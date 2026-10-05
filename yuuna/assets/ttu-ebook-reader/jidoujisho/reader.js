/*
 * jidoujisho bridge for ッツ Ebook Reader's book page (b.html).
 *
 * Injected once per page load. Handles tap-to-lookup, the lookup highlight,
 * reading and saving ッツ's position, and the short highlight shown after
 * jumping to a memo. Messages go to Flutter through the "jidoujisho"
 * JavaScript handler.
 */
(function () {
  'use strict';

  if (window.__jdj) {
    return;
  }

  var jdj = (window.__jdj = {});

  /* How far outside a character's box a tap still counts, in CSS pixels. */
  var SLOP = 4;

  var BLOCKS = {
    P: 1, DIV: 1, LI: 1, H1: 1, H2: 1, H3: 1, H4: 1, H5: 1, H6: 1,
    BLOCKQUOTE: 1, TD: 1, TH: 1, DD: 1, DT: 1, SECTION: 1, ARTICLE: 1,
    FIGCAPTION: 1,
  };

  function post(message) {
    var bridge = window.flutter_inappwebview;
    if (bridge && typeof bridge.callHandler === 'function') {
      bridge.callHandler('jidoujisho', message);
    }
  }

  function isBookContent(el) {
    return !!(el && el.classList && el.classList.contains('book-content'));
  }

  /* Furigana and its parentheses are never part of the looked-up text. */
  function isAnnotation(node) {
    for (var el = node.parentElement; el; el = el.parentElement) {
      if (el.nodeName === 'RT' || el.nodeName === 'RP') {
        return true;
      }
      if (isBookContent(el)) {
        return false;
      }
    }
    return false;
  }

  function insideBook(node) {
    for (var el = node.parentElement; el; el = el.parentElement) {
      if (isBookContent(el)) {
        return true;
      }
    }
    return false;
  }

  function paragraphOf(node) {
    var fallback = null;
    for (var el = node.parentElement; el && !isBookContent(el); el = el.parentElement) {
      if (el.nodeName === 'P') {
        return el;
      }
      if (!fallback && BLOCKS[el.nodeName]) {
        fallback = el;
      }
    }
    return fallback || node.parentElement;
  }

  function textNodesOf(root) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        return isAnnotation(n) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      },
    });
    var nodes = [];
    for (var n = walker.nextNode(); n; n = walker.nextNode()) {
      nodes.push(n);
    }
    return nodes;
  }

  function rectsContain(rects, x, y) {
    for (var i = 0; i < rects.length; i++) {
      var r = rects[i];
      if (r.width === 0 && r.height === 0) {
        continue;
      }
      if (x >= r.left - SLOP && x <= r.right + SLOP && y >= r.top - SLOP && y <= r.bottom + SLOP) {
        return true;
      }
    }
    return false;
  }

  /*
   * caretRangeFromPoint snaps to the nearest text even when the finger is in
   * a margin or between lines, so check that a character is really under the
   * tap before treating it as a lookup.
   */
  function hitTest(x, y) {
    var caret = document.caretRangeFromPoint(x, y);
    if (!caret) {
      return null;
    }
    var node = caret.startContainer;
    if (!node || node.nodeType !== Node.TEXT_NODE || isAnnotation(node) || !insideBook(node)) {
      return null;
    }
    var text = node.textContent;
    var range = document.createRange();
    var candidates = [caret.startOffset, caret.startOffset - 1];
    for (var i = 0; i < candidates.length; i++) {
      var offset = candidates[i];
      if (offset < 0 || offset >= text.length || /\s/.test(text[offset])) {
        continue;
      }
      range.setStart(node, offset);
      range.setEnd(node, offset + 1);
      if (rectsContain(range.getClientRects(), x, y)) {
        return { node: node, offset: offset };
      }
    }
    return null;
  }

  var last = null;

  function dismiss(e) {
    post({ type: 'lookup', index: -1, text: '', x: Math.round(e.clientX), y: Math.round(e.clientY) });
  }

  var CONTROLS = 'button, a, input, select, textarea, label, [role="button"], [role="dialog"]';

  function onTap(e) {
    var target = e.target;
    if (!target || !target.closest) {
      return;
    }
    if (!target.closest('.book-content')) {
      /* Margins close the popup; ッツ's own buttons are left alone. */
      if (!target.closest(CONTROLS)) {
        dismiss(e);
      }
      return;
    }

    var hit = hitTest(e.clientX, e.clientY);
    if (!hit) {
      dismiss(e);
      return;
    }

    /* Tapping the word that is already highlighted closes the popup. */
    var selection = window.getSelection();
    if (selection && selection.rangeCount && !selection.isCollapsed) {
      var current = selection.getRangeAt(0);
      try {
        if (current.isPointInRange(hit.node, hit.offset)) {
          dismiss(e);
          return;
        }
      } catch (_) {
        /* A range in another document fragment is never the same word. */
      }
    }

    var paragraph = paragraphOf(hit.node);
    var nodes = textNodesOf(paragraph);
    var text = '';
    var index = -1;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i] === hit.node) {
        index = text.length + hit.offset;
      }
      text += nodes[i].textContent;
    }
    if (index < 0) {
      dismiss(e);
      return;
    }

    last = { nodes: nodes };
    post({ type: 'lookup', index: index, text: text, x: Math.round(e.clientX), y: Math.round(e.clientY) });
  }

  document.addEventListener('click', onTap, true);

  /* Highlights [start, start + length) of the last tapped paragraph. */
  jdj.highlight = function (start, length, wordMode) {
    if (!last || !last.nodes.length) {
      return;
    }
    var nodes = last.nodes;
    var end = start + Math.max(length, 1);
    var pos = 0;
    var startNode = null;
    var startOffset = 0;
    var endNode = null;
    var endOffset = 0;
    for (var i = 0; i < nodes.length; i++) {
      var len = nodes[i].textContent.length;
      if (!startNode && start < pos + len) {
        startNode = nodes[i];
        startOffset = start - pos;
      }
      if (startNode && end <= pos + len) {
        endNode = nodes[i];
        endOffset = end - pos;
        break;
      }
      pos += len;
    }
    if (!startNode) {
      return;
    }
    if (!endNode) {
      endNode = nodes[nodes.length - 1];
      endOffset = endNode.textContent.length;
    }
    var range = document.createRange();
    range.setStart(startNode, startOffset);
    if (wordMode && typeof range.expand === 'function') {
      range.setEnd(startNode, Math.min(startOffset + 1, startNode.textContent.length));
      range.expand('word');
    } else {
      range.setEnd(endNode, endOffset);
    }
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
  };

  jdj.clearSelection = function () {
    var selection = window.getSelection();
    if (selection && !selection.isCollapsed) {
      selection.removeAllRanges();
    }
  };

  /* ---------- ッツ position ---------- */

  function bookId() {
    var id = new URLSearchParams(location.search).get('id');
    return id === null ? NaN : Number(id);
  }

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
        reject(request.error || new Error('Could not open ッツ storage'));
      };
    });
  }

  function readBookmark(id) {
    return openBooks().then(function (db) {
      return new Promise(function (resolve, reject) {
        var tx = db.transaction('bookmark', 'readonly');
        var request = tx.objectStore('bookmark').get(id);
        request.onsuccess = function () {
          resolve(request.result || null);
        };
        request.onerror = function () {
          reject(request.error);
        };
      }).finally(function () {
        db.close();
      });
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

  function toPosition(bookmark) {
    if (!bookmark) {
      return null;
    }
    return {
      exploredCharCount: bookmark.exploredCharCount || 0,
      progress: normaliseProgress(bookmark.progress),
      lastBookmarkModified: bookmark.lastBookmarkModified || 0,
    };
  }

  function sleep(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  /*
   * Presses ッツ's own bookmark key, so ッツ computes the position itself,
   * then waits for the saved record. Returns the saved position.
   */
  jdj.savePosition = function () {
    var id = bookId();
    if (isNaN(id)) {
      return Promise.resolve(null);
    }
    return readBookmark(id).then(function (before) {
      var since = (before && before.lastBookmarkModified) || 0;
      var target = document.body || document.documentElement;
      target.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'b', code: 'KeyB', bubbles: true, cancelable: true,
      }));
      var attempt = function (n) {
        return sleep(60).then(function () {
          return readBookmark(id);
        }).then(function (now) {
          if (now && (now.lastBookmarkModified || 0) > since) {
            return toPosition(now);
          }
          if (n <= 0) {
            return toPosition(now || before);
          }
          return attempt(n - 1);
        });
      };
      return attempt(25);
    });
  };

  jdj.readPosition = function () {
    var id = bookId();
    if (isNaN(id)) {
      return Promise.resolve(null);
    }
    return readBookmark(id).then(toPosition);
  };

  /* ---------- landing highlight after a jump ---------- */

  var FLASH_STYLE_ID = 'jdj-flash-style';

  function flashStyle(alpha) {
    var style = document.getElementById(FLASH_STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = FLASH_STYLE_ID;
      document.head.appendChild(style);
    }
    style.textContent = '::highlight(jdj-flash){background-color:rgba(244,67,54,' + alpha + ');}';
  }

  function visible(range) {
    var rects = range.getClientRects();
    var w = window.innerWidth;
    var h = window.innerHeight;
    for (var i = 0; i < rects.length; i++) {
      var r = rects[i];
      if (r.right > 0 && r.left < w && r.bottom > 0 && r.top < h && (r.width || r.height)) {
        return true;
      }
    }
    return false;
  }

  function findVisible(excerpt) {
    var root = document.querySelector('.book-content');
    if (!root) {
      return null;
    }
    var nodes = textNodesOf(root);
    var starts = [];
    var text = '';
    for (var i = 0; i < nodes.length; i++) {
      starts.push(text.length);
      text += nodes[i].textContent;
    }
    var locate = function (offset) {
      var lo = 0;
      var hi = nodes.length - 1;
      while (lo < hi) {
        var mid = (lo + hi + 1) >> 1;
        if (starts[mid] <= offset) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return { node: nodes[lo], offset: offset - starts[lo] };
    };
    for (var at = text.indexOf(excerpt); at >= 0; at = text.indexOf(excerpt, at + 1)) {
      var a = locate(at);
      var b = locate(at + excerpt.length - 1);
      var range = document.createRange();
      range.setStart(a.node, a.offset);
      range.setEnd(b.node, b.offset + 1);
      if (visible(range)) {
        return range;
      }
    }
    return null;
  }

  /* Briefly highlights the memo's quoted line once it is on screen. */
  jdj.flash = function (excerpt) {
    if (!excerpt || !window.CSS || !CSS.highlights || typeof Highlight === 'undefined') {
      return Promise.resolve(false);
    }
    var tries = 0;
    var run = function () {
      var range = findVisible(excerpt.trim());
      if (!range) {
        tries += 1;
        if (tries > 12) {
          return Promise.resolve(false);
        }
        return sleep(250).then(run);
      }
      CSS.highlights.set('jdj-flash', new Highlight(range));
      var steps = [0.34, 0.34, 0.34, 0.3, 0.24, 0.18, 0.12, 0.06, 0];
      var step = function (i) {
        if (i >= steps.length) {
          CSS.highlights.delete('jdj-flash');
          return Promise.resolve(true);
        }
        flashStyle(steps[i]);
        return sleep(i < 3 ? 300 : 150).then(function () {
          return step(i + 1);
        });
      };
      return step(0);
    };
    return run();
  };

  /* Selection colours and unselectable furigana, as before. */
  var style = document.createElement('style');
  style.textContent =
    'rt,rp{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}' +
    '::selection{color:white;background:rgba(255,0,0,0.6)}';
  (document.head || document.documentElement).appendChild(style);
})();
