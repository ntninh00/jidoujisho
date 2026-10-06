/*
 * jidoujisho storage bridge for ッツ Ebook Reader: backs up and restores
 * everything ッツ keeps in the browser for one language.
 *
 * Runs in a hidden WebView on the ッツ origin. Covers every IndexedDB
 * database (books, reading positions, statistics), localStorage (settings)
 * and Cache Storage (fonts the user added). Values JSON can't hold, such as
 * pictures stored as Blobs, are tagged and written as base64.
 *
 * Big data moves in slices: the app asks for the next records to be packed
 * into text, then reads that text a slice at a time; restoring works the
 * same way in reverse. Every function returns plain JSON-safe values for
 * callAsyncJavaScript.
 */
(function () {
  'use strict';

  if (window.jdjStorage) {
    return;
  }

  var S = (window.jdjStorage = {});
  var TAG = '$jdj';
  /* Caches holding the user's own files: fonts added in ッツ's settings. */
  var USER_CACHES = ['ttu-userfonts'];
  var outgoing = '';
  var incoming = [];

  function done(request) {
    return new Promise(function (resolve, reject) {
      request.onsuccess = function () {
        resolve(request.result);
      };
      request.onerror = function () {
        reject(request.error);
      };
    });
  }

  function finished(tx) {
    return new Promise(function (resolve, reject) {
      tx.oncomplete = function () {
        resolve();
      };
      tx.onerror = function () {
        reject(tx.error);
      };
      tx.onabort = function () {
        reject(tx.error || new Error('Transaction aborted'));
      };
    });
  }

  /* ---------- values ---------- */

  function blobToBase64(blob) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onload = function () {
        var url = String(reader.result);
        resolve(url.slice(url.indexOf(',') + 1));
      };
      reader.onerror = function () {
        reject(reader.error);
      };
      reader.readAsDataURL(blob);
    });
  }

  function base64ToBytes(text) {
    var binary = atob(text);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  function bytesOf(view) {
    return new Blob([view]);
  }

  /* A value as JSON, with Blobs, binary data, dates and odd numbers tagged. */
  function encode(value) {
    if (value === null || value === undefined) {
      return Promise.resolve(value === undefined ? { $jdj: 'undefined' } : null);
    }
    if (typeof value === 'number') {
      return Promise.resolve(isFinite(value) ? value : { $jdj: 'number', v: String(value) });
    }
    if (typeof value !== 'object') {
      return Promise.resolve(value);
    }
    if (value instanceof Date) {
      return Promise.resolve({ $jdj: 'date', v: value.getTime() });
    }
    if (typeof Blob !== 'undefined' && value instanceof Blob) {
      return blobToBase64(value).then(function (data) {
        var tagged = { $jdj: 'blob', type: value.type || '', v: data };
        if (typeof File !== 'undefined' && value instanceof File) {
          tagged.name = value.name;
          tagged.lastModified = value.lastModified;
        }
        return tagged;
      });
    }
    if (value instanceof ArrayBuffer) {
      return blobToBase64(bytesOf(value)).then(function (data) {
        return { $jdj: 'buffer', v: data };
      });
    }
    if (ArrayBuffer.isView(value)) {
      return blobToBase64(bytesOf(value)).then(function (data) {
        return { $jdj: 'view', kind: value.constructor.name, v: data };
      });
    }
    if (Array.isArray(value)) {
      return Promise.all(value.map(encode));
    }
    if (value instanceof Map) {
      return Promise.all(Array.from(value.entries()).map(function (pair) {
        return Promise.all([encode(pair[0]), encode(pair[1])]);
      })).then(function (entries) {
        return { $jdj: 'map', v: entries };
      });
    }
    if (value instanceof Set) {
      return Promise.all(Array.from(value.values()).map(encode)).then(function (items) {
        return { $jdj: 'set', v: items };
      });
    }
    var keys = Object.keys(value);
    return Promise.all(keys.map(function (key) {
      return encode(value[key]);
    })).then(function (values) {
      var out = {};
      keys.forEach(function (key, i) {
        out[key] = values[i];
      });
      return out;
    });
  }

  function decode(value) {
    if (value === null || typeof value !== 'object') {
      return value;
    }
    if (Array.isArray(value)) {
      return value.map(decode);
    }
    switch (value[TAG]) {
      case 'undefined':
        return undefined;
      case 'number':
        return Number(value.v);
      case 'date':
        return new Date(value.v);
      case 'blob': {
        var bytes = base64ToBytes(value.v);
        if (value.name !== undefined && typeof File !== 'undefined') {
          return new File([bytes], value.name, { type: value.type, lastModified: value.lastModified });
        }
        return new Blob([bytes], { type: value.type });
      }
      case 'buffer':
        return base64ToBytes(value.v).buffer;
      case 'view': {
        var raw = base64ToBytes(value.v);
        var Kind = window[value.kind];
        return typeof Kind === 'function' && Kind !== DataView
          ? new Kind(raw.buffer, 0, raw.byteLength / (Kind.BYTES_PER_ELEMENT || 1))
          : new DataView(raw.buffer);
      }
      case 'map':
        return new Map(value.v.map(function (pair) {
          return [decode(pair[0]), decode(pair[1])];
        }));
      case 'set':
        return new Set(value.v.map(decode));
    }
    var out = {};
    Object.keys(value).forEach(function (key) {
      out[key] = decode(value[key]);
    });
    return out;
  }

  /* ---------- databases ---------- */

  function databaseNames() {
    if (!indexedDB.databases) {
      return Promise.resolve(['books']);
    }
    return indexedDB.databases().then(function (list) {
      return list.map(function (db) {
        return db.name;
      }).filter(Boolean);
    });
  }

  /* Opens a database that exists, never creating or upgrading it. */
  function openExisting(name) {
    return new Promise(function (resolve, reject) {
      var request = indexedDB.open(name);
      request.onupgradeneeded = function () {
        request.transaction.abort();
      };
      request.onsuccess = function () {
        resolve(request.result);
      };
      request.onerror = function () {
        reject(request.error || new Error('No database ' + name));
      };
    });
  }

  function describeStore(db, name) {
    var tx = db.transaction(name, 'readonly');
    var store = tx.objectStore(name);
    var indexes = Array.from(store.indexNames).map(function (indexName) {
      var index = store.index(indexName);
      return {
        name: indexName,
        keyPath: index.keyPath,
        unique: index.unique,
        multiEntry: index.multiEntry,
      };
    });
    return done(store.count()).then(function (count) {
      return {
        name: name,
        keyPath: store.keyPath,
        autoIncrement: store.autoIncrement,
        indexes: indexes,
        count: count,
      };
    });
  }

  /* What there is to back up: databases with their stores, settings, and
   * cached files. */
  S.describe = function () {
    return databaseNames().then(function (names) {
      return Promise.all(names.map(function (name) {
        return openExisting(name).then(function (db) {
          var stores = Array.from(db.objectStoreNames);
          return Promise.all(stores.map(function (store) {
            return describeStore(db, store);
          })).then(function (described) {
            var out = { name: name, version: db.version, stores: described };
            db.close();
            return out;
          });
        }, function () {
          return null;
        });
      }));
    }).then(function (databases) {
      var settings = {};
      for (var i = 0; i < localStorage.length; i++) {
        var key = localStorage.key(i);
        settings[key] = localStorage.getItem(key);
      }
      // Only the user's own files; ッツ's cached program files belong to the
      // installed version and are left alone.
      var cacheList = typeof caches === 'undefined'
        ? Promise.resolve([])
        : caches.keys().then(function (names) {
          return names.filter(function (name) {
            return USER_CACHES.indexOf(name) >= 0;
          });
        });
      return cacheList.then(function (cacheNames) {
        return Promise.all(cacheNames.map(function (cacheName) {
          return caches.open(cacheName).then(function (cache) {
            return cache.keys();
          }).then(function (requests) {
            return { name: cacheName, count: requests.length };
          });
        }));
      }).then(function (cacheInfo) {
        return {
          databases: databases.filter(Boolean),
          localStorage: settings,
          caches: cacheInfo,
        };
      });
    });
  };

  /*
   * Packs the records of a store that come after [after] (an encoded key, or
   * null to start) into text of roughly [budget] characters, ready to be
   * read with slice(). Resolves with the text's length, how many records it
   * holds, and the key to continue after, or null at the end.
   */
  S.pack = function (dbName, storeName, after, budget) {
    budget = budget || 4 * 1024 * 1024;
    var start = after === null || after === undefined ? null : decode(after);
    return openExisting(dbName).then(function (db) {
      var range = start === null ? null : IDBKeyRange.lowerBound(start, true);
      var keys = done(db.transaction(storeName, 'readonly').objectStore(storeName).getAllKeys(range, 500));
      return keys.then(function (list) {
        var parts = [];
        var size = 0;
        var last = null;
        var i = 0;
        var next = function () {
          if (i >= list.length || (parts.length && size >= budget)) {
            return Promise.resolve();
          }
          var key = list[i++];
          var read = done(db.transaction(storeName, 'readonly').objectStore(storeName).get(key));
          return read.then(function (value) {
            return Promise.all([encode(key), encode(value)]);
          }).then(function (pair) {
            var text = JSON.stringify(pair);
            parts.push(text);
            size += text.length;
            last = pair[0];
            return next();
          });
        };
        return next().then(function () {
          db.close();
          outgoing = '[' + parts.join(',') + ']';
          var more = i < list.length || list.length === 500;
          return { length: outgoing.length, count: parts.length, next: more ? last : null };
        });
      }, function (error) {
        db.close();
        throw error;
      });
    });
  };

  /* A slice of the text the last pack() made. */
  S.slice = function (from, to) {
    return outgoing.substring(from, to);
  };

  /* Packs cached files from position [from], like pack(). */
  S.packCache = function (cacheName, from, budget) {
    budget = budget || 4 * 1024 * 1024;
    return caches.open(cacheName).then(function (cache) {
      return cache.keys().then(function (requests) {
        var parts = [];
        var size = 0;
        var i = from || 0;
        var next = function () {
          if (i >= requests.length || (parts.length && size >= budget)) {
            return Promise.resolve();
          }
          var request = requests[i++];
          return cache.match(request).then(function (response) {
            if (!response) {
              return next();
            }
            var headers = [];
            response.headers.forEach(function (value, name) {
              headers.push([name, value]);
            });
            return response.blob().then(encode).then(function (body) {
              var url = new URL(request.url);
              var text = JSON.stringify({
                path: url.pathname + url.search,
                status: response.status,
                statusText: response.statusText,
                headers: headers,
                body: body,
              });
              parts.push(text);
              size += text.length;
              return next();
            });
          });
        };
        return next().then(function () {
          outgoing = '[' + parts.join(',') + ']';
          return { length: outgoing.length, count: parts.length, next: i < requests.length ? i : null };
        });
      });
    });
  };

  /* ---------- restoring ---------- */

  /* Receives a slice of text for the next unpack(). */
  S.receive = function (chunk) {
    incoming.push(chunk);
    return incoming.length;
  };

  function takeIncoming() {
    var text = incoming.join('');
    incoming = [];
    return JSON.parse(text);
  }

  /* Opens [description]'s database, creating it and any missing stores and
   * indexes, and empties its stores. */
  function prepareDatabase(description) {
    return new Promise(function (resolve, reject) {
      var request = indexedDB.open(description.name);
      request.onsuccess = function () {
        var db = request.result;
        var version = db.version;
        var missing = description.stores.some(function (store) {
          return !db.objectStoreNames.contains(store.name);
        });
        db.close();
        resolve({ version: version, missing: missing });
      };
      request.onerror = function () {
        reject(request.error);
      };
    }).then(function (state) {
      var target = Math.max(state.version, description.version || 1);
      if (state.missing && target === state.version) {
        target += 1;
      }
      return new Promise(function (resolve, reject) {
        var request = indexedDB.open(description.name, target);
        request.onupgradeneeded = function () {
          var db = request.result;
          var tx = request.transaction;
          description.stores.forEach(function (spec) {
            var store = db.objectStoreNames.contains(spec.name)
              ? tx.objectStore(spec.name)
              : db.createObjectStore(spec.name, {
                keyPath: spec.keyPath === undefined ? null : spec.keyPath,
                autoIncrement: !!spec.autoIncrement,
              });
            (spec.indexes || []).forEach(function (index) {
              if (!store.indexNames.contains(index.name)) {
                store.createIndex(index.name, index.keyPath, {
                  unique: !!index.unique,
                  multiEntry: !!index.multiEntry,
                });
              }
            });
          });
        };
        request.onblocked = function () {
          reject(new Error('ッツ storage is in use. Close any open book and try again.'));
        };
        request.onsuccess = function () {
          resolve(request.result);
        };
        request.onerror = function () {
          reject(request.error);
        };
      });
    }).then(function (db) {
      var names = description.stores.map(function (store) {
        return store.name;
      });
      if (!names.length) {
        db.close();
        return true;
      }
      var tx = db.transaction(names, 'readwrite');
      names.forEach(function (name) {
        tx.objectStore(name).clear();
      });
      return finished(tx).then(function () {
        db.close();
        return true;
      });
    });
  }

  /* Makes ready for a restore: databases and stores as described, emptied,
   * and the caches the backup has removed. */
  S.prepare = function (description) {
    var chain = Promise.resolve();
    (description.databases || []).forEach(function (db) {
      chain = chain.then(function () {
        return prepareDatabase(db);
      });
    });
    return chain.then(function () {
      if (typeof caches === 'undefined') {
        return true;
      }
      return Promise.all((description.caches || []).map(function (cache) {
        return caches.delete(cache.name);
      })).then(function () {
        return true;
      });
    });
  };

  /* Writes the records received since the last unpack into a store. */
  S.unpack = function (dbName, storeName) {
    var items = takeIncoming();
    return openExisting(dbName).then(function (db) {
      var tx = db.transaction(storeName, 'readwrite');
      var store = tx.objectStore(storeName);
      var inline = store.keyPath !== null;
      items.forEach(function (pair) {
        var value = decode(pair[1]);
        if (inline) {
          store.put(value);
        } else {
          store.put(value, decode(pair[0]));
        }
      });
      return finished(tx).then(function () {
        db.close();
        return items.length;
      });
    });
  };

  /* Puts the files received since the last unpack back in a cache, under
   * this page's own address. */
  S.unpackCache = function (cacheName) {
    var items = takeIncoming();
    return caches.open(cacheName).then(function (cache) {
      return Promise.all(items.map(function (item) {
        var headers = new Headers();
        (item.headers || []).forEach(function (pair) {
          headers.append(pair[0], pair[1]);
        });
        var response = new Response(decode(item.body), {
          status: item.status || 200,
          statusText: item.statusText || '',
          headers: headers,
        });
        return cache.put(new Request(location.origin + item.path), response);
      }));
    }).then(function () {
      return items.length;
    });
  };

  /* Replaces ッツ's settings. */
  S.restoreSettings = function (settings) {
    localStorage.clear();
    Object.keys(settings || {}).forEach(function (key) {
      localStorage.setItem(key, settings[key]);
    });
    return true;
  };
})();
