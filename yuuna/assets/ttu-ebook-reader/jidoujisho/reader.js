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

  /* Height of the strips at the top and bottom edges that open the menu. */
  var MENU_STRIP = 40;

  function onTap(e) {
    var target = e.target;
    if (!target || !target.closest) {
      return;
    }
    /* A memo's note opens the whole memo in the app. */
    var note = target.closest('.jdj-memo-note');
    if (note) {
      post({ type: 'memo', id: Number(note.getAttribute('data-memo')) });
      return;
    }
    /* The full-size viewer handles its own taps. */
    if (target.closest('#jdj-viewer')) {
      return;
    }
    /* A formula or table shrunk to fit opens at full size. */
    var fitted = target.closest('[data-jdj-fit]');
    if (fitted && window.__jdjFit) {
      dismiss(e);
      window.__jdjFit.open(fitted);
      return;
    }
    if (!target.closest('.book-content')) {
      /* Margins close the popup, and the edge strips open the app's menu;
       * ッツ's own buttons are left alone. */
      if (!target.closest(CONTROLS)) {
        if (e.clientY < MENU_STRIP || e.clientY > window.innerHeight - MENU_STRIP) {
          post({ type: 'menu' });
        } else {
          dismiss(e);
        }
      }
      return;
    }

    var hit = hitTest(e.clientX, e.clientY);
    if (!hit) {
      /* The strips along the top and bottom edges open the app's menu. */
      if (e.clientY < MENU_STRIP || e.clientY > window.innerHeight - MENU_STRIP) {
        post({ type: 'menu' });
        return;
      }
      dismiss(e);
      return;
    }

    /* Tapping the word that is already highlighted closes the popup. */
    if (word) {
      for (var w = 0; w < word.ranges.length; w++) {
        try {
          if (word.ranges[w].isPointInRange(hit.node, hit.offset)) {
            dismiss(e);
            return;
          }
        } catch (_) {
          /* A range in another document fragment is never the same word. */
        }
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

  /* ---------- lookup highlight ---------- */

  /*
   * The looked-up word gets a box with slightly rounded corners drawn behind
   * the text. Boxes live in a fixed layer under the book, outside ッツ's
   * content, so ッツ's character counts never see them. Where something in
   * the page paints its own background over that layer, the CSS highlight
   * API is used instead, which has square corners.
   */
  var HIGHLIGHT_FILL = 'rgba(255,0,0,0.6)';
  var RADIUS = 4;
  var PAD = 2;
  var hasHighlightApi = !!(window.CSS && CSS.highlights && typeof Highlight !== 'undefined');

  var word = null;

  /* Splits [startNode:startOffset, endNode:endOffset) into one range per
   * text node, leaving out furigana. */
  function piecesBetween(nodes, startNode, startOffset, endNode, endOffset) {
    var pieces = [];
    var on = false;
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n === startNode) {
        on = true;
      }
      if (!on) {
        continue;
      }
      var r = document.createRange();
      r.setStart(n, n === startNode ? startOffset : 0);
      r.setEnd(n, n === endNode ? endOffset : n.textContent.length);
      if (!r.collapsed) {
        pieces.push(r);
      }
      if (n === endNode) {
        break;
      }
    }
    return pieces;
  }

  /* Joins boxes that sit side by side on one line. */
  function mergeRects(rects, vertical) {
    var out = [];
    for (var i = 0; i < rects.length; i++) {
      var r = rects[i];
      if (!r.width || !r.height) {
        continue;
      }
      var box = { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
      var prev = out[out.length - 1];
      if (prev) {
        var sameLine = vertical
          ? Math.abs(prev.left - box.left) < 2 && Math.abs(prev.right - box.right) < 2 &&
            box.top - prev.bottom < 2 && box.bottom > prev.top
          : Math.abs(prev.top - box.top) < 2 && Math.abs(prev.bottom - box.bottom) < 2 &&
            box.left - prev.right < 2 && box.right > prev.left;
        if (sameLine) {
          prev.left = Math.min(prev.left, box.left);
          prev.top = Math.min(prev.top, box.top);
          prev.right = Math.max(prev.right, box.right);
          prev.bottom = Math.max(prev.bottom, box.bottom);
          continue;
        }
      }
      out.push(box);
    }
    return out;
  }

  function bookIsVertical() {
    var root = document.querySelector('.book-content');
    return !!root && /vertical/.test(getComputedStyle(root).writingMode);
  }

  /* Boxes behind the text only show if nothing between the book and the
   * page root paints a background. */
  function canDrawBehind() {
    var root = document.querySelector('.book-content');
    for (var el = root; el && el !== document.body; el = el.parentElement) {
      var cs = getComputedStyle(el);
      var bg = cs.backgroundColor;
      if (cs.backgroundImage !== 'none' || !(bg === 'transparent' || /rgba\(.*,\s*0\)$/.test(bg))) {
        return false;
      }
    }
    return !!root;
  }

  function layer(id, z) {
    var el = document.getElementById(id);
    if (!el) {
      el = document.createElement('div');
      el.id = id;
      el.setAttribute('aria-hidden', 'true');
      el.style.cssText =
        'position:fixed;left:0;top:0;width:0;height:0;pointer-events:none;z-index:' + z;
      document.body.appendChild(el);
    }
    return el;
  }

  function drawBoxes(target, ranges, fill, vertical) {
    var rects = [];
    for (var i = 0; i < ranges.length; i++) {
      var list = ranges[i].getClientRects();
      for (var j = 0; j < list.length; j++) {
        rects.push(list[j]);
      }
    }
    var boxes = mergeRects(rects, vertical);
    var html = '';
    for (var k = 0; k < boxes.length; k++) {
      var b = boxes[k];
      var padX = vertical ? 0 : PAD;
      var padY = vertical ? PAD : 0;
      html +=
        '<div style="position:absolute;left:' + (b.left - padX) + 'px;top:' + (b.top - padY) +
        'px;width:' + (b.right - b.left + padX * 2) + 'px;height:' + (b.bottom - b.top + padY * 2) +
        'px;border-radius:' + RADIUS + 'px;background:' + fill + '"></div>';
    }
    target.innerHTML = html;
  }

  var redrawQueued = false;
  function redraw() {
    if (redrawQueued) {
      return;
    }
    redrawQueued = true;
    requestAnimationFrame(function () {
      redrawQueued = false;
      if (word && word.layer) {
        drawBoxes(word.layer, word.ranges, HIGHLIGHT_FILL, word.vertical);
      }
      if (flashState) {
        drawBoxes(flashState.layer, flashState.ranges, flashState.fill, flashState.vertical);
      }
    });
  }

  /* Page turns scroll ッツ's container, so boxes follow the text. */
  window.addEventListener('scroll', function () {
    if (word || flashState) {
      redraw();
    }
    if (selectionShown) {
      queueSelection();
    }
  }, { capture: true, passive: true });
  window.addEventListener('resize', function () {
    if (word || flashState) {
      redraw();
    }
    if (selectionShown) {
      queueSelection();
    }
  }, { passive: true });

  /* ---------- rounded text selection ---------- */

  /*
   * A long-press selection is drawn the same way as the lookup highlight:
   * the browser's own selection colour is made transparent and rounded
   * boxes are drawn behind the selected text. The selection handles stay.
   */
  var SELECTION_FILL = 'rgba(255,0,0,0.42)';
  var selectionShown = false;
  var selectionQueued = false;

  /* One range per selected text node, furigana left out. Walks only from the
   * start of the selection to its end. */
  function selectedPieces(range) {
    var root = range.commonAncestorContainer;
    if (root.nodeType === Node.TEXT_NODE) {
      return isAnnotation(root) ? [] : [range];
    }
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        return isAnnotation(n) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
      },
    });
    var start = range.startContainer;
    if (start.nodeType !== Node.TEXT_NODE) {
      start = start.childNodes[range.startOffset] || start;
    }
    walker.currentNode = start;
    var node = start.nodeType === Node.TEXT_NODE && !isAnnotation(start) ? start : walker.nextNode();
    var pieces = [];
    while (node) {
      if (range.comparePoint(node, 0) > 0) {
        break;
      }
      if (range.intersectsNode(node)) {
        var r = document.createRange();
        r.setStart(node, node === range.startContainer ? range.startOffset : 0);
        r.setEnd(node, node === range.endContainer ? range.endOffset : node.textContent.length);
        if (!r.collapsed) {
          pieces.push(r);
        }
      }
      node = walker.nextNode();
    }
    return pieces;
  }

  function drawSelection() {
    selectionQueued = false;
    var target = document.getElementById('jdj-selection-layer');
    var selection = window.getSelection();
    if (!selection || selection.isCollapsed || !selection.rangeCount) {
      if (target) {
        target.innerHTML = '';
      }
      selectionShown = false;
      return;
    }
    if (!canDrawBehind()) {
      document.documentElement.classList.remove('jdj-round-selection');
      return;
    }
    document.documentElement.classList.add('jdj-round-selection');
    var pieces = [];
    for (var i = 0; i < selection.rangeCount; i++) {
      pieces = pieces.concat(selectedPieces(selection.getRangeAt(i)));
    }
    drawBoxes(layer('jdj-selection-layer', -1), pieces, SELECTION_FILL, bookIsVertical());
    selectionShown = true;
  }

  function queueSelection() {
    if (!selectionQueued) {
      selectionQueued = true;
      requestAnimationFrame(drawSelection);
    }
  }

  document.addEventListener('selectionchange', queueSelection);

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
    if (wordMode) {
      var probe = document.createRange();
      probe.setStart(startNode, startOffset);
      probe.setEnd(startNode, Math.min(startOffset + 1, startNode.textContent.length));
      if (typeof probe.expand === 'function') {
        probe.expand('word');
        if (nodes.indexOf(probe.startContainer) >= 0 && nodes.indexOf(probe.endContainer) >= 0) {
          startNode = probe.startContainer;
          startOffset = probe.startOffset;
          endNode = probe.endContainer;
          endOffset = probe.endOffset;
        }
      }
    }

    jdj.clearSelection();
    var ranges = piecesBetween(nodes, startNode, startOffset, endNode, endOffset);
    if (!ranges.length) {
      return;
    }
    word = { ranges: ranges, layer: null, vertical: bookIsVertical() };
    if (hasHighlightApi) {
      var behind = canDrawBehind();
      highlightStyle(behind);
      var highlight = new Highlight();
      ranges.forEach(function (r) {
        highlight.add(r);
      });
      CSS.highlights.set('jdj-word', highlight);
      if (behind) {
        word.layer = layer('jdj-word-layer', -1);
        drawBoxes(word.layer, ranges, HIGHLIGHT_FILL, word.vertical);
      }
    } else {
      var selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(ranges[0]);
    }
  };

  var HIGHLIGHT_STYLE_ID = 'jdj-word-style';
  function highlightStyle(behind) {
    var style = document.getElementById(HIGHLIGHT_STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = HIGHLIGHT_STYLE_ID;
      document.head.appendChild(style);
    }
    style.textContent = behind
      ? '::highlight(jdj-word){color:#fff}'
      : '::highlight(jdj-word){color:#fff;background-color:' + HIGHLIGHT_FILL + '}';
  }

  /* The highlighted text, for checks. */
  jdj.highlightedText = function () {
    if (!word) {
      return '';
    }
    return word.ranges.map(function (r) {
      return r.toString();
    }).join('');
  };

  jdj.clearSelection = function () {
    if (word) {
      if (word.layer) {
        word.layer.innerHTML = '';
      }
      if (hasHighlightApi) {
        CSS.highlights.delete('jdj-word');
      }
      word = null;
    }
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

  /*
   * Puts ッツ's saved position back to [characters], [progress] without
   * moving the page. Used after a visit to a memo or term, so the reader's
   * own place is kept.
   */
  jdj.writePosition = function (characters, progress) {
    var id = bookId();
    if (isNaN(id)) {
      return Promise.resolve(false);
    }
    return openBooks().then(function (db) {
      return new Promise(function (resolve, reject) {
        var tx = db.transaction('bookmark', 'readwrite');
        tx.objectStore('bookmark').put({
          dataId: id,
          exploredCharCount: characters,
          progress: progress,
          lastBookmarkModified: Date.now(),
        });
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

  jdj.readPosition = function () {
    var id = bookId();
    if (isNaN(id)) {
      return Promise.resolve(null);
    }
    return readBookmark(id).then(toPosition);
  };

  /* ---------- landing highlight after a jump ---------- */

  var FLASH_STYLE_ID = 'jdj-flash-style';
  var flashState = null;

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
      /* Rounded boxes that fade out in one CSS transition. */
      if (canDrawBehind()) {
        var target = layer('jdj-flash-layer', -1);
        target.style.transition = 'none';
        target.style.opacity = '1';
        flashState = { layer: target, ranges: [range], fill: 'rgba(244,67,54,0.34)', vertical: bookIsVertical() };
        drawBoxes(target, flashState.ranges, flashState.fill, flashState.vertical);
        return sleep(900).then(function () {
          target.style.transition = 'opacity 700ms ease-out';
          target.style.opacity = '0';
          return sleep(720);
        }).then(function () {
          target.innerHTML = '';
          flashState = null;
          return true;
        });
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

  /* ---------- memos on the page ---------- */

  /*
   * Each memo's quoted passage gets a soft amber mark behind the text, and a
   * small note above it with the start of the memo. Tapping the note asks
   * the app to show the whole memo. Only memos on screen are drawn.
   */
  var MEMO_FILL = 'rgba(255,193,7,0.26)';
  var memoState = null;
  var memosQueued = false;

  /* The characters ッツ counts for its positions: letters, digits, kana and
   * kanji, as in its own reader. */
  var UNCOUNTED = /[^0-9A-Z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]+/gimu;
  var COUNTED = /[0-9A-Z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]/iu;

  /* All book text with where each text node starts, in text and in ッツ's
   * count, furigana left out. */
  function indexBook(root) {
    var nodes = textNodesOf(root);
    var starts = [];
    var counts = [];
    var text = '';
    var counted = 0;
    for (var i = 0; i < nodes.length; i++) {
      var content = nodes[i].textContent;
      starts.push(text.length);
      counts.push(counted);
      text += content;
      counted += content.replace(UNCOUNTED, '').length;
    }
    return { nodes: nodes, starts: starts, counts: counts, text: text };
  }

  /* The text offset where ッツ's count reaches [count]. */
  function offsetOfCount(index, count) {
    var lo = 0;
    var hi = index.nodes.length - 1;
    while (lo < hi) {
      var mid = (lo + hi + 1) >> 1;
      if (index.counts[mid] <= count) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    var content = index.nodes[lo] ? index.nodes[lo].textContent : '';
    var counted = index.counts[lo] || 0;
    for (var i = 0; i < content.length; i++) {
      if (counted >= count) {
        return index.starts[lo] + i;
      }
      if (COUNTED.test(content[i])) {
        counted++;
      }
    }
    return (index.starts[lo] || 0) + content.length;
  }

  function locateIn(index, offset) {
    var lo = 0;
    var hi = index.nodes.length - 1;
    while (lo < hi) {
      var mid = (lo + hi + 1) >> 1;
      if (index.starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return { node: index.nodes[lo], offset: offset - index.starts[lo] };
  }

  /* One range per text node for [at, at + length) of the book text. */
  function rangesIn(index, at, length) {
    var a = locateIn(index, at);
    var b = locateIn(index, at + length - 1);
    return piecesBetween(index.nodes, a.node, a.offset, b.node, b.offset + 1);
  }

  /* The quoted passage as it appears in the book: its longest line, since a
   * selection across paragraphs has line breaks the page text does not. */
  function passageOf(excerpt) {
    var lines = String(excerpt || '').split(/\n+/).map(function (line) {
      return line.trim();
    }).filter(function (line) {
      return line.length > 0;
    });
    lines.sort(function (a, b) {
      return b.length - a.length;
    });
    return lines[0] || '';
  }

  /*
   * ッツ keeps only the current chapter in the page, while its positions
   * count from the start of the book, and nothing in the page says which
   * chapter it is. Chapters differ in length, so the chapter is the one
   * whose stored length matches the page's; [hint], a position known to be
   * in the page, settles ties.
   */
  function pageStartCount(index, hint) {
    return jdj.chapters().then(function (book) {
      var sections = (book && book.sections) || [];
      if (!sections.length) {
        return 0;
      }
      var last = index.nodes.length - 1;
      var total = last < 0 ? 0 : index.counts[last] + index.nodes[last].textContent.replace(UNCOUNTED, '').length;
      var root = document.querySelector('.book-content');
      total += root ? root.querySelectorAll('img, image').length : 0;

      /* A chapter alone, or with the sections nested under it. */
      var blocks = [];
      sections.forEach(function (section, i) {
        blocks.push({ start: section.start, characters: section.characters });
        if (!section.parent) {
          var sum = section.characters;
          for (var j = i + 1; j < sections.length && sections[j].parent; j++) {
            sum += sections[j].characters;
          }
          if (sum !== section.characters) {
            blocks.push({ start: section.start, characters: sum });
          }
        }
      });
      var tolerance = Math.max(5, total * 0.01);
      var close = blocks.filter(function (block) {
        return Math.abs(block.characters - total) <= tolerance;
      });
      if (!close.length) {
        close = [blocks.reduce(function (a, b) {
          return Math.abs(a.characters - total) <= Math.abs(b.characters - total) ? a : b;
        })];
      }
      if (close.length > 1 && hint >= 0) {
        var inside = close.filter(function (block) {
          return hint >= block.start && hint < block.start + block.characters;
        });
        if (inside.length) {
          return inside[0].start;
        }
      }
      return close[0].start;
    }).catch(function () {
      return 0;
    });
  }

  var lastMemos = null;
  var lastHint = -1;

  jdj.showMemos = function (memos, hint) {
    lastMemos = memos || [];
    lastHint = typeof hint === 'number' ? hint : -1;
    var root = document.querySelector('.book-content');
    if (!root) {
      return Promise.resolve(0);
    }
    var index = indexBook(root);
    return pageStartCount(index, lastHint).then(function (base) {
      return placeMemos(index, base, lastMemos);
    });
  };

  /* ッツ swaps in the next chapter as pages turn; place the memos again. */
  var replaceTimer = null;
  new MutationObserver(function (records) {
    if (!lastMemos || !lastMemos.length) {
      return;
    }
    var inBook = records.some(function (record) {
      return record.target.closest && record.target.closest('.book-content');
    });
    if (!inBook) {
      return;
    }
    clearTimeout(replaceTimer);
    replaceTimer = setTimeout(function () {
      jdj.showMemos(lastMemos, -1);
    }, 300);
  }).observe(document.body || document.documentElement, { childList: true, subtree: true });
  function placeMemos(index, base, memos) {
    var items = [];
    (memos || []).forEach(function (memo) {
      var passage = passageOf(memo.excerpt);
      if (!passage) {
        return;
      }
      /* The memo's place is the start of the page it was written on, so the
       * passage is the first match from there; a little slack allows for
       * pictures, which ッツ counts and the text does not. */
      var from = memo.characters > 0
        ? offsetOfCount(index, Math.max(0, memo.characters - base))
        : Math.round((memo.progress || 0) * index.text.length);
      var best = index.text.indexOf(passage, Math.max(0, from - 40));
      if (best < 0) {
        var distance = Infinity;
        for (var at = index.text.indexOf(passage); at >= 0; at = index.text.indexOf(passage, at + 1)) {
          if (Math.abs(at - from) < distance) {
            best = at;
            distance = Math.abs(at - from);
          }
        }
      }
      if (best >= 0) {
        items.push({ id: memo.id, text: memo.text || '', ranges: rangesIn(index, best, passage.length) });
      }
    });
    memoState = items.length ? { items: items } : null;
    drawMemos();
    return items.length;
  }

  function onScreen(rect) {
    return rect.width && rect.right > 0 && rect.left < window.innerWidth &&
      rect.bottom > 0 && rect.top < window.innerHeight;
  }

  function drawMemos() {
    memosQueued = false;
    var marks = layer('jdj-memo-marks', -1);
    var notes = layer('jdj-memo-notes', 2147482000);
    if (!memoState || !canDrawBehind()) {
      marks.innerHTML = '';
      notes.innerHTML = '';
      return;
    }
    var vertical = bookIsVertical();
    var shown = [];
    memoState.items.forEach(function (item) {
      var rects = [];
      item.ranges.forEach(function (range) {
        var list = range.getClientRects();
        for (var i = 0; i < list.length; i++) {
          if (onScreen(list[i])) {
            rects.push(list[i]);
          }
        }
      });
      if (rects.length) {
        shown.push({ item: item, rects: rects });
      }
    });

    var html = '';
    shown.forEach(function (entry) {
      mergeRects(entry.rects, vertical).forEach(function (b) {
        html += '<div style="position:absolute;left:' + b.left + 'px;top:' + b.top +
          'px;width:' + (b.right - b.left) + 'px;height:' + (b.bottom - b.top) +
          'px;border-radius:' + RADIUS + 'px;background:' + MEMO_FILL + '"></div>';
      });
    });
    marks.innerHTML = html;

    notes.innerHTML = '';
    var page = getComputedStyle(document.body);
    var root = document.querySelector('.book-content');
    var ink = root ? getComputedStyle(root).color : page.color;
    shown.forEach(function (entry) {
      var first = entry.rects[0];
      var note = document.createElement('div');
      note.className = 'jdj-memo-note';
      note.setAttribute('data-memo', String(entry.item.id));
      note.textContent = entry.item.text || '…';
      note.style.cssText =
        'position:absolute;pointer-events:auto;cursor:pointer;box-sizing:border-box;' +
        'font:500 11px/16px system-ui,sans-serif;white-space:nowrap;overflow:hidden;' +
        'text-overflow:ellipsis;padding:0 7px;border-radius:8px;' +
        'border:1px solid rgba(255,193,7,0.75);background:' + page.backgroundColor + ';' +
        'color:' + ink + ';box-shadow:0 1px 4px rgba(0,0,0,0.25);';
      if (vertical) {
        note.style.writingMode = 'vertical-rl';
        note.style.maxHeight = '40vh';
        note.style.padding = '7px 0';
        note.style.left = Math.min(window.innerWidth - 20, first.right + 2) + 'px';
        note.style.top = Math.max(4, first.top) + 'px';
      } else {
        note.style.maxWidth = Math.min(260, window.innerWidth * 0.7) + 'px';
        note.style.left = Math.max(4, Math.min(first.left, window.innerWidth - 120)) + 'px';
        note.style.top = (first.top > 22 ? first.top - 18 : first.bottom + 2) + 'px';
      }
      notes.appendChild(note);
    });
  }

  function queueMemos() {
    if (memoState && !memosQueued) {
      memosQueued = true;
      requestAnimationFrame(drawMemos);
    }
  }

  window.addEventListener('scroll', queueMemos, { capture: true, passive: true });
  window.addEventListener('resize', queueMemos, { passive: true });

  /* ---------- chapters ---------- */

  /* The book's chapters as ッツ stored them, with its character count. */
  jdj.chapters = function () {
    var id = bookId();
    if (isNaN(id)) {
      return Promise.resolve(null);
    }
    return openBooks().then(function (db) {
      return new Promise(function (resolve, reject) {
        var request = db.transaction('data', 'readonly').objectStore('data').get(id);
        request.onsuccess = function () {
          var book = request.result;
          if (!book) {
            resolve(null);
            return;
          }
          resolve({
            characters: book.characters || 0,
            sections: (book.sections || []).map(function (s) {
              return {
                label: s.label || '',
                reference: s.reference || '',
                start: s.startCharacter || 0,
                characters: s.characters || 0,
                parent: s.parentChapter || null,
              };
            }),
          });
        };
        request.onerror = function () {
          reject(request.error);
        };
      }).finally(function () {
        db.close();
      });
    });
  };

  /* ---------- live preview of page settings ---------- */

  /*
   * Shows page settings on the book straight away while the settings sheet
   * is open. ッツ applies them properly when the book reloads afterwards.
   */
  var PREVIEW_STYLE_ID = 'jdj-preview-style';

  jdj.preview = function (p) {
    var root = document.querySelector('.book-content');
    var style = document.getElementById(PREVIEW_STYLE_ID);
    if (!style) {
      style = document.createElement('style');
      style.id = PREVIEW_STYLE_ID;
      document.head.appendChild(style);
    }
    var vertical = !!root && /vertical/.test(getComputedStyle(root).writingMode);
    var css = '.book-content{' +
      'font-size:' + p.fontSize + 'px!important;' +
      'line-height:' + p.lineHeight + '!important;' +
      'font-family:' + (p.fontFamily ? '"' + p.fontFamily + '",' : '') + '"Noto Serif JP",serif!important;' +
      (vertical
        ? 'padding-left:' + p.margin + 'px!important;padding-right:' + p.margin + 'px!important;'
        : 'padding-top:' + p.margin + 'px!important;padding-bottom:' + p.margin + 'px!important;') +
      (p.foreground ? 'color:' + p.foreground + '!important;' : '') +
      '}';
    if (p.background) {
      css += 'html,body{background-color:' + p.background + '!important}';
    }
    style.textContent = css;
    if (root) {
      var classes = root.classList;
      classes.toggle('book-content--hide-spoiler-image', !!p.blurImages);
      classes.toggle('book-content--avoid-page-break', !!p.avoidPageBreak);
      if (p.furigana !== undefined) {
        classes.toggle('book-content--hide-furigana', !p.furigana);
        ['partial', 'full', 'toggle'].forEach(function (name) {
          classes.toggle('book-content--furigana-style-' + name, p.furiganaStyle === name);
        });
      }
    }
    if (window.__jdjFit) {
      window.__jdjFit.run();
    }
    if (word || flashState) {
      redraw();
    }
    queueMemos();
  };

  /* ッツ's own fonts, and fonts the user added in ッツ's settings. */
  jdj.userFonts = function () {
    try {
      var fonts = JSON.parse(localStorage.getItem('userfonts') || '[]');
      return fonts.map(function (font) {
        return font && (font.name || font.fontName || String(font));
      }).filter(Boolean);
    } catch (_) {
      return [];
    }
  };

  /* Unselectable furigana, and selection colours: drawn as rounded boxes
   * where possible, the browser's own square selection otherwise. ッツ's own
   * header is replaced by the app's menu. */
  var style = document.createElement('style');
  style.textContent =
    'button.fixed.inset-x-0.top-0.h-8{display:none!important}' +
    'rt,rp{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}' +
    '::selection{color:white;background:rgba(255,0,0,0.6)}' +
    'html.jdj-round-selection ::selection{color:inherit;background:transparent}';
  (document.head || document.documentElement).appendChild(style);
})();
