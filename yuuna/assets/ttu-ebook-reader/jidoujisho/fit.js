/*
 * jidoujisho: keeps wide book content inside the page.
 *
 * A formula or table wider than the page pushes ッツ's page columns out of
 * line, so every page after it is cut off. Such elements are shrunk to fit
 * and marked; tapping one shows it at full size in a viewer above the page.
 * Long code lines wrap instead.
 *
 * Runs at document start so the fix is in place before ッツ lays out a book.
 */
(function () {
  'use strict';

  if (window.__jdjFit) {
    return;
  }
  var fit = (window.__jdjFit = {});

  var CANDIDATES = 'math, table, svg';
  var MARK = 'data-jdj-fit';

  function addStyle() {
    var style = document.createElement('style');
    style.id = 'jdj-fit-style';
    style.textContent =
      /* Nothing in a book may widen the page itself. */
      '.book-content[class*="writing-horizontal"]{overflow-x:clip!important}' +
      '.book-content[class*="writing-vertical"]{overflow-y:clip!important}' +
      '.book-content pre{white-space:pre-wrap!important;overflow-wrap:anywhere!important}' +
      '.book-content svg{max-inline-size:100%}' +
      '.book-content [' + MARK + ']{cursor:zoom-in}' +
      '#jdj-viewer{position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;' +
      'justify-content:center;background:rgba(0,0,0,.6);padding:16px;box-sizing:border-box;' +
      'animation:jdj-viewer-in .14s ease-out}' +
      '#jdj-viewer .jdj-panel{position:relative;max-width:100%;max-height:100%;overflow:auto;' +
      'border-radius:18px;box-shadow:0 8px 32px rgba(0,0,0,.4);box-sizing:border-box;' +
      'padding:44px 18px 18px;overscroll-behavior:contain;-webkit-overflow-scrolling:touch}' +
      '#jdj-viewer .jdj-bar{position:sticky;top:-44px;margin:-44px -18px 8px;height:40px;display:flex;' +
      'justify-content:flex-end;gap:4px;padding:4px 6px 0}' +
      '#jdj-viewer button{width:36px;height:36px;border:0;border-radius:18px;background:rgba(128,128,128,.18);' +
      'color:inherit;font:600 18px/36px sans-serif;padding:0}' +
      '#jdj-viewer .jdj-body{width:max-content;max-width:none}' +
      '@keyframes jdj-viewer-in{from{opacity:0}to{opacity:1}}' +
      '@media (prefers-reduced-motion: reduce){#jdj-viewer{animation:none}}';
    (document.head || document.documentElement).appendChild(style);
  }

  function isVertical(root) {
    return /vertical/.test(getComputedStyle(root).writingMode);
  }

  /* The inline size of the nearest block around [el]: the column it sits in. */
  function available(el, root, vertical) {
    for (var node = el.parentElement; node; node = node.parentElement) {
      var cs = getComputedStyle(node);
      if (cs.display.indexOf('inline') === 0 || cs.display === 'contents') {
        if (node === root) {
          break;
        }
        continue;
      }
      var size = parseFloat(vertical ? cs.height : cs.width);
      if (node === root) {
        var column = parseFloat(cs.columnWidth);
        if (!isNaN(column) && column > 0) {
          size = isNaN(size) ? column : Math.min(size, column);
        }
      }
      if (!isNaN(size) && size > 0) {
        return size;
      }
      if (node === root) {
        break;
      }
    }
    return vertical ? window.innerHeight : window.innerWidth;
  }

  /*
   * How far an element's content reaches in the inline direction. A block
   * formula's own box is only as wide as the column while its content spills
   * past it, so the content is measured too.
   */
  var probe = null;
  function extent(el, vertical) {
    var rect = el.getBoundingClientRect();
    var size = vertical ? rect.height : rect.width;
    probe = probe || document.createRange();
    probe.selectNodeContents(el);
    var inner = probe.getBoundingClientRect();
    size = Math.max(size, vertical ? inner.height : inner.width);
    var scroll = vertical ? el.scrollHeight : el.scrollWidth;
    return Math.max(size, scroll || 0);
  }

  function outermost(list) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var el = list[i];
      var parent = el.parentElement;
      if (parent && parent.closest(CANDIDATES)) {
        continue;
      }
      out.push(el);
    }
    return out;
  }

  /* Reset, measure, then shrink, so the page lays out at most twice. */
  fit.run = function () {
    var root = document.querySelector('.book-content');
    if (!root) {
      return 0;
    }
    var vertical = isVertical(root);
    var els = outermost(root.querySelectorAll(CANDIDATES));
    var i;
    for (i = 0; i < els.length; i++) {
      if (els[i].style.zoom) {
        els[i].style.zoom = '';
      }
    }
    var plan = [];
    for (i = 0; i < els.length; i++) {
      var el = els[i];
      var size = extent(el, vertical);
      var room = available(el, root, vertical);
      plan.push(size > room + 1 ? room / size : 0);
    }
    var fitted = [];
    for (i = 0; i < els.length; i++) {
      if (plan[i] > 0) {
        els[i].style.zoom = String(Math.floor(plan[i] * 1000) / 1000);
        els[i].setAttribute(MARK, '');
        fitted.push(els[i]);
      } else if (els[i].hasAttribute(MARK)) {
        els[i].removeAttribute(MARK);
      }
    }
    /* Some content, such as a fraction bar, grows with its box; one more
     * pass takes up what is left over. */
    var again = [];
    for (i = 0; i < fitted.length; i++) {
      var over = extent(fitted[i], vertical);
      var space = available(fitted[i], root, vertical);
      again.push(over > space + 1 ? space / over : 1);
    }
    for (i = 0; i < fitted.length; i++) {
      if (again[i] < 1) {
        var zoom = parseFloat(fitted[i].style.zoom) * again[i];
        fitted[i].style.zoom = String(Math.floor(zoom * 1000) / 1000);
      }
    }
    return fitted.length;
  };

  var scheduled = false;
  function schedule() {
    if (scheduled) {
      return;
    }
    scheduled = true;
    requestAnimationFrame(function () {
      scheduled = false;
      fit.run();
    });
  }

  function ours(node) {
    return node.nodeType === 1 && node.id && node.id.indexOf('jdj-') === 0;
  }

  /* Only book content changes matter; the app's own overlays are ignored. */
  function relevant(records) {
    for (var i = 0; i < records.length; i++) {
      var added = records[i].addedNodes;
      for (var j = 0; j < added.length; j++) {
        if (!ours(added[j])) {
          return true;
        }
      }
    }
    return false;
  }

  /* ---------- viewer ---------- */

  var viewer = null;
  var viewerZoom = 1;

  fit.close = function () {
    if (!viewer) {
      return false;
    }
    viewer.remove();
    viewer = null;
    return true;
  };

  fit.isOpen = function () {
    return !!viewer;
  };

  function stop(e) {
    e.stopPropagation();
  }

  fit.open = function (el) {
    fit.close();
    var root = document.querySelector('.book-content') || document.body;
    var page = getComputedStyle(document.body);
    var text = getComputedStyle(root);

    viewer = document.createElement('div');
    viewer.id = 'jdj-viewer';
    var panel = document.createElement('div');
    panel.className = 'jdj-panel';
    panel.style.background = page.backgroundColor;
    panel.style.color = text.color;
    panel.style.fontSize = text.fontSize;
    panel.style.fontFamily = text.fontFamily;

    var bar = document.createElement('div');
    bar.className = 'jdj-bar';
    var body = document.createElement('div');
    body.className = 'jdj-body';
    body.style.writingMode = getComputedStyle(el.parentElement || root).writingMode;
    var clone = el.cloneNode(true);
    clone.removeAttribute(MARK);
    clone.style.zoom = '';
    body.appendChild(clone);
    viewerZoom = 1;

    function button(label, title, onTap) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.setAttribute('aria-label', title);
      b.addEventListener('click', function (e) {
        e.stopPropagation();
        onTap();
      });
      bar.appendChild(b);
    }
    button('−', 'Smaller', function () {
      viewerZoom = Math.max(0.5, viewerZoom - 0.25);
      body.style.zoom = String(viewerZoom);
    });
    button('+', 'Larger', function () {
      viewerZoom = Math.min(3, viewerZoom + 0.25);
      body.style.zoom = String(viewerZoom);
    });
    button('×', 'Close', fit.close);

    panel.appendChild(bar);
    panel.appendChild(body);
    viewer.appendChild(panel);

    /* Keep ッツ from turning pages or toggling its header underneath. */
    ['click', 'pointerdown', 'pointerup', 'pointermove', 'mousedown', 'mouseup',
      'touchstart', 'touchmove', 'touchend', 'wheel', 'contextmenu'].forEach(function (type) {
      viewer.addEventListener(type, stop, { passive: true });
    });
    viewer.addEventListener('click', function (e) {
      if (e.target === viewer) {
        fit.close();
      }
    });
    document.body.appendChild(viewer);
  };

  function start() {
    addStyle();
    new MutationObserver(function (records) {
      if (relevant(records)) {
        schedule();
      }
    }).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener('resize', schedule, { passive: true });
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(schedule);
      document.fonts.addEventListener('loadingdone', schedule);
    }
    schedule();
  }

  if (document.documentElement) {
    start();
  } else {
    document.addEventListener('DOMContentLoaded', start);
  }
})();
