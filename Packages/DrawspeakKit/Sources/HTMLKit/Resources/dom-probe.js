// Drawspeak DOM probe. Runs only in the "drawspeak-probe" content world, so it
// works with page JavaScript disabled and page scripts cannot see or call it.
// It reads the DOM; the only mutation is one marked viewport <meta> tag.
(() => {
  'use strict';
  if (globalThis.__drawspeakProbe) return;

  const INJECTED = 'data-drawspeak-injected';
  const TEXT_LABEL_LENGTH = 24;

  function cssEscape(value) {
    if (globalThis.CSS && typeof CSS.escape === 'function') return CSS.escape(value);
    return String(value).replace(/["\\]/g, '\\$&');
  }

  function humanize(key) {
    return key
      .split(/[-_\s]+/)
      .filter(Boolean)
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  function collapsed(text) {
    return (text || '').replace(/\s+/g, ' ').trim();
  }

  function label(el) {
    const name = collapsed(el.getAttribute('data-review-name'));
    if (name) return name;
    const key = collapsed(el.getAttribute('data-review-id'));
    if (key) return humanize(key) || key;
    const aria = collapsed(el.getAttribute('aria-label'));
    if (aria) return aria;
    if (el.id) return el.id;
    const tag = '<' + el.localName + '>';
    const text = collapsed(el.textContent).slice(0, TEXT_LABEL_LENGTH);
    return text ? tag + ' ' + text : tag;
  }

  function cssPath(el) {
    const doc = el.ownerDocument;
    if (el === doc.body) return 'body';
    const parts = [];
    for (let node = el; node && node !== doc.body && node !== doc.documentElement; node = node.parentElement) {
      const siblings = node.parentElement ? Array.from(node.parentElement.children) : [node];
      const index = siblings.filter(sibling => sibling.localName === node.localName).indexOf(node) + 1;
      parts.unshift(node.localName + ':nth-of-type(' + index + ')');
    }
    return 'body > ' + parts.join(' > ');
  }

  function locator(el) {
    const doc = el.ownerDocument;
    const key = el.getAttribute('data-review-id');
    if (key && doc.querySelectorAll('[data-review-id="' + cssEscape(key) + '"]').length === 1) {
      return { strategy: 'data-review-id', value: key };
    }
    if (el.id && doc.querySelectorAll('#' + cssEscape(el.id)).length === 1) {
      return { strategy: 'id', value: el.id };
    }
    return { strategy: 'css-path', value: cssPath(el) };
  }

  function clamp01(value) {
    return Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0;
  }

  function bounds(el, width, height) {
    const rect = el.getBoundingClientRect();
    const x = clamp01(rect.left / width);
    const y = clamp01(rect.top / height);
    const right = clamp01(rect.right / width);
    const bottom = clamp01(rect.bottom / height);
    return { x, y, width: right - x, height: bottom - y };
  }

  function info(el, width, height) {
    return {
      label: label(el),
      tagName: el.localName,
      locator: locator(el),
      bounds: bounds(el, width, height),
    };
  }

  function hasSize(el) {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  // Hit element first, <body> last; <html> is never part of a chain.
  function chain(el, width, height) {
    const doc = el.ownerDocument;
    const out = [];
    for (let node = el; node && node !== doc.documentElement; node = node.parentElement) {
      if (node === doc.body || hasSize(node)) out.push(info(node, width, height));
      if (node === doc.body) break;
    }
    return out;
  }

  // layers[0] is the topmost element under the point. Every further layer is an
  // element in the same point's stack that is not an ancestor of an earlier layer.
  function probe(nx, ny, width, height) {
    const doc = document;
    const x = Math.min(Math.max(nx * width, 0), Math.max(width - 0.5, 0));
    const y = Math.min(Math.max(ny * height, 0), Math.max(height - 0.5, 0));
    const hits = doc.elementsFromPoint(x, y).filter(el => el !== doc.documentElement);
    const tops = [];
    for (const el of hits) {
      if (!tops.some(top => el === top || el.contains(top))) tops.push(el);
    }
    return JSON.stringify({ layers: tops.map(top => chain(top, width, height)) });
  }

  // The rendered document without the probe's own viewport tag.
  function serializedDocument() {
    const copy = document.documentElement.cloneNode(true);
    copy.querySelectorAll('[' + INJECTED + ']').forEach(node => node.remove());
    return copy.outerHTML;
  }

  // Appended last so it wins over the page's own viewport tag, which stays untouched.
  function installViewport(width) {
    const doc = document;
    if (!doc.documentElement || doc.querySelector('meta[' + INJECTED + ']')) return;
    const meta = doc.createElement('meta');
    meta.setAttribute(INJECTED, 'viewport');
    meta.setAttribute('name', 'viewport');
    meta.setAttribute('content', 'width=' + width + ', initial-scale=1, maximum-scale=1, user-scalable=no');
    (doc.head || doc.documentElement).appendChild(meta);
  }

  function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // Waits for web fonts and one rendered frame, each with a bound.
  async function settle() {
    if (document.fonts && document.fonts.ready) {
      await Promise.race([document.fonts.ready, timeout(1000)]);
    }
    const frame = new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    await Promise.race([frame, timeout(250)]);
    return true;
  }

  Object.defineProperty(globalThis, '__drawspeakProbe', {
    value: Object.freeze({ probe, serializedDocument, installViewport, settle }),
    configurable: false,
    enumerable: false,
    writable: false,
  });
})();
