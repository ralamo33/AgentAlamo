import { chromium } from 'playwright';
import http from 'node:http';
import { spawn } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../..');
const CANVAS_BIN = path.join(ROOT, 'bin/canvas');
const PORT = 4737;
const BASE = `http://127.0.0.1:${PORT}`;
const PLAN_NAME = 'todo-e2e';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function httpPost(urlPath, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const url = new URL(urlPath, BASE);
    const req = http.request(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
    }, (res) => {
      let buf = '';
      res.on('data', c => { buf += c; });
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    });
    req.on('error', reject);
    req.end(data);
  });
}

function httpGet(urlPath) {
  return new Promise((resolve, reject) => {
    http.get(new URL(urlPath, BASE), (res) => {
      let buf = '';
      res.on('data', c => { buf += c; });
      res.on('end', () => { try { resolve(JSON.parse(buf)); } catch { resolve(buf); } });
    }).on('error', reject);
  });
}

function poll(name) {
  return new Promise((resolve, reject) => {
    http.get(new URL(`/api/poll?name=${name}`, BASE), (res) => {
      let buf = '';
      res.on('data', c => { buf += c; });
      res.on('end', () => {
        try { resolve(JSON.parse(buf.trim())); }
        catch (e) { reject(new Error(`Poll parse error: ${buf.slice(0, 200)}`)); }
      });
    }).on('error', reject);
  });
}

async function cleanup() {
  try { await httpPost('/shutdown', {}); } catch {}
  await sleep(500);
  const planFile = path.join(os.homedir(), '.canvas', 'active_plans', `${PLAN_NAME}.html`);
  try { fs.unlinkSync(planFile); } catch {}
  const stateFile = path.join(os.homedir(), '.canvas', 'state.json');
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    delete state.sessions[PLAN_NAME];
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
  } catch {}
}

async function startServer() {
  const proc = spawn('node', [CANVAS_BIN, 'server'], { stdio: ['pipe', 'pipe', 'pipe'] });
  proc.stderr.on('data', d => process.stderr.write(d));
  for (let i = 0; i < 50; i++) {
    try { await httpGet('/health'); return proc; } catch { await sleep(100); }
  }
  proc.kill();
  throw new Error('Server did not start within 5 seconds');
}

async function annotate(planFrame, selector, note) {
  await planFrame.locator(selector).click();
  await planFrame.locator('#noteInput').waitFor({ state: 'visible', timeout: 5000 });
  await planFrame.locator('#noteInput').fill(note, { force: true });
  await sleep(600);
  await planFrame.locator('#queueBtn').click({ force: true });
  await sleep(800);
}

async function main() {
  console.log('=== Canvas E2E Test ===\n');

  console.log('1. Cleaning up previous state...');
  await cleanup();

  console.log('2. Starting canvas server...');
  const server = await startServer();
  console.log('   Server running on port', PORT);

  let browser;
  let page;

  try {
    console.log('3. Opening plan (v1 - basic todo)...');
    const planV1 = path.join(__dirname, 'plans', 'todo-v1.html');
    await httpPost('/api/plans/open', { name: PLAN_NAME, path: planV1 });

    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
      recordVideo: { dir: path.join(__dirname, 'videos'), size: { width: 1280, height: 720 } },
    });
    page = await context.newPage();

    await page.goto(`${BASE}/session/${PLAN_NAME}`);
    console.log('   Waiting for layout audit...');
    await page.locator('#layoutGate').waitFor({ state: 'hidden', timeout: 15000 });
    await sleep(1000);

    const planFrame = page.frameLocator('#planFrame');

    // ── Round 1: Annotate basic todo ─────────────────────────────────────────
    console.log('\n4. Round 1: Annotating basic todo...');

    const poll1 = poll(PLAN_NAME);
    await sleep(500);

    await annotate(planFrame, 'h1', 'Make this title much larger and bolder');
    console.log('   Queued: h1 annotation');

    await annotate(planFrame, 'li >> nth=0', 'Add checkboxes to each task item');
    console.log('   Queued: list item annotation');

    await page.locator('#chatInput').click();
    await page.locator('#chatInput').type('Overall needs better styling and visual hierarchy', { delay: 25 });
    await sleep(400);
    await page.locator('#sendBtn').click();
    console.log('   Sent feedback to agent');

    const fb1 = await poll1;
    console.log(`   Agent received ${fb1.prompts?.length ?? 0} prompts`);

    await httpPost(`/api/${PLAN_NAME}/agent-reply`, {
      text: 'Got it! Adding checkboxes, bigger title, and better styling...',
    });
    await sleep(2500);

    // ── Round 2: Review improved version ─────────────────────────────────────
    console.log('\n5. Round 2: Updating to v2 (checkboxes + green styling)...');
    const planV2 = path.join(__dirname, 'plans', 'todo-v2.html');
    await httpPost('/api/plans/update', { name: PLAN_NAME, path: planV2 });

    await sleep(2000);
    await page.locator('#layoutGate').waitFor({ state: 'hidden', timeout: 15000 });
    await sleep(1000);

    const poll2 = poll(PLAN_NAME);
    await sleep(500);

    await annotate(planFrame, '.task >> nth=0', 'Switch to a blue color scheme instead of green');
    console.log('   Queued: color scheme annotation');

    await page.locator('#chatInput').click();
    await page.locator('#chatInput').type('Almost there! Change the green to blue and wrap in a card', { delay: 25 });
    await sleep(400);
    await page.locator('#sendBtn').click();
    console.log('   Sent feedback to agent');

    const fb2 = await poll2;
    console.log(`   Agent received ${fb2.prompts?.length ?? 0} prompts`);

    await httpPost(`/api/${PLAN_NAME}/agent-reply`, {
      text: 'Switching to blue theme with card layout now.',
    });
    await sleep(2500);

    // ── Round 3: Review final version and confirm ─────────────────────────────
    console.log('\n6. Round 3: Updating to v3 (blue theme + card layout)...');
    const planV3 = path.join(__dirname, 'plans', 'todo-v3.html');
    await httpPost('/api/plans/update', { name: PLAN_NAME, path: planV3 });

    await sleep(2000);
    await page.locator('#layoutGate').waitFor({ state: 'hidden', timeout: 15000 });
    await sleep(1000);

    const poll3 = poll(PLAN_NAME);
    await sleep(500);

    console.log('7. Confirming plan with final notes...');
    await page.locator('#chatInput').click();
    await page.locator('#chatInput').type('Looks perfect, shipping it!', { delay: 25 });
    await sleep(400);
    await page.locator('#confirmBtn').click();

    const fb3 = await poll3;
    console.log(`   Agent received status: ${fb3.status}, ${fb3.prompts?.length ?? 0} prompts`);
    await sleep(3000);

    console.log('\n8. Saving recording...');
    await context.close();
    const dest = path.join(ROOT, 'e2e-recording.webm');
    await page.video().saveAs(dest);
    console.log(`   Recording saved: ${dest}`);

  } finally {
    if (browser) await browser.close().catch(() => {});
    server.kill();
    await sleep(300);
  }

  console.log('\n=== E2E Test Complete ===');
}

main().catch(err => {
  console.error('\nE2E test failed:', err);
  process.exit(1);
});
