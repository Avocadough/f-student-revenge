// Run from the repository root with Node. No browser, engine, network or GPU used.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const html = fs.readFileSync('Web/horror_shell.html', 'utf8');
const checks = [];
function check(condition, label) {
  assert.ok(condition, label);
  checks.push(label);
}
const expectedTokens = ['$GODOT_CONFIG', '$GODOT_HEAD_INCLUDE', '$GODOT_PROJECT_NAME', '$GODOT_SPLASH', '$GODOT_SPLASH_CLASSES', '$GODOT_SPLASH_COLOR', '$GODOT_THREADS_ENABLED', '$GODOT_URL'];
check(JSON.stringify([...new Set(html.match(/\$GODOT_[A-Z_]+/g))].sort()) === JSON.stringify(expectedTokens.sort()), 'All eight official exporter placeholders are preserved');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(match => match[1]).filter(Boolean);
check(scripts.length === 1, 'One inline bootstrap script');
const config = { executable: 'index', mainPack: 'index.pck', args: ['--example', 'keep-me'], fileSizes: { 'index.wasm': 1234, 'index.pck': 21130280 }, serviceWorker: '', ensureCrossOriginIsolationHeaders: false };
function source(override = {}) {
  return scripts[0].replace('$GODOT_CONFIG', JSON.stringify({ ...config, ...override })).replace('$GODOT_THREADS_ENABLED', 'false');
}
new vm.Script(source());
check(true, 'JavaScript syntax parses after exporter substitution');
function deferred() {
  const result = {};
  result.promise = new Promise((resolve, reject) => Object.assign(result, { resolve, reject }));
  return result;
}
function start(scenario = 'normal', override = {}) {
  const nodes = new Map();
  function node() {
    return { style: {}, attributes: {}, children: [], listeners: {}, textContent: '', removed: false,
      setAttribute(key, value) { this.attributes[key] = value; },
      removeAttribute(key) { delete this.attributes[key]; if (key in this) delete this[key]; },
      appendChild(child) { this.children.push(child); },
      removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
      get lastChild() { return this.children.at(-1); },
      addEventListener(event, fn) { this.listeners[event] = fn; },
      remove() { this.removed = true; }
    };
  }
  const state = { nodes, calls: [], reloaded: false, init: deferred(), pack: deferred(), run: deferred() };
  const context = {
    document: { getElementById(id) { if (!nodes.has(id)) nodes.set(id, node()); return nodes.get(id); }, createElement: node, createTextNode(text) { return { text }; } },
    window: { location: { reload() { state.reloaded = true; } } },
    navigator: {}, console: { error() {} }, Error, Promise, setTimeout
  };
  if (scenario !== 'script-failure') {
    context.Engine = class {
      constructor(options) { state.config = options; }
      static getMissingFeatures(options) { state.featureCheck = options; return scenario === 'missing-feature' ? ['WebGL 2'] : []; }
      init(executable) { state.calls.push(['init', executable]); return state.init.promise; }
      preloadFile(url, path) { state.calls.push(['preloadFile', url, path]); return state.pack.promise; }
      start(options) { state.calls.push(['start']); state.startOptions = options; return state.run.promise; }
    };
  }
  vm.runInNewContext(source(override), context);
  return state;
}
async function flush() { for (let i = 0; i < 5; i++) await Promise.resolve(); }
async function ready(state) { state.init.resolve(); state.pack.resolve(); await flush(); }
(async () => {
  let state = start();
  check(state.nodes.get('progress-panel').attributes['aria-busy'] === 'true', 'Loading UI is active during initialization');
  check(state.calls[0][0] === 'init' && state.calls[0][1] === 'index', 'Engine initializes using the original executable');
  check(state.calls[1][0] === 'preloadFile' && state.calls[1][1] === 'index.pck?v=0.5-captions3', 'Pack download has the release cache key');
  check(state.calls[1][2] === 'index.pck' && !state.calls[1][2].includes('?'), 'Preload VFS path stays query-free');
  check(state.config.fileSizes['index.pck?v=0.5-captions3'] === 21130280 && state.config.fileSizes['index.pck'] === 21130280 && state.config.fileSizes['index.wasm'] === 1234, 'Versioned download has the correct known size without losing original sizes');
  check(typeof state.config.onProgress === 'function', 'Progress callback is available at Engine construction');
  state.config.onProgress(250, 1000);
  check(state.nodes.get('status-progress').value === 250 && state.nodes.get('status-progress').max === 1000, 'Actual byte counts drive the native progress element');
  check(state.nodes.get('progress-text').textContent.includes('25%'), 'Determinate progress has Thai percentage copy');
  state.config.onProgress(1000, 1000);
  check(state.nodes.get('progress-text').textContent.includes('ดาวน์โหลดครบแล้ว'), 'Completed download indicates scene preparation');
  state.config.onProgress(0, 0);
  check(!('value' in state.nodes.get('status-progress')) && !('max' in state.nodes.get('status-progress')), 'Unknown totals use indeterminate progress');
  state.init.resolve(); await flush();
  check(!state.startOptions && !state.nodes.get('status').removed, 'Engine cannot start before pack preload completes');
  state.pack.resolve(); await flush();
  check(JSON.stringify(state.startOptions.args) === JSON.stringify(['--main-pack', 'index.pck', '--example', 'keep-me']), 'Main-pack path is clean and original args are retained');
  check(!state.nodes.get('status').removed, 'Overlay remains until Engine.start resolves');
  state.run.resolve(); await flush();
  check(state.nodes.get('status').removed, 'Successful engine start removes the overlay');
  state = start('normal', { mainPack: '', args: undefined });
  await ready(state);
  check(state.calls[1][2] === 'index.pck' && JSON.stringify(state.startOptions.args) === JSON.stringify(['--main-pack', 'index.pck']), 'Missing optional mainPack and args preserve exporter defaults');
  state.run.resolve(); await flush();
  state = start('missing-feature');
  check(state.calls.length === 0 && state.nodes.get('error-panel').style.display === 'block', 'Missing WebGL features prevent downloads and show recovery UI');
  check(state.featureCheck.threads === false && state.nodes.get('status-notice').children.some(child => child.text === 'WebGL 2'), 'Thread setting and missing-feature details are preserved');
  state.nodes.get('retry-button').listeners.click();
  check(state.reloaded, 'Recovery button reloads the page');
  state = start('script-failure');
  check(state.calls.length === 0 && state.nodes.get('error-panel').style.display === 'block', 'Engine script failure has a usable error screen');
  for (const phase of ['init', 'pack', 'run']) {
    state = start();
    if (phase === 'run') await ready(state);
    state[phase].reject(new Error('<unsafe ' + phase + ' error>'));
    await flush();
    check(state.nodes.get('error-panel').style.display === 'block' && !state.nodes.get('status').removed, phase + ' rejection retains error recovery overlay');
    check(state.nodes.get('status-notice').children[0].text === '<unsafe ' + phase + ' error>', phase + ' error is inserted as text, not HTML');
  }
  for (const error of ['network unavailable', { unexpected: true }]) {
    state = start(); state.pack.reject(error); await flush();
    check(state.nodes.get('error-panel').style.display === 'block' && state.nodes.get('status-notice').children[0].text === (typeof error === 'string' ? error : 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ'), 'String and unknown failures retain readable notices');
  }
  check(!/<(?:img|link)[^>]+(?:src|href)\s*=/.test(html) && !/https?:\/\//.test(html), 'Shell adds no external art or font fetches');
  check(!/\bfetch\s*=|window\.fetch|globalThis\.fetch|Engine\.prototype\s*[.=]/.test(html), 'Cache handling does not monkeypatch network or Engine APIs');
  console.log(JSON.stringify({ passed: true, checks: checks.length, scope: 'Stubbed documented Engine startup and loading/error lifecycle; no browser or cache-network validation', cases: checks }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
