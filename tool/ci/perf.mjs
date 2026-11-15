// Performance check of the web build in headless Chrome, like a phone held
// sideways (844x390, touch) with a 4x slower CPU.
//
//   node tool/ci/perf.mjs http://localhost:8123/ [chrome-binary]
//
// 1. The lobby must stand still: no frames while nothing happens (the rule
//    "no endless animations"). More than a few frames in 3 seconds fails.
// 2. A new game is started and the deal measured: how long each frame takes
//    and how many frames stutter (over 50 ms). These numbers are reported (in the
//    GitHub job summary and perf.json), not judged: runners vary.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const url = process.argv[2] ?? 'http://localhost:8123/';
const chromeBin =
  process.argv[3] ??
  process.env.CHROME ??
  (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome');
const port = 9444;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'pastra-perf-'));
const chrome = spawn(
  chromeBin,
  [
    '--headless=new',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=844,390',
    'about:blank',
  ],
  { stdio: 'ignore' },
);

let ws;
let id = 0;
const pending = new Map();
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const i = ++id;
    pending.set(i, resolve);
    ws.send(JSON.stringify({ id: i, method, params }));
  });
const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  return r.result?.result?.value;
};
const tap = async (x, y) => {
  await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  await sleep(60);
  await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
};

function stats(values) {
  if (values.length === 0) return { n: 0, p50: 0, p95: 0, max: 0 };
  const s = [...values].sort((a, b) => a - b);
  const at = (q) => s[Math.min(s.length - 1, Math.floor(q * s.length))];
  return { n: s.length, p50: +at(0.5).toFixed(1), p95: +at(0.95).toFixed(1), max: +s[s.length - 1].toFixed(1) };
}

let exitCode = 0;
try {
  // Chrome needs a moment to open its debugging port.
  let list;
  for (let i = 0; i < 50 && !list; i++) {
    try {
      list = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    } catch {
      await sleep(200);
    }
  }
  const page = list.find((t) => t.type === 'page');
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) {
      pending.get(m.id)(m);
      pending.delete(m.id);
    }
  });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Emulation.setDeviceMetricsOverride', { width: 844, height: 390, deviceScaleFactor: 2.6, mobile: true });
  await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
  // Every frame Flutter asks for goes through requestAnimationFrame: count
  // them, and time the work done in each.
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.__frames = [];
      const raf = window.requestAnimationFrame.bind(window);
      window.requestAnimationFrame = (cb) => raf((t) => {
        const start = performance.now();
        cb(t);
        window.__frames.push([start, performance.now() - start]);
      });
      // Frames that took longer than 50 ms from start to paint (a stutter).
      window.__long = [];
      try {
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) window.__long.push([e.startTime, e.duration]);
        }).observe({ type: 'long-animation-frame', buffered: true });
      } catch (e) {}`,
  });

  // First visit: no tutorial, no sound; then the real start.
  await send('Page.navigate', { url });
  await sleep(1500);
  await evaluate(
    `localStorage.setItem('flutter.tutorialDone','true');localStorage.setItem('flutter.sound','false');` +
      `localStorage.setItem('flutter.language','"en"');'ok'`,
  );
  await send('Emulation.setCPUThrottlingRate', { rate: 4 });
  await send('Page.reload');
  // Until the app is there (the splash is removed), then let the lobby's
  // entrance finish.
  for (let i = 0; i < 120; i++) {
    if (await evaluate(`!document.getElementById('loading')`)) break;
    await sleep(500);
  }
  await sleep(3000);
  // The daily bonus greets a new player: close it (Escape closes dialogs).
  for (const type of ['keyDown', 'keyUp']) {
    await send('Input.dispatchKeyEvent', { type, key: 'Escape', code: 'Escape', windowsVirtualKeyCode: 27 });
  }
  await sleep(2000);

  // 1. The lobby stands still.
  await evaluate(`window.__frames = []; 0`);
  await sleep(3000);
  const idleFrames = await evaluate(`window.__frames.length`);

  // 2. A quick game: "Play", then "Start", and the deal.
  await tap(83, 340);
  await sleep(1500);
  await tap(421, 324);
  await sleep(300);
  await evaluate(`window.__frames = []; window.__long = []; 0`);
  await sleep(7000);
  const frames = (await evaluate(`window.__frames`)) ?? [];
  const long = (await evaluate(`window.__long`)) ?? [];
  const work = frames.map((f) => f[1]);
  const gaps = frames.slice(1).map((f, i) => f[0] - frames[i][0]);
  const dealWork = stats(work);
  const dealGaps = stats(gaps);
  const longStats = stats(long.map((f) => f[1]));

  const result = { idleFrames, deal: { frames: frames.length, work: dealWork, gaps: dealGaps, long: longStats } };
  fs.writeFileSync('perf.json', JSON.stringify(result, null, 2));
  const idleOk = idleFrames <= 10;
  if (!idleOk) exitCode = 1;
  const md = [
    '## Performance (headless Chrome, 844×390, CPU 4× slower)',
    '',
    `| Check | Result |`,
    `|---|---|`,
    `| Lobby frames in 3 s while nothing happens | ${idleFrames} ${idleOk ? '✅' : '❌ (an endless animation?)'} |`,
    `| Deal: frames in 7 s | ${frames.length}${frames.length < 20 ? ' ⚠️ (did the game start?)' : ''} |`,
    `| Deal: work per frame p50 / p95 / max (ms) | ${dealWork.p50} / ${dealWork.p95} / ${dealWork.max} |`,
    `| Deal: time between frames p50 (ms) | ${dealGaps.p50} |`,
    `| Deal: stutters (frames over 50 ms), longest (ms) | ${longStats.n}, ${longStats.max} |`,
    '',
  ].join('\n');
  console.log(md);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + '\n');
} catch (e) {
  console.error('perf check failed to run:', e);
  exitCode = 2;
} finally {
  try {
    ws?.close();
  } catch {}
  chrome.kill('SIGKILL');
}
process.exit(exitCode);
