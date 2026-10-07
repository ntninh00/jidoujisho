/*
 * jidoujisho library bridge for ッツ Ebook Reader.
 *
 * Runs in a hidden WebView on the ッツ origin. Lists books without pulling
 * their full text, hands picked files to ッツ's own importer, and deletes
 * books. Every function returns plain JSON-safe values for
 * callAsyncJavaScript.
 */
(function () {
  'use strict';

  if (window.jdjLibrary) {
    return;
  }

  var L = (window.jdjLibrary = {});
  var staged = {};

  function sleep(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  /* Opens ッツ's database without ever creating or upgrading it. */
  function openBooks() {
    return new Promise(function (resolve, reject) {
      var request = indexedDB.open('books');
      request.onupgradeneeded = function () {
        request.transaction.abort();
      };
      request.onsuccess = function () {
        resolve(request.result);
      };
      request.onerror = function () {
        reject(request.error || new Error('No ッツ storage yet'));
      };
    });
  }

  function hasStore(db, name) {
    return Array.prototype.indexOf.call(db.objectStoreNames, name) >= 0;
  }

  function getAll(db, store) {
    if (!hasStore(db, store)) {
      return Promise.resolve([]);
    }
    return new Promise(function (resolve, reject) {
      var request = db.transaction(store, 'readonly').objectStore(store).getAll();
      request.onsuccess = function () {
        resolve(request.result || []);
      };
      request.onerror = function () {
        reject(request.error);
      };
    });
  }

  /* Walks the data store with a cursor and keeps only what the shelf needs. */
  function listData(db) {
    if (!hasStore(db, 'data')) {
      return Promise.resolve([]);
    }
    return new Promise(function (resolve, reject) {
      var books = [];
      var request = db.transaction('data', 'readonly').objectStore('data').openCursor();
      request.onsuccess = function () {
        var cursor = request.result;
        if (!cursor) {
          resolve(books);
          return;
        }
        var v = cursor.value || {};
        books.push({
          id: v.id,
          title: v.title || '',
          characters: v.characters || 0,
          lastBookOpen: v.lastBookOpen || 0,
          lastBookModified: v.lastBookModified || 0,
          cover: v.coverImage || null,
        });
        cursor.continue();
      };
      request.onerror = function () {
        reject(request.error);
      };
    });
  }

  function normaliseProgress(progress) {
    if (typeof progress === 'string') {
      var value = parseFloat(progress);
      if (isNaN(value)) {
        return 0;
      }
      return progress.trim().slice(-1) === '%' ? value / 100 : value;
    }
    return typeof progress === 'number' && isFinite(progress) ? progress : 0;
  }

  function blobToDataUrl(blob) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onload = function () {
        resolve(reader.result);
      };
      reader.onerror = function () {
        reject(reader.error);
      };
      reader.readAsDataURL(blob);
    });
  }

  /* Covers are shrunk to thumbnail size so the app never decodes full images. */
  function thumbnail(cover) {
    if (!cover) {
      return Promise.resolve(null);
    }
    if (typeof cover === 'string') {
      return Promise.resolve(cover.indexOf('data:') === 0 ? cover : null);
    }
    if (typeof createImageBitmap !== 'function') {
      return blobToDataUrl(cover).catch(function () {
        return null;
      });
    }
    return createImageBitmap(cover).then(function (bitmap) {
      var width = 360;
      var scale = Math.min(1, width / bitmap.width);
      var canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * scale));
      canvas.height = Math.max(1, Math.round(bitmap.height * scale));
      canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      if (bitmap.close) {
        bitmap.close();
      }
      return canvas.toDataURL('image/jpeg', 0.86);
    }).catch(function () {
      return blobToDataUrl(cover).catch(function () {
        return null;
      });
    });
  }

  /*
   * Lists every book. `known` maps a book id to the lastBookModified value the
   * app already has a cover for; those covers are skipped.
   */
  L.list = function (known) {
    known = known || {};
    return openBooks().then(function (db) {
      return Promise.all([listData(db), getAll(db, 'bookmark')]).finally(function () {
        db.close();
      });
    }, function () {
      return null;
    }).then(function (stores) {
      if (!stores) {
        return { exists: false, books: [] };
      }
      var books = stores[0];
      var bookmarks = {};
      stores[1].forEach(function (b) {
        bookmarks[b.dataId] = b;
      });
      var chain = Promise.resolve();
      books.forEach(function (book) {
        var mark = bookmarks[book.id];
        book.exploredCharCount = (mark && mark.exploredCharCount) || 0;
        book.progress = mark ? normaliseProgress(mark.progress) : 0;
        book.lastBookmarkModified = (mark && mark.lastBookmarkModified) || 0;
        var cover = book.cover;
        book.cover = null;
        book.coverChanged = false;
        if (String(known[book.id]) !== String(book.lastBookModified)) {
          chain = chain.then(function () {
            return thumbnail(cover);
          }).then(function (url) {
            book.cover = url;
            book.coverChanged = true;
          });
        }
      });
      return chain.then(function () {
        return { exists: true, books: books };
      });
    });
  };

  /* Large files arrive in base64 chunks so no single message is huge. */
  L.stage = function (key, chunk) {
    var binary = atob(chunk);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    (staged[key] = staged[key] || []).push(bytes);
    return true;
  };

  function bookIds() {
    return openBooks().then(function (db) {
      if (!hasStore(db, 'data')) {
        db.close();
        return [];
      }
      return new Promise(function (resolve, reject) {
        var request = db.transaction('data', 'readonly').objectStore('data').getAllKeys();
        request.onsuccess = function () {
          resolve(request.result || []);
        };
        request.onerror = function () {
          reject(request.error);
        };
      }).finally(function () {
        db.close();
      });
    }, function () {
      return [];
    });
  }

  function importInput() {
    var inputs = document.querySelectorAll('input[type="file"]');
    for (var i = 0; i < inputs.length; i++) {
      var accept = inputs[i].getAttribute('accept') || '';
      if (accept.indexOf('.epub') >= 0) {
        return inputs[i];
      }
    }
    return null;
  }

  function importError() {
    var text = document.body ? document.body.innerText : '';
    var markers = ['Import failed', 'Failure', 'Error'];
    for (var i = 0; i < markers.length; i++) {
      var at = text.indexOf(markers[i]);
      if (at >= 0) {
        return text.substr(at, 200).split('\n').slice(0, 3).join(' ').trim();
      }
    }
    return null;
  }

  /*
   * Imports every staged file through ッツ's own file input, then waits until
   * the new books are stored. Resolves with the ids that were added.
   */
  L.importStaged = function (names, timeoutMs) {
    var files = names.map(function (name) {
      var type = /\.epub$/i.test(name) ? 'application/epub+zip' : 'application/zip';
      return new File(staged[name] || [], name, { type: type });
    });
    staged = {};
    var deadline = Date.now() + (timeoutMs || 180000);
    var waitForInput = function () {
      var input = importInput();
      if (input) {
        return Promise.resolve(input);
      }
      if (Date.now() > deadline) {
        return Promise.reject(new Error('ッツ import is not ready'));
      }
      return sleep(150).then(waitForInput);
    };
    return Promise.all([waitForInput(), bookIds()]).then(function (ready) {
      var input = ready[0];
      var before = ready[1];
      var transfer = new DataTransfer();
      files.forEach(function (file) {
        transfer.items.add(file);
      });
      input.files = transfer.files;
      input.dispatchEvent(new Event('change', { bubbles: true }));
      var poll = function () {
        return sleep(300).then(function () {
          return bookIds();
        }).then(function (now) {
          var added = now.filter(function (id) {
            return before.indexOf(id) < 0;
          });
          if (added.length >= files.length) {
            return { added: added };
          }
          var error = importError();
          if (error) {
            return { added: added, error: error };
          }
          if (Date.now() > deadline) {
            return { added: added, error: 'Import timed out' };
          }
          return poll();
        });
      };
      return poll();
    });
  };

  /* Deletes books and their saved position from ッツ's database. */
  L.deleteBooks = function (ids) {
    return openBooks().then(function (db) {
      var stores = ['data', 'bookmark', 'lastItem'].filter(function (s) {
        return hasStore(db, s);
      });
      return new Promise(function (resolve, reject) {
        var tx = db.transaction(stores, 'readwrite');
        ids.forEach(function (id) {
          if (stores.indexOf('data') >= 0) {
            tx.objectStore('data').delete(id);
          }
          if (stores.indexOf('bookmark') >= 0) {
            tx.objectStore('bookmark').delete(id);
          }
        });
        if (stores.indexOf('lastItem') >= 0) {
          var last = tx.objectStore('lastItem');
          var cursorRequest = last.openCursor();
          cursorRequest.onsuccess = function () {
            var cursor = cursorRequest.result;
            if (!cursor) {
              return;
            }
            if (cursor.value && ids.indexOf(cursor.value.dataId) >= 0) {
              cursor.delete();
            }
            cursor.continue();
          };
        }
        tx.oncomplete = function () {
          resolve(true);
        };
        tx.onerror = function () {
          reject(tx.error);
        };
      }).finally(function () {
        db.close();
      });
    });
  };
  /* ---------- the user's fonts ---------- */

  /*
   * Fonts the user added, stored the way ッツ's settings page stores them:
   * the file in the `ttu-userfonts` cache under /userfonts/<file>, and
   * {name, path, fileName} in localStorage, which ッツ loads them from.
   */
  var FONT_CACHE = 'ttu-userfonts';

  function storedFonts() {
    try {
      var fonts = JSON.parse(localStorage.getItem('userfonts') || '[]');
      return Array.isArray(fonts) ? fonts : [];
    } catch (_) {
      return [];
    }
  }

  L.fonts = function () {
    return storedFonts().map(function (font) {
      return font.name;
    });
  };

  /* Stores the staged file [key] as the font [name], replacing one of the
   * same name or file. */
  L.addFont = function (name, fileName, key) {
    var parts = staged[key] || [];
    delete staged[key];
    var blob = new Blob(parts);
    var path = '/userfonts/' + fileName;
    var type = 'font/' + fileName.split('.').pop().toLowerCase();
    var others = storedFonts().filter(function (font) {
      return font.name !== name && font.fileName !== fileName;
    });
    return caches.open(FONT_CACHE).then(function (cache) {
      return cache.put(path, new Response(blob, {
        headers: { 'Content-Type': type, 'Content-Length': String(blob.size) },
      }));
    }).then(function () {
      others.push({ name: name, path: path, fileName: fileName });
      localStorage.setItem('userfonts', JSON.stringify(others));
      return true;
    });
  };

  L.removeFont = function (name) {
    var fonts = storedFonts();
    var gone = fonts.filter(function (font) {
      return font.name === name;
    });
    localStorage.setItem('userfonts', JSON.stringify(fonts.filter(function (font) {
      return font.name !== name;
    })));
    return caches.open(FONT_CACHE).then(function (cache) {
      return Promise.all(gone.map(function (font) {
        return cache.delete(font.path);
      }));
    }).then(function () {
      return true;
    });
  };
})();
