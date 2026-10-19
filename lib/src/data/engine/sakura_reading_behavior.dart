/// Reading behaviour sakura_epub doesn't expose as settings, added by
/// patching its epub.js rendition from the outside (the package's page
/// script keeps `rendition` and `book` as globals).
///
/// - Chapter scroll: in scrolled flow, sakura always uses epub.js's
///   "continuous" manager, which keeps appending the next/previous chapter
///   as you scroll. Wrapping the manager's `check()` stops that, so vertical
///   scrolling stays inside the current chapter.
/// - Gestures: the package's own swipe detector is disabled. In scrolled
///   mode a vertical drag only scrolls the current chapter (never into the
///   next one), and a horizontal drag is a lock-swipe that reports its
///   progress to Flutter and changes chapter only when released full. In
///   paginated mode a quick horizontal swipe turns the page.
library;

import 'dart:convert';

import 'package:sakura_epub/sakura_epub.dart';

class SakuraReadingBehavior {
  SakuraReadingBehavior._();

  // Saved locations: load them so percentages, page counts and jumping
  // work at once, and stop the background pass from re-counting.
  static const String _locationsScript = r'''
(function (json) {
  try {
    if (typeof book === 'undefined' || !book.locations) return -1;
    book.locations.load(json);
    // Sections still queued from sakura's generate() add nothing now.
    book.locations.parse = function () { return []; };
    book.locations.pause = 0;
    window.__areadLocationsCached = json;
    try { rendition.reportLocation(); } catch (e) {}
    return book.locations.length();
  } catch (e) { return -1; }
})
''';

  static const String _script = r'''
(function (chapterScroll, marginHorizontal, bgColor, restoreCfi, pageCurl) {
  if (typeof rendition === 'undefined' || !rendition || !rendition.manager) return false;
  var r = rendition;
  var m = r.manager;
  // The element that actually scrolls: epub.js's stage container
  // (.epub-container). #viewer only wraps it and never scrolls itself.
  var scroller = function () {
    try { if (rendition.manager && rendition.manager.container) return rendition.manager.container; } catch (e) {}
    return document.getElementById('viewer');
  };
  var margin = (typeof marginHorizontal === 'number' && marginHorizontal >= 0) ? marginHorizontal : 0;

  if (bgColor && typeof bgColor === 'string' && bgColor !== 'null') {
    try {
      document.documentElement.style.backgroundColor = bgColor;
      document.body.style.backgroundColor = bgColor;
    } catch (e) {}
  }

  // Disable buggy swipe detector in epubView.js that calls e.preventDefault() on touchmove
  window.detectSwipe = function () {};

  // Patch window._injectFontCSS so it doesn't crush book styles with !important on child tags
  window._injectFontCSS = function (contents, fontFamily, fontBase64, fontMimeType) {
    if (!contents || !contents.document) return;
    var doc = contents.document;
    var old = doc.getElementById('sakura-font-style');
    if (old) old.remove();
    if (!fontFamily) return;
    var style = doc.createElement('style');
    style.id = 'sakura-font-style';
    var css = '';
    if (fontBase64) {
      css += "@font-face {\n" +
        "  font-family: '" + fontFamily + "';\n" +
        "  src: url('data:" + (fontMimeType || 'font/truetype') + ";base64," + fontBase64 + "') format('truetype');\n" +
        "  font-weight: 100 900;\n" +
        "  font-style: normal;\n" +
        "}\n";
    }
    // Books set fonts on p/span/div themselves, so a plain body rule loses.
    // Every text element gets the family; weight/style stay the book's own.
    var stack = "'" + fontFamily + "', Georgia, serif";
    css += "html body, body p, body div, body span, body li, body td, body th, body blockquote, " +
      "body a, body em, body i, body strong, body b, body cite, body dd, body dt, body section, " +
      "body article, body h1, body h2, body h3, body h4, body h5, body h6, body sup, body sub, body small {\n" +
      "  font-family: " + stack + " !important;\n" +
      "}\n" +
      "body { -webkit-font-synthesis: weight style; font-synthesis: weight style; }\n";
    css += "code, pre, kbd, samp { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace !important; }\n";
    style.textContent = css;
    if (doc.head) doc.head.appendChild(style);
  };

  if (typeof _currentFontFamily !== 'undefined' && _currentFontFamily && rendition) {
    try {
      rendition.getContents().forEach(function (c) {
        window._injectFontCSS(c, _currentFontFamily, _currentFontBase64, _currentFontMimeType);
      });
    } catch (e) {}
  }

  // Inject scroll & container styles for proper continuous scrolling and paginated flow
  var style = document.getElementById('aread-flow-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'aread-flow-style';
    document.head.appendChild(style);
  }
  if (chapterScroll) {
    style.innerHTML = '\
      html, body {\
        width: 100% !important;\
        height: 100% !important;\
        overflow: hidden !important;\
        margin-left: auto !important;\
        margin-right: auto !important;\
        padding: 0 !important;\
        background-color: transparent !important;\
      }\
      #viewer, #viewer.scrolled {\
        overflow-y: auto !important;\
        overflow-x: hidden !important;\
        width: 100% !important;\
        max-width: 100% !important;\
        height: 100% !important;\
        margin-left: auto !important;\
        margin-right: auto !important;\
        padding: 0 !important;\
        border: none !important;\
        box-shadow: none !important;\
        -webkit-overflow-scrolling: touch !important;\
        touch-action: pan-y !important;\
        box-sizing: border-box !important;\
        background-color: transparent !important;\
        scrollbar-width: none !important;\
      }\
      #viewer::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }\
      .epub-container {\
        width: 100% !important;\
        height: 100% !important;\
      }\
      .epub-view {\
        width: 100% !important;\
      }\
      .epub-view > iframe {\
        width: 100% !important;\
        border: none !important;\
      }\
    ';
  } else {
    style.innerHTML = '\
      html, body {\
        width: 100% !important;\
        height: 100% !important;\
        overflow: hidden !important;\
        margin: 0 !important;\
        padding: 0 !important;\
        background-color: transparent !important;\
      }\
      #viewer {\
        overflow: hidden !important;\
        width: 100% !important;\
        max-width: 100% !important;\
        height: 100% !important;\
        margin: 0 !important;\
        padding: 0 !important;\
        border: none !important;\
        box-shadow: none !important;\
        touch-action: pan-x pan-y !important;\
        background-color: transparent !important;\
      }\
      .epub-container {\
        width: 100% !important;\
        height: 100% !important;\
      }\
      .epub-view > iframe {\
        border: none !important;\
      }\
    ';
  }

  // Paint the page colour into the page itself: the WebView is transparent,
  // and its snapshots (zoomed cards, page curl, opening picture) turned the
  // transparent areas - e.g. below a short chapter - black.
  if (bgColor && typeof bgColor === 'string' && bgColor !== 'null') {
    style.innerHTML += ' html, body, #viewer, .epub-container { background-color: ' + bgColor + ' !important; }';
  }

  // --- keep scrolling within the current chapter -------------------------
  if (!m.__areadCheck) {
    m.__areadCheck = m.check;
    m.check = function () {
      if (window.__areadChapterScroll) {
        if (m.q && typeof m.update === 'function') {
          m.q.enqueue(function () { m.update(); });
        }
        return Promise.resolve(false);
      }
      // A neighbour chapter destroyed mid-render never resolves its
      // display promise, and check() waits on it - which froze the whole
      // render queue (no more relocated events: progress stuck at 0%,
      // position never saved, flow switches ignored). Cap the wait.
      var checking = m.__areadCheck.apply(m, arguments);
      return Promise.race([
        Promise.resolve(checking),
        new Promise(function (resolve) { setTimeout(function () { resolve(false); }, 2500); })
      ]);
    };
  }
  window.__areadChapterScroll = !!chapterScroll;
  // Paginated swipes are drawn as a page curl by Flutter (see the turn
  // handlers below) instead of turning the page here.
  window.__areadCurl = !!pageCurl;
  // Text padding: scrolled mode pads the page body (see injectContentStyle);
  // paginated mode lets epub.js do it - it pads each page by gap/2 per side.
  window.__areadPad = margin;
  try { if (m.settings) m.settings.gap = margin * 2; } catch (e) {}

  window.__areadShiftTop = function (px) {
    var c = scroller();
    if (!c) return;
    if (!window.__areadChapterScroll) px = 0;
    c.style.transition = 'transform 260ms cubic-bezier(0.2, 0.8, 0.2, 1)';
    c.style.transform = px ? 'translateY(' + px + 'px)' : '';
  };
  if (!chapterScroll) { var sc = scroller(); if (sc) { sc.style.transform = ''; } }

  // Re-applying (flow switch etc.) clears any half-finished animation.
  var vw = document.getElementById('viewer');
  if (vw) { vw.style.transition = 'none'; vw.style.transform = ''; vw.style.opacity = '1'; }
  if (r.__areadResetBusy) r.__areadResetBusy();

  var injectContentStyle = function (doc) {
    if (!doc || !doc.head) return;
    var cs = doc.getElementById('aread-iframe-style');
    if (!cs) {
      cs = doc.createElement('style');
      cs.id = 'aread-iframe-style';
      doc.head.appendChild(cs);
    }
    // Fit oversized media while leaving each publication's typography,
    // spacing, semantic tags, and table layout intact.
    var baseFitCss = '\
      img, svg, video, audio, object, embed, canvas {\
        max-width: 100% !important;\
        height: auto !important;\
      }\
      svg { max-height: 100vh !important; }\
      table { max-width: 100% !important; }\
    ';

    var pad = (typeof window.__areadPad === 'number') ? window.__areadPad : 24;
    // Book layout: symmetric side padding, a centred text column capped at a
    // comfortable line length (~40em, i.e. roughly 65-75 characters), centred
    // block images, and breathing room at the chapter start/end. Publisher
    // typography (indents, headings, paragraph spacing) is left alone.
    var bookCss = '\
      p > img:only-child, div > img:only-child, figure img {\
        display: block !important;\
        margin-left: auto !important;\
        margin-right: auto !important;\
      }\
      p { orphans: 2; widows: 2; }\
    ';
    if (window.__areadChapterScroll) {
      cs.innerHTML = baseFitCss + bookCss + '\
        html, body {\
          touch-action: pan-y !important;\
          -webkit-overflow-scrolling: touch !important;\
          overflow-y: visible !important;\
          height: auto !important;\
        }\
        html { padding: 0 !important; margin: 0 !important; }\
        body {\
          box-sizing: border-box !important;\
          padding-left: ' + pad + 'px !important;\
          padding-right: ' + pad + 'px !important;\
          padding-top: 24px !important;\
          padding-bottom: 64px !important;\
          max-width: calc(40em + ' + (pad * 2) + 'px) !important;\
          margin-left: auto !important;\
          margin-right: auto !important;\
        }\
      ';
    } else {
      cs.innerHTML = baseFitCss + bookCss + '\
        html, body {\
          touch-action: pan-x pan-y !important;\
          height: 100% !important;\
        }\
      ';
    }
  };

  // --- smooth page / chapter moves -------------------------------------
  if (!r.__areadNext) {
    r.__areadNext = r.next.bind(r);
    r.__areadPrev = r.prev.bind(r);

    var busy = false;
    r.__areadResetBusy = function () { busy = false; };
    var viewer = scroller;

    // Tell Flutter a swipe navigated, so it doesn't also count the gesture
    // as a tap (the page's touch forwarding can report a swipe's end at its
    // start point).
    var notify = function (dir) {
      try { window.flutter_inappwebview.callHandler('areadNavigated', dir); } catch (e) {}
    };

    var navigate = function (dir, action) {
      if (busy) return;
      busy = true;
      notify(dir);
      try {
        Promise.resolve(action()).then(function () {
          setTimeout(function () { busy = false; }, 180);
        }, function () {
          busy = false;
        });
      } catch (e) {
        busy = false;
      }
    };

    // A little rubber-band when there's nowhere to go.
    var bounce = function (dir) {
      var v = viewer();
      if (!v || busy) return;
      v.style.transition = 'transform 120ms ease-out';
      v.style.transform = 'translateX(' + (dir > 0 ? -12 : 12) + 'px)';
      setTimeout(function () {
        v.style.transform = 'translateX(0)';
        setTimeout(function () { v.style.transition = ''; }, 120);
      }, 120);
    };

    // --- chapter units -----------------------------------------------------
    // A "chapter" is a spine section's start plus every TOC anchor inside
    // it. Books like Project Gutenberg's Alice keep all chapters in ONE
    // spine file (each chapter is an #anchor), so spine-only chapters would
    // let scrolling run through the whole book and leave swipes nowhere to go.
    var tocAnchorsBySection = null;
    var buildTocIndex = function () {
      tocAnchorsBySection = {};
      var walk = function (items) {
        (items || []).forEach(function (it) {
          if (it && it.href) {
            var parts = it.href.split('#');
            var sec = book.spine.get(parts[0]) || book.spine.get(it.href);
            if (!sec) {
              // nav hrefs can be relative to a nav doc in another folder
              var base = parts[0].split('/').pop();
              for (var i = 0; i < book.spine.spineItems.length && !sec; i++) {
                var s = book.spine.spineItems[i];
                if (s && s.href && s.href.split('/').pop() === base) sec = s;
              }
            }
            if (sec && parts[1]) {
              (tocAnchorsBySection[sec.index] = tocAnchorsBySection[sec.index] || []).push(parts[1]);
            }
          }
          walk(it && it.subitems);
        });
      };
      try { walk(book.navigation && book.navigation.toc); } catch (e) {}
    };

    var currentIndex = function () {
      var loc = r.currentLocation();
      var idx = loc && loc.start ? loc.start.index : undefined;
      if (idx === undefined && r.location && r.location.start) idx = r.location.start.index;
      return idx;
    };
    var currentView = function () {
      try { return m.views && (m.views.first ? m.views.first() : m.views._views[0]); } catch (e) { return null; }
    };
    // Unit start offsets (in #viewer scroll coordinates) for the displayed
    // section, ascending, always beginning with 0.
    var unitTops = function () {
      if (!tocAnchorsBySection) buildTocIndex();
      var idx = currentIndex();
      var tops = [0];
      var v = viewer(), view = currentView();
      var anchors = idx === undefined ? null : tocAnchorsBySection[idx];
      if (!v || !view || !view.element || !anchors || !view.contents || !view.contents.document) return tops;
      var viewTop = view.element.getBoundingClientRect().top - v.getBoundingClientRect().top + v.scrollTop;
      anchors.forEach(function (id) {
        var el = view.contents.document.getElementById(id);
        if (!el) return;
        var y = Math.max(0, Math.round(viewTop + el.getBoundingClientRect().top));
        tops.push(y);
      });
      tops.sort(function (a, b) { return a - b; });
      // Merge units closer than 40px (e.g. a heading anchor at the very top).
      var merged = [];
      tops.forEach(function (y) { if (!merged.length || y - merged[merged.length - 1] >= 40) merged.push(y); });
      return merged;
    };
    // Which unit of the current section the reader is in (sticky - set on
    // navigation, never inferred from a scroll that is being clamped).
    var unit = 0;
    var unitFromScroll = function () {
      var v = viewer(); if (!v) { unit = 0; return; }
      var tops = unitTops(), y = v.scrollTop + 2, u = 0;
      for (var i = 0; i < tops.length; i++) if (tops[i] <= y) u = i;
      unit = u;
    };
    var clampSuspended = false;
    var clampScroll = function () {
      if (!window.__areadChapterScroll || clampSuspended) return;
      var v = viewer(); if (!v) return;
      var tops = unitTops();
      if (tops.length < 2) return; // whole section is one chapter
      if (unit >= tops.length) unit = tops.length - 1;
      var start = tops[unit];
      var end = unit + 1 < tops.length ? tops[unit + 1] : v.scrollHeight;
      var max = Math.max(start, end - v.clientHeight);
      if (v.scrollTop < start) v.scrollTop = start;
      else if (v.scrollTop > max) v.scrollTop = max;
    };
    // Bounds of the current chapter unit in scroller coordinates.
    var unitBounds = function () {
      var v = viewer();
      if (!v) return { start: 0, end: 0 };
      var tops = unitTops();
      var u = Math.min(unit, tops.length - 1);
      var start = tops[u] || 0;
      var end = u + 1 < tops.length ? tops[u + 1] : v.scrollHeight;
      return { start: start, end: Math.max(start, end) };
    };
    // Scrolled mode: tell Flutter where in the chapter we are (0..1) and
    // how much of it fits on screen, for the vertical position line.
    var scrollPending = false;
    var sendScroll = function () {
      scrollPending = false;
      var v = viewer();
      if (!v) return;
      var ratio = -1, frac = 1;
      if (window.__areadChapterScroll) {
        var b = unitBounds();
        var len = Math.max(1, b.end - b.start);
        var span = Math.max(1, len - v.clientHeight);
        ratio = Math.min(1, Math.max(0, (v.scrollTop - b.start) / span));
        frac = Math.min(1, v.clientHeight / len);
      }
      try { window.flutter_inappwebview.callHandler('areadScroll', ratio, frac); } catch (e) {}
    };
    var onScrollReport = function () {
      if (scrollPending) return;
      scrollPending = true;
      requestAnimationFrame(sendScroll);
    };
    window.__areadReportScroll = onScrollReport;
    window.__areadScrollTo = function (ratio) {
      var v = viewer();
      if (!v || !window.__areadChapterScroll) return;
      var b = unitBounds();
      var span = Math.max(0, (b.end - b.start) - v.clientHeight);
      clampSuspended = true;
      v.scrollTop = b.start + Math.min(1, Math.max(0, ratio)) * span;
      clampSuspended = false;
    };
    var installClamp = function () {
      var v = viewer();
      if (v && !v.__areadClamp) {
        v.__areadClamp = true;
        v.addEventListener('scroll', clampScroll, { passive: true });
        v.addEventListener('scroll', onScrollReport, { passive: true });
      }
    };
    installClamp();
    // The scroll line needs a report once the chapter has its real height,
    // not just when the reader scrolls: a report taken before the chapter
    // rendered says "fits on screen" and kept the line hidden.
    r.on('relocated', function () { installClamp(); onScrollReport(); });
    r.on('rendered', function () { setTimeout(function () { installClamp(); onScrollReport(); }, 50); });

    // Any display() (TOC sheet, search, CFI restore) re-derives the unit
    // from where it landed instead of being clamped back.
    if (!r.__areadDisplay) {
      r.__areadDisplay = r.display.bind(r);
      r.display = function () {
        clampSuspended = true;
        var p = r.__areadDisplay.apply(r, arguments);
        return Promise.resolve(p).then(function (res) {
          setTimeout(function () { installClamp(); unitFromScroll(); clampSuspended = false; onScrollReport(); }, 60);
          return res;
        }, function (err) { clampSuspended = false; throw err; });
      };
    }

    var linearSection = function (from, dir) {
      var s = book.spine.get(from + dir);
      while (s && s.linear === false) s = book.spine.get(s.index + dir);
      return s || null;
    };
    // Where `dir` would go: {sameSection, unit} or {section, last} or null.
    var neighbour = function (dir) {
      var idx = currentIndex();
      if (idx === undefined) return null;
      var tops = unitTops();
      if (dir > 0 && unit + 1 < tops.length) return { sameSection: true, unit: unit + 1 };
      if (dir < 0 && unit > 0) return { sameSection: true, unit: unit - 1 };
      var s = linearSection(idx, dir);
      return s ? { section: s, last: dir < 0 } : null;
    };

    var goChapter = function (dir) {
      var target = neighbour(dir);
      if (!target) { notify(dir); bounce(dir); return; }
      if (target.sameSection) {
        navigate(dir, function () {
          unit = target.unit;
          var v = viewer();
          if (v) { clampSuspended = true; v.scrollTop = unitTops()[unit] || 0; clampSuspended = false; }
          return Promise.resolve();
        });
        return;
      }
      navigate(dir, function () {
        return r.__areadDisplay(target.section.href).then(function () {
          return new Promise(function (resolve) {
            setTimeout(function () {
              installClamp();
              var tops = unitTops();
              unit = target.last ? tops.length - 1 : 0;
              var v = viewer();
              if (v) { clampSuspended = true; v.scrollTop = tops[unit] || 0; clampSuspended = false; }
              resolve();
            }, 60);
          });
        });
      });
    };

    // Expose chapter moves so Flutter (keyboard handler) can trigger them.
    window.__areadGoChapter = goChapter;
    window.__areadSyncUnit = function () { installClamp(); unitFromScroll(); };

    // --- gestures ----------------------------------------------------------
    // Scrolled (chapter-scroll) mode: vertical drags only ever scroll the
    // current chapter. A horizontal drag is a *lock* gesture: it reports its
    // progress to Flutter (which draws the indicator and fires the haptic
    // when it fills) and changes chapter only if released while full.
    // Paginated mode keeps a quick horizontal swipe = page turn, since pages
    // would otherwise be unreachable.
    var report = function (dir, progress, available) {
      try { window.flutter_inappwebview.callHandler('areadSwipeProgress', dir, progress, available); } catch (e) {}
    };
    var reportEnd = function (committed) {
      try { window.flutter_inappwebview.callHandler('areadSwipeEnd', committed); } catch (e) {}
    };
    var commitDistance = function () {
      var w = window.innerWidth || 360;
      return Math.max(90, Math.min(200, w * 0.32));
    };

    var swipeStart = null;
    var axis = null; // null | 'v' | 'h'
    var lockDir = 0, lockProgress = 0, lockAvailable = false, lastSent = -1;

    // Page curl (paginated): Flutter draws the turn, the page only reports
    // the drag - start, horizontal offset (in page widths) and the release
    // with its speed (page widths per second).
    var turnActive = false, turnSamples = [], turnMovePending = false, turnDx = 0;
    var pageWidth = function () { return window.innerWidth || 360; };
    var callTurn = function (name, a, b) {
      try { window.flutter_inappwebview.callHandler(name, a, b); } catch (e) {}
    };
    var turnVelocity = function () {
      var now = Date.now();
      var recent = turnSamples.filter(function (s) { return now - s.t <= 120; });
      if (recent.length < 2) return 0;
      var a = recent[0], b = recent[recent.length - 1];
      if (b.t === a.t) return 0;
      return ((b.x - a.x) / (b.t - a.t)) * 1000 / pageWidth();
    };
    var endTurn = function () {
      if (!turnActive) return;
      turnActive = false;
      var v = turnVelocity();
      turnSamples = [];
      callTurn('areadTurnEnd', turnDx / pageWidth(), v);
    };

    // Scrolled mode scrolls by hand instead of the WebView's own fling,
    // which flew far too fast: 1:1 while dragging, then a short, heavy
    // coast (strong friction) after release.
    var dragLastY = 0, dragSamples = [], momentumRaf = null;
    var stopMomentum = function () {
      if (momentumRaf) cancelAnimationFrame(momentumRaf);
      momentumRaf = null;
    };
    var dragBegin = function (t) {
      dragLastY = t.screenY;
      dragSamples = [{ y: t.screenY, t: Date.now() }];
    };
    var dragScroll = function (t) {
      if (!window.__areadChapterScroll) return;
      if (typeof hasActiveSelection === 'function' && hasActiveSelection()) return;
      var v = viewer();
      if (!v) return;
      var dy = t.screenY - dragLastY;
      dragLastY = t.screenY;
      v.scrollTop -= dy;
      dragSamples.push({ y: t.screenY, t: Date.now() });
      if (dragSamples.length > 8) dragSamples.shift();
    };
    var dragEnd = function () {
      if (!window.__areadChapterScroll) return;
      var now = Date.now();
      var recent = dragSamples.filter(function (p) { return now - p.t <= 100; });
      dragSamples = [];
      if (recent.length < 2) return;
      var a = recent[0], b = recent[recent.length - 1];
      if (b.t === a.t) return;
      var vel = ((b.y - a.y) / (b.t - a.t)) * 0.6; // px/ms, damped
      vel = Math.max(-3, Math.min(3, vel));
      var last = performance.now();
      var step = function (ts) {
        var dt = Math.min(32, Math.max(1, ts - last));
        last = ts;
        var sc = viewer();
        if (!sc) { momentumRaf = null; return; }
        var before = sc.scrollTop;
        sc.scrollTop -= vel * dt;
        vel *= Math.pow(0.92, dt / 16);
        if (Math.abs(vel) < 0.02 || sc.scrollTop === before) { momentumRaf = null; return; }
        momentumRaf = requestAnimationFrame(step);
      };
      momentumRaf = requestAnimationFrame(step);
    };

    var resetGesture = function () {
      swipeStart = null; axis = null;
      lockDir = 0; lockProgress = 0; lockAvailable = false; lastSent = -1;
    };

    var onStart = function (e) {
      var t = e.touches && e.touches[0];
      if (t && e.touches.length === 1) {
        endTurn();
        resetGesture();
        stopMomentum();
        dragBegin(t);
        swipeStart = { x: t.screenX, y: t.screenY, at: Date.now() };
      } else {
        if (axis === 'h' && window.__areadChapterScroll) reportEnd(false);
        endTurn();
        resetGesture();
      }
    };

    var onMove = function (e) {
      if (!swipeStart) return;
      var t = e.touches && e.touches[0];
      if (!t) return;
      if (axis === 'v') { dragScroll(t); return; }
      var rawDx = t.screenX - swipeStart.x;
      var dx = Math.abs(rawDx);
      var dy = Math.abs(t.screenY - swipeStart.y);
      if (axis === null) {
        if (dx > 12 || dy > 12) {
          // A drag, not a tap: the tap-to-show-controls must not fire.
          try { window.flutter_inappwebview.callHandler('areadDrag'); } catch (err) {}
        }
        if (dy > 12 && dy > dx * 1.25) { axis = 'v'; dragScroll(t); return; }
        if (dx > 12 && dx > dy * 1.5) {
          if (typeof hasActiveSelection === 'function' && hasActiveSelection()) { axis = 'v'; return; }
          axis = 'h';
        } else {
          return;
        }
      }
      if (!window.__areadChapterScroll) {
        if (!window.__areadCurl) return;
        turnDx = rawDx;
        turnSamples.push({ x: t.screenX, t: Date.now() });
        if (turnSamples.length > 12) turnSamples.shift();
        if (!turnActive) {
          turnActive = true;
          var h = window.innerHeight || 1;
          callTurn('areadTurnStart', rawDx < 0 ? 1 : -1, Math.min(1, Math.max(0, t.clientY / h)));
        }
        if (!turnMovePending) {
          turnMovePending = true;
          requestAnimationFrame(function () {
            turnMovePending = false;
            if (turnActive) callTurn('areadTurnMove', turnDx / pageWidth());
          });
        }
        return;
      }
      // Finger moving left = forward (next chapter), right = back.
      var dir = rawDx < 0 ? 1 : -1;
      if (dir !== lockDir) { lockDir = dir; lockAvailable = !!neighbour(dir); }
      lockProgress = Math.min(1, Math.max(0, (dx - 12) / commitDistance()));
      var rounded = Math.round(lockProgress * 50) / 50;
      if (rounded !== lastSent) {
        lastSent = rounded;
        report(lockDir, lockProgress, lockAvailable);
      }
    };

    var onEnd = function (e) {
      var t = e.changedTouches && e.changedTouches[0];
      var st = swipeStart, wasAxis = axis;
      var dir = lockDir, full = lockProgress >= 1, available = lockAvailable;
      // A short touch that never became a drag is a tap (Flutter shows or
      // hides the controls). Long presses select text instead.
      // Distance is checked here too: the WebView can swallow the move
      // events of a vertical swipe, so `axis` alone misses it.
      var endX = t ? t.screenX : (st ? st.x : 0), endY = t ? t.screenY : (st ? st.y : 0);
      var still = st && Math.abs(endX - st.x) < 12 && Math.abs(endY - st.y) < 12;
      if (wasAxis === null && st && still && Date.now() - st.at < 450 &&
          !(typeof hasActiveSelection === 'function' && hasActiveSelection())) {
        try { window.flutter_inappwebview.callHandler('areadTap'); } catch (err) {}
      }
      if (wasAxis === 'v') dragEnd();
      if (turnActive) {
        if (t && st) turnDx = t.screenX - st.x;
        endTurn();
        resetGesture();
        return;
      }
      resetGesture();
      if (!t || !st || wasAxis !== 'h') return;

      if (window.__areadChapterScroll) {
        var commit = full && available;
        reportEnd(commit);
        if (commit) goChapter(dir);
        else if (full && !available) bounce(dir);
        return;
      }

      // Paginated: quick natural swipe turns the page.
      if (typeof hasActiveSelection === 'function' && hasActiveSelection()) return;
      var dx = t.screenX - st.x, dy = t.screenY - st.y;
      if (Date.now() - st.at > 800) return;
      if (Math.abs(dx) >= 45 && Math.abs(dx) > Math.abs(dy) * 1.5) {
        if (dx < 0) r.next(); else r.prev();
      }
    };

    var onCancel = function () {
      if (axis === 'h' && window.__areadChapterScroll) reportEnd(false);
      endTurn();
      resetGesture();
    };

    var wheelAccum = 0;
    var wheelTimer = null;
    var onWheel = function (e) {
      if (window.__areadChapterScroll) return;
      wheelAccum += e.deltaY;
      clearTimeout(wheelTimer);
      wheelTimer = setTimeout(function () {
        if (Math.abs(wheelAccum) >= 40) {
          if (wheelAccum > 0) { r.next(); } else { r.prev(); }
        }
        wheelAccum = 0;
      }, 80);
    };

    var onKey = function (e) {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
      if (e.ctrlKey || e.altKey || e.metaKey) return;
      var nextKeys = ['ArrowRight', 'ArrowDown', 'PageDown', ' '];
      var prevKeys = ['ArrowLeft', 'ArrowUp', 'PageUp'];
      if (window.__areadChapterScroll && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
        // Scrolled mode: left/right change chapter, the rest scroll it.
        e.preventDefault();
        goChapter(e.key === 'ArrowRight' ? 1 : -1);
      } else if (nextKeys.indexOf(e.key) !== -1) {
        e.preventDefault();
        r.next();
      } else if (prevKeys.indexOf(e.key) !== -1) {
        e.preventDefault();
        r.prev();
      } else if (e.key === 'Escape') {
        try { window.flutter_inappwebview.callHandler('areadToggleMenu'); } catch (err) {}
      }
    };

    var attach = function (win) {
      if (!win || win.__areadSwipe) return;
      win.__areadSwipe = true;
      // Book text frames only: in the outer page this style's
      // `html, body { height: auto }` undid the fixed-height layout, so the
      // whole document scrolled instead of the book container (custom
      // scrolling and the scroll line both drive the container).
      try {
        if (win !== window && win.document) injectContentStyle(win.document);
      } catch (e) {}
      win.addEventListener('touchstart', onStart, { capture: true, passive: true });
      win.addEventListener('touchmove', onMove, { capture: true, passive: true });
      // Scrolled mode scrolls by hand (dragScroll): stop the WebView's own
      // scroll. Done here rather than with touch-action:none, which also
      // killed long-press text selection. Selection handle drags pass.
      win.addEventListener('touchmove', function (e) {
        if (!window.__areadChapterScroll || !e.cancelable) return;
        if (typeof hasActiveSelection === 'function' && hasActiveSelection()) return;
        e.preventDefault();
      }, { capture: true, passive: false });
      win.addEventListener('touchend', onEnd, { capture: true, passive: true });
      win.addEventListener('touchcancel', onCancel, { capture: true, passive: true });
      win.addEventListener('wheel', onWheel, { passive: true });
      win.addEventListener('keydown', onKey);
    };
    attach(window);
    r.hooks.content.register(function (contents) {
      if (contents && contents.window) {
        attach(contents.window);
        injectContentStyle(contents.document);
      }
    });
    try {
      r.getContents().forEach(function (c) {
        if (c && c.window) {
          attach(c.window);
          injectContentStyle(c.document);
        }
      });
    } catch (e) {}

    // One page move without any animation, for Flutter's curl: resolves
    // once the new page is laid out and painted, with whether it moved.
    window.__areadTurn = function (dir) {
      var at = function () { return r.location && r.location.start ? r.location.start.cfi : null; };
      var before = at();
      return new Promise(function (resolve) {
        var done = false;
        var finish = function () {
          if (done) return;
          done = true;
          requestAnimationFrame(function () {
            requestAnimationFrame(function () { resolve(at() !== before); });
          });
        };
        try {
          Promise.resolve(dir > 0 ? r.__areadNext() : r.__areadPrev()).then(finish, finish);
        } catch (e) { finish(); }
        setTimeout(finish, 1500);
      });
    };

    // Zoomed page strip: one "page" in either mode - a page turn when
    // paginated, one screen within the chapter when scrolled. Resolves with
    // whether it moved.
    window.__areadStep = function (dir) {
      if (!window.__areadChapterScroll) return window.__areadTurn(dir);
      return new Promise(function (resolve) {
        var v = viewer();
        if (!v) { resolve(false); return; }
        var b = unitBounds();
        var max = Math.max(b.start, b.end - v.clientHeight);
        var before = v.scrollTop;
        var target = Math.min(max, Math.max(b.start, before + dir * v.clientHeight));
        if (Math.abs(target - before) < 2) { resolve(false); return; }
        v.scrollTop = target;
        requestAnimationFrame(function () { requestAnimationFrame(function () { resolve(true); }); });
      });
    };
    // --- chapters for the zoomed view ------------------------------------
    // Table-of-contents entries in reading order, each with its spine
    // section (entries can be anchors inside one section).
    var tocList = null;
    var sectionFor = function (href) {
      var base = href.split('#')[0];
      var sec = book.spine.get(base) || book.spine.get(href);
      if (!sec) {
        var name = base.split('/').pop();
        for (var i = 0; i < book.spine.spineItems.length && !sec; i++) {
          var it = book.spine.spineItems[i];
          if (it && it.href && it.href.split('/').pop() === name) sec = it;
        }
      }
      return sec;
    };
    var getTocList = function () {
      if (tocList && tocList.length) return tocList;
      var out = [];
      var walk = function (items) {
        (items || []).forEach(function (it) {
          if (it && it.href) {
            var sec = sectionFor(it.href);
            if (sec) out.push({ title: (it.label || '').replace(/\s+/g, ' ').trim(), href: it.href, index: sec.index, anchor: it.href.split('#')[1] || null });
          }
          walk(it && it.subitems);
        });
      };
      try { walk(book.navigation && book.navigation.toc); } catch (e) {}
      // Reading order: some tables of contents list entries out of order
      // (e.g. the cover last in the book but first in the list).
      out.forEach(function (e, i) { e.order = i; });
      out.sort(function (a, b) { return a.index - b.index || a.order - b.order; });
      tocList = out;
      return out;
    };
    // Which entry the page is in: the last one starting at or before it.
    var chapterIndex = function () {
      var list = getTocList();
      var idx = currentIndex();
      if (idx === undefined) return -1;
      var loc = r.location;
      var endCfi = loc && loc.end ? loc.end.cfi : null;
      var cur = -1;
      for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (e.index < idx) { cur = i; continue; }
        if (e.index > idx) break;
        // Same section: an anchored entry counts once its anchor is on or
        // before this page.
        if (!e.anchor || !endCfi) { cur = i; continue; }
        var found = false;
        try {
          r.getContents().forEach(function (c) {
            if (found || c.sectionIndex !== idx) return;
            var el = c.document.getElementById(e.anchor);
            if (!el) return;
            var cfi = c.cfiFromNode(el);
            if (new ePub.CFI().compare(cfi, endCfi) <= 0) found = true;
          });
        } catch (err) { found = true; }
        if (found || cur === -1) cur = i;
      }
      return cur;
    };
    window.__areadChapterInfo = function () {
      var list = getTocList();
      var i = chapterIndex();
      var pick = function (j) { return j >= 0 && j < list.length ? { title: list[j].title, href: list[j].href } : null; };
      return JSON.stringify({ current: pick(i), prev: pick(i - 1), next: pick(i + 1) });
    };
    window.__areadOpenHref = function (href) {
      return new Promise(function (resolve) {
        var done = function () {
          requestAnimationFrame(function () { requestAnimationFrame(function () { resolve(true); }); });
        };
        Promise.resolve(r.display(href)).then(done, done);
      });
    };

    // Exact spot to come back to after the strip's photo moves.
    window.__areadMark = function () {
      var v = viewer();
      return JSON.stringify({
        cfi: r.location && r.location.start ? r.location.start.cfi : null,
        top: v ? v.scrollTop : 0,
        scrolled: !!window.__areadChapterScroll
      });
    };
    window.__areadRestore = function (mark) {
      return new Promise(function (resolve) {
        var done = function () {
          requestAnimationFrame(function () { requestAnimationFrame(function () { resolve(true); }); });
        };
        var m;
        try { m = JSON.parse(mark); } catch (e) { resolve(false); return; }
        if (m.scrolled && window.__areadChapterScroll) {
          var v = viewer();
          if (v) { clampSuspended = true; v.scrollTop = m.top; clampSuspended = false; }
          done();
        } else if (m.cfi) {
          Promise.resolve(r.display(m.cfi)).then(done, done);
        } else {
          resolve(false);
        }
      });
    };

    r.next = function () {
      try { if (window.getSelection) window.getSelection().removeAllRanges(); } catch (err) {}
      if (window.__areadChapterScroll) {
        // Never leave the chapter by scrolling: at the end this is a no-op.
        // Changing chapter is a deliberate horizontal lock-swipe (or ←/→).
        var v = viewer();
        if (v) v.scrollBy({ top: v.clientHeight * 0.85, behavior: 'smooth' });
        return;
      }
      navigate(1, r.__areadNext);
    };
    r.prev = function () {
      try { if (window.getSelection) window.getSelection().removeAllRanges(); } catch (err) {}
      if (window.__areadChapterScroll) {
        var v = viewer();
        if (v) v.scrollBy({ top: -v.clientHeight * 0.85, behavior: 'smooth' });
        return;
      }
      navigate(-1, r.__areadPrev);
    };
  }

  // --- pages left in the book (paginated) ------------------------------
  // epub.js only knows page counts for the chapter on screen, so the rest of
  // the book is estimated from its locations (fixed-size text chunks) at the
  // pages-per-location rate of the chapters seen so far.
  if (!r.__areadPages) {
    r.__areadPages = true;
    var sectionLocations = null, countedLength = -1;
    var countLocations = function () {
      try {
        var list = book.locations && book.locations._locations;
        // epub.js fills this list a chapter at a time in the background and
        // sets `total` only when it's done; counting a partial list left
        // later chapters out (the count read like the current chapter's).
        if (!list || !list.length || !(book.locations.total > 0)) return null;
        if (sectionLocations && countedLength === list.length) return sectionLocations;
        countedLength = list.length;
        var counts = {};
        for (var i = 0; i < list.length; i++) {
          var pos;
          try { pos = new ePub.CFI(list[i]).spinePos; } catch (e) { continue; }
          if (typeof pos === 'number') counts[pos] = (counts[pos] || 0) + 1;
        }
        return counts;
      } catch (e) { return null; }
    };
    var sendPages = function (loc) {
      var left = -1;
      try {
        if (!window.__areadChapterScroll && loc && loc.start && loc.start.displayed) {
          sectionLocations = countLocations();
          if (sectionLocations) {
            var idx = loc.start.index, shown = loc.start.displayed;
            // Page counts taken mid-relayout (old flow/size) are wrong.
            if (!window.__areadLayingOut) window.__areadSeenPages[idx] = shown.total;
            var pages = 0, locs = 0, after = 0, k;
            for (k in window.__areadSeenPages) {
              if (sectionLocations[k]) { pages += window.__areadSeenPages[k]; locs += sectionLocations[k]; }
            }
            for (k in sectionLocations) if (+k > idx) after += sectionLocations[k];
            var perLocation = locs > 0 ? pages / locs : 1;
            left = Math.max(0, shown.total - shown.page) + Math.round(after * perLocation);
          }
        }
      } catch (e) { left = -1; }
      try { window.flutter_inappwebview.callHandler('areadPages', left); } catch (e) {}
    };
    r.on('relocated', sendPages);
    window.__areadSendPages = function () { sendPages(r.location); };
  }
  // Page counts change with the layout (text size, margins, flow).
  window.__areadSeenPages = {};

  // Load every chapter's text in the background (one at a time, with
  // pauses), so a jump - progress bar, chapter list, search - only has to
  // lay the page out instead of fetching and parsing it first.
  window.__areadPreload = function () {
    if (window.__areadPreloading) return;
    window.__areadPreloading = true;
    var items = (book.spine && book.spine.spineItems) || [];
    var i = 0;
    var next = function () {
      if (i >= items.length) return;
      var s = items[i++];
      if (!s || s.contents) { setTimeout(next, 0); return; }
      Promise.resolve(s.load(book.load.bind(book)))
        .catch(function () {})
        .then(function () { setTimeout(next, 40); });
    };
    next();
  };

  // Re-display where we are, every time. The book was first laid out before
  // any of the CSS above existed (stale iframe height, column gap, side
  // padding), which is why it looked cut off / off-centre until a chapter
  // change re-rendered it. This also drops neighbouring chapters the
  // continuous manager loaded before chapter-scroll was installed.
  // Reading mode. epub.js's own rendition.flow() (sakura's setFlow) clears
  // and re-displays the book by itself; the re-display below then cleared
  // it again mid-render, which orphaned the first render and left a blank
  // page. Switch the layout here without displaying, and display once.
  var wantFlow = chapterScroll ? 'scrolled' : 'paginated';
  var haveFlow = (r.settings && /^scrolled/.test(r.settings.flow || '')) ? 'scrolled' : 'paginated';
  if (wantFlow !== haveFlow) {
    r.settings.flow = wantFlow;
    try { if (r._layout) r._layout.flow(wantFlow); } catch (e) {}
    try { if (r._layout) m.applyLayout(r._layout); } catch (e) {}
    try { m.updateFlow(wantFlow); } catch (e) {}
  }

  // Tells Flutter the page has its final layout (it covers the page with a
  // skeleton until then, hiding the re-layout flash).
  window.__areadLayingOut = true;
  var laidOut = function () {
    setTimeout(function () {
      window.__areadLayingOut = false;
      window.__areadSeenPages = {};
      if (window.__areadSendPages) window.__areadSendPages();
      try { window.flutter_inappwebview.callHandler('areadLaidOut'); } catch (e) {}
    }, 120);
  };

  // Lays the book out again at `cfi` (after a resize/rotation).
  window.__areadRelayout = function (cfi) {
    window.__areadLayingOut = true;
    try { if (window.getSelection) window.getSelection().removeAllRanges(); } catch (e) {}
    try {
      r.getContents().forEach(function (c) {
        try { c.window.getSelection().removeAllRanges(); } catch (e) {}
        injectContentStyle(c.document);
      });
    } catch (e) {}
    var target = cfi || (r.location && r.location.start ? r.location.start.cfi : undefined);
    r.q.enqueue(function () { try { m.clear(); } catch (e) {} });
    Promise.resolve(r.display(target)).then(laidOut, laidOut);
  };

  var layoutKey = [chapterScroll, margin, bgColor].join('|');
  var layoutChanged = window.__areadLayoutKey !== layoutKey;
  window.__areadLayoutKey = layoutKey;
  if (layoutChanged && m.views && m.views.length >= 1) {
    // Prefer the position the app captured before switching: mid-switch,
    // currentLocation() reads the half-relaid-out page (usually the
    // chapter start), which lost your place on every flow change.
    var here = restoreCfi ? null : r.currentLocation();
    var cfi = restoreCfi || (here && here.start ? here.start.cfi : (r.location && r.location.start ? r.location.start.cfi : null));
    // display() alone just re-scrolls an already-rendered section, so clear
    // the views first to force a real re-render with the new CSS.
    try { r.getContents().forEach(function (c) { injectContentStyle(c.document); }); } catch (e) {}
    if (cfi) {
      // Queued, so it waits for any render still in progress instead of
      // pulling the views out from under it.
      r.q.enqueue(function () { try { m.clear(); } catch (e) {} });
      Promise.resolve(r.display(cfi)).then(laidOut, laidOut);
    } else {
      laidOut();
    }
  } else {
    laidOut();
  }
  // Opening at a saved CFI, or re-applying after a flow switch, can land
  // mid-section: work out which chapter unit that is before clamping.
  if (window.__areadSyncUnit) setTimeout(window.__areadSyncUnit, 80);
  if (window.__areadReportScroll) {
    [200, 600, 1200, 2500].forEach(function (ms) { setTimeout(window.__areadReportScroll, ms); });
  }
  if (window.__areadSendPages) setTimeout(window.__areadSendPages, 300);
  return true;
})
''';

  /// JS handler name the page calls after a swipe navigates.
  static const String navigatedHandler = 'areadNavigated';

  /// Called with `(dir, progress 0..1, available)` while a horizontal
  /// chapter lock-swipe is in progress (scrolled mode only). `dir` is 1 for
  /// the next chapter, -1 for the previous; `available` is false at the
  /// first/last chapter.
  static const String swipeProgressHandler = 'areadSwipeProgress';

  /// Called with `(committed)` when the lock-swipe ends - `committed` is
  /// true if it was released full and the chapter is changing.
  static const String swipeEndHandler = 'areadSwipeEnd';

  /// Called with `(ratio, visibleFraction)` as the reader scrolls in
  /// scrolled mode: `ratio` 0..1 is the position inside the current
  /// chapter, `visibleFraction` how much of the chapter fits on screen.
  /// `ratio` is -1 in paginated mode (no vertical position to show).
  static const String scrollHandler = 'areadScroll';

  /// Page curl (paginated, when [apply] got `pageCurl: true`):
  /// `(dir, yFraction)` when a horizontal drag starts - dir 1 next, -1 back;
  /// `(dxFraction)` as it moves, in page widths (negative = leftwards);
  /// `(dxFraction, velocity)` on release, velocity in page widths/second.
  static const String turnStartHandler = 'areadTurnStart';
  static const String turnMoveHandler = 'areadTurnMove';
  static const String turnEndHandler = 'areadTurnEnd';

  /// Called with `(pagesLeft)` after each move in paginated mode: an
  /// estimate of the pages left in the book, or -1 when not known yet.
  static const String pagesHandler = 'areadPages';

  /// Called for a tap on the page (short touch, no drag, no selection).
  static const String tapHandler = 'areadTap';

  /// Called once a touch moves far enough to be a drag rather than a tap.
  static const String dragHandler = 'areadDrag';

  /// Called when [apply] has finished laying the page out.
  static const String laidOutHandler = 'areadLaidOut';

  /// Moves the scrolled text down by [px] (0 = back in place), animated,
  /// without re-laying it out.
  static Future<void> shiftTop(EpubController controller, double px) async {
    await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadShiftTop && window.__areadShiftTop(${px.toStringAsFixed(1)});',
    );
  }

  /// Lays the book out again at [cfi] (after the view was resized).
  static Future<void> relayout(EpubController controller, String? cfi) async {
    final arg = cfi != null ? jsonEncode(cfi) : 'null';
    await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadRelayout && window.__areadRelayout($arg);',
    );
  }

  /// Current/previous/next chapter (from the table of contents) as
  /// `{current, prev, next}`, each `{title, href}` or null.
  static Future<Map<String, dynamic>?> chapterInfo(EpubController controller) async {
    final result = await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadChapterInfo ? window.__areadChapterInfo() : null',
    );
    if (result is! String) return null;
    try {
      return jsonDecode(result) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Shows [href] (e.g. a chapter) and waits until it's painted.
  static Future<void> openHref(EpubController controller, String href) async {
    await controller.webViewController?.callAsyncJavaScript(
      functionBody: 'return window.__areadOpenHref ? await window.__areadOpenHref(href) : false;',
      arguments: {'href': href},
    );
  }

  /// Starts loading every chapter in the background (see __areadPreload).
  static Future<void> preloadBook(EpubController controller) async {
    await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadPreload && window.__areadPreload();',
    );
  }

  /// One strip "page" (`dir` 1 or -1): a page turn when paginated, a
  /// screen when scrolled. Returns whether it moved.
  static Future<bool> step(EpubController controller, int dir) async {
    final result = await controller.webViewController?.callAsyncJavaScript(
      functionBody: 'return window.__areadStep ? await window.__areadStep(dir) : false;',
      arguments: {'dir': dir < 0 ? -1 : 1},
    );
    return result?.value == true;
  }

  /// The exact current spot, to hand back to [restore].
  static Future<String?> mark(EpubController controller) async {
    final result = await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadMark ? window.__areadMark() : null',
    );
    return result is String ? result : null;
  }

  /// Returns to a spot from [mark] and waits until it's painted.
  static Future<void> restore(EpubController controller, String mark) async {
    await controller.webViewController?.callAsyncJavaScript(
      functionBody: 'return window.__areadRestore ? await window.__areadRestore(mark) : false;',
      arguments: {'mark': mark},
    );
  }

  /// Shows the page holding [cfi] and waits until it's painted. Used to
  /// return exactly to a page: stepping back with [turn] can land on the
  /// wrong page at a chapter boundary.
  static Future<void> displayCfi(EpubController controller, String cfi) async {
    await controller.webViewController?.callAsyncJavaScript(
      functionBody: '''
        try { await rendition.display(cfi); } catch (e) {}
        await new Promise(function (r) { requestAnimationFrame(function () { requestAnimationFrame(r); }); });
        return true;
      ''',
      arguments: {'cfi': cfi},
    );
  }

  /// Where the page is right now (start CFI), or null.
  static Future<String?> currentCfi(EpubController controller) async {
    final result = await controller.webViewController?.evaluateJavascript(
      source: '(function(){ try { return rendition.location.start.cfi; } catch (e) { return null; } })();',
    );
    return result is String && result.startsWith('epubcfi(') ? result : null;
  }

  /// Loads saved epub.js locations (from [saveLocations]) into the page.
  /// Returns how many were loaded, or -1 on failure.
  static Future<int> loadLocations(EpubController controller, String json) async {
    final result = await controller.webViewController?.evaluateJavascript(
      source: '$_locationsScript(${jsonEncode(json)});',
    );
    return result is num ? result.toInt() : -1;
  }

  /// The page's counted locations as JSON, to save for the next open.
  static Future<String?> saveLocations(EpubController controller) async {
    final result = await controller.webViewController?.evaluateJavascript(
      source: '(function(){ try { return (book.locations && book.locations.total > 0) ? book.locations.save() : null; } catch (e) { return null; } })();',
    );
    return result is String && result.length > 2 ? result : null;
  }

  /// Moves one page (`dir` 1 or -1) with no animation and waits until the
  /// new page is painted. Returns whether the page actually changed.
  static Future<bool> turn(EpubController controller, int dir) async {
    final result = await controller.webViewController?.callAsyncJavaScript(
      functionBody: 'return window.__areadTurn ? await window.__areadTurn(dir) : false;',
      arguments: {'dir': dir < 0 ? -1 : 1},
    );
    return result?.value == true;
  }

  /// Scrolls the current chapter to [ratio] (0..1). Scrolled mode only.
  static Future<void> scrollTo(EpubController controller, double ratio) async {
    final r = ratio.clamp(0.0, 1.0).toStringAsFixed(4);
    await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadScrollTo && window.__areadScrollTo($r);',
    );
  }

  /// Re-reports the current location. epub.js reports the first one before
  /// it has counted the book's locations, so its percentage reads 0 until
  /// the reader moves - call this once they are ready.
  static Future<void> reportLocation(EpubController controller) async {
    await controller.webViewController?.evaluateJavascript(
      source: 'try { rendition.reportLocation(); } catch (e) {}',
    );
  }

  /// Moves to the next (`dir = 1`) or previous (`dir = -1`) chapter, if
  /// [apply] has been run on this page.
  static Future<void> goChapter(EpubController controller, int dir) async {
    await controller.webViewController?.evaluateJavascript(
      source: 'window.__areadGoChapter && window.__areadGoChapter(${dir < 0 ? -1 : 1});',
    );
  }

  /// Installs (idempotently) and switches chapter-scroll on/off.
  static Future<void> apply(
    EpubController controller, {
    required bool chapterScroll,
    double marginHorizontal = 0.0,
    String? backgroundColor,
    String? restoreCfi,
    bool pageCurl = false,
  }) async {
    final bgArg = backgroundColor != null ? "'$backgroundColor'" : "null";
    final cfiArg = restoreCfi != null ? jsonEncode(restoreCfi) : "null";
    await controller.webViewController?.evaluateJavascript(
      source: '$_script($chapterScroll, $marginHorizontal, $bgArg, $cfiArg, $pageCurl);',
    );
  }
}
