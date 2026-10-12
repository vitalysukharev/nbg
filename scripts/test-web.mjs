import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { setTimeout as delay } from "node:timers/promises";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bundle = resolve(process.argv[2] || `${project}/build/web`);
const profile = await mkdtemp(`${tmpdir()}/nbg-web-test-`);
const module = new WebAssembly.Module(await readFile(`${bundle}/game.wasm`));
assert(WebAssembly.Module.imports(module).every(item => ["odin_env", "webgl", "nbg"].includes(item.module)));

let missingAsset = "";
const mime = { ".wasm": "application/wasm", ".js": "text/javascript", ".html": "text/html",
  ".webp": "image/webp", ".png": "image/png", ".fnt": "text/plain" };
const server = createServer(async (request, response) => {
  try {
    const path = new URL(request.url, "http://localhost").pathname;
    const file = resolve(bundle, `.${path === "/" ? "/index.html" : path}`);
    if (!file.startsWith(`${bundle}${sep}`) || path === missingAsset) throw new Error("Missing asset");
    const bytes = await readFile(file);
    response.writeHead(200, { "Content-Type": mime[file.slice(file.lastIndexOf("."))] || "application/octet-stream" });
    response.end(bytes);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
});

class CDP {
  constructor(socket) {
    this.socket = socket;
    this.pending = new Map();
    this.sequence = 0;
    this.errors = [];
    socket.addEventListener("message", event => {
      const message = JSON.parse(event.data);
      if (message.id) {
        const pending = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(JSON.stringify(message.error)));
        else pending.resolve(message.result);
      } else if (message.method === "Runtime.exceptionThrown") {
        this.errors.push(message.params.exceptionDetails);
      } else if (message.method === "Runtime.consoleAPICalled" && message.params.type === "error") {
        this.errors.push(message.params.args.map(arg => arg.value || arg.description));
      }
    });
  }
  static async connect(url) {
    const socket = new WebSocket(url);
    await new Promise((ok, fail) => {
      socket.addEventListener("open", ok, { once: true });
      socket.addEventListener("error", fail, { once: true });
    });
    return new CDP(socket);
  }
  send(method, params = {}) {
    const id = ++this.sequence;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  }
  async wait(expression, timeout = 15000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await this.evaluate(expression)) return;
      await delay(40);
    }
    throw new Error(`Timed out waiting for: ${expression}`);
  }
}

let chrome, page, browser;
let chromeLog = "";
try {
  await new Promise((ok, fail) => {
    server.once("error", fail);
    server.listen(0, "127.0.0.1", ok);
  });
  chrome = spawn(process.env.CHROMIUM || "chromium", [
    "--headless=new", "--no-first-run", "--no-default-browser-check", "--disable-background-networking",
    "--disable-dev-shm-usage", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
    "--remote-debugging-address=127.0.0.1", "--remote-debugging-port=0", `--user-data-dir=${profile}`, "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  chrome.stderr.on("data", chunk => { chromeLog = (chromeLog + chunk).slice(-4000); });
  let endpoint;
  for (let attempt = 0; attempt < 200; attempt++) {
    try { endpoint = (await readFile(`${profile}/DevToolsActivePort`, "utf8")).trim().split("\n"); break; }
    catch { await delay(50); }
  }
  assert(endpoint, `Chromium did not start: ${chromeLog}`);
  browser = await CDP.connect(`ws://127.0.0.1:${endpoint[0]}${endpoint[1]}`);
  const { targetId } = await browser.send("Target.createTarget", { url: "about:blank" });
  const targets = await (await fetch(`http://127.0.0.1:${endpoint[0]}/json/list`)).json();
  page = await CDP.connect(targets.find(target => target.id === targetId).webSocketDebuggerUrl);
  await page.send("Runtime.enable");
  await page.send("Page.enable");
  await page.send("Network.enable");
  await page.send("Network.setCacheDisabled", { cacheDisabled: true });
  await page.send("Emulation.setDeviceMetricsOverride", { width: 800, height: 600, deviceScaleFactor: 1, mobile: false });
  await page.send("Page.navigate", { url: `http://127.0.0.1:${server.address().port}/` });
  await page.wait('document.documentElement.dataset.gameReady === "true"');

  const count = () => page.evaluate('Number(document.getElementById("game").dataset.playerCount)');
  const click = async () => {
    await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 20, y: 20, button: "left", clickCount: 1 });
    await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 20, y: 20, button: "left", clickCount: 1 });
  };
  await page.wait('document.getElementById("game").dataset.playerCount === "2"');
  for (const expected of [3, 4, 2]) {
    await click();
    await page.wait(`document.getElementById("game").dataset.playerCount === "${expected}"`);
  }
  await page.send("Input.dispatchMouseEvent", { type: "mousePressed", x: 20, y: 20, button: "left", clickCount: 1 });
  await page.wait('document.getElementById("game").dataset.playerCount === "3"');
  await delay(200);
  assert.equal(await count(), 3, "Holding a pointer must not repeat presses");
  await page.send("Input.dispatchMouseEvent", { type: "mouseReleased", x: 20, y: 20, button: "left", clickCount: 1 });
  await page.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Enter", code: "Enter" });
  await page.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Enter", code: "Enter" });
  await page.wait('document.getElementById("game").dataset.playerCount === "4"');
  await page.send("Emulation.setTouchEmulationEnabled", { enabled: true });
  await page.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: 20, y: 20 }] });
  await page.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  await page.wait('document.getElementById("game").dataset.playerCount === "2"');
  await delay(100);
  assert.equal(await count(), 2, "A touch must not also trigger an emulated mouse press");

  for (const [width, height, scale] of [[800, 600, 1], [600, 800, 1], [480, 480, 1],
      [480, 481, 1], [481, 480, 1], [1920, 1080, 1], [480, 1600, 1], [1600, 480, 1], [390, 844, 2]]) {
    await page.send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: scale, mobile: scale === 2 });
    for (const expected of [2, 3, 4]) {
      while (await count() !== expected) {
        const before = await count();
        await click();
        await page.wait(`Number(document.getElementById("game").dataset.playerCount) !== ${before}`);
      }
      const pixels = await page.evaluate(`new Promise(resolve => requestAnimationFrame(() => {
        const canvas = document.getElementById("game");
        const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
        const data = new Uint8Array(4);
        gl.readPixels(2, 2, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, data);
        resolve({ error: gl.getError(), width: canvas.width, height: canvas.height, pixel: Array.from(data) });
      }))`);
      assert.equal(pixels.error, 0, `WebGL error at ${width}x${height} with ${expected} players`);
      assert.equal(pixels.width, width * scale);
      assert.equal(pixels.height, height * scale);
      assert(pixels.pixel.slice(0, 3).every(value => value > 80), "The wooden table must be drawn");
    }
  }
  assert.deepEqual(page.errors, [], "Unexpected browser errors");
  await mkdir(`${project}/bin`, { recursive: true });
  const screenshot = await page.send("Page.captureScreenshot", { format: "png" });
  await writeFile(`${project}/bin/wasm-browser-preview.png`, Buffer.from(screenshot.data, "base64"));

  missingAsset = "/assets/example-tiles.webp";
  await page.send("Page.reload", { ignoreCache: true });
  await page.wait('document.documentElement.dataset.gameReady === "false"');
  assert(await page.evaluate('!document.getElementById("status").hidden && document.getElementById("status").textContent.includes("Could not load")'));
  console.log("Browser checks passed: WASM imports, assets, mouse/hold/touch/keyboard, 27 viewport/player combinations, DPR, WebGL rendering, and missing-asset feedback.");
  console.log(`Preview: ${project}/bin/wasm-browser-preview.png`);
} finally {
  page?.socket.close();
  if (browser) {
    await browser.send("Browser.close").catch(() => {});
    browser.socket.close();
  }
  if (chrome && chrome.exitCode === null) {
    await new Promise(resolve => { chrome.once("exit", resolve); chrome.kill(); });
  }
  if (server.listening) await new Promise(resolve => server.close(resolve));
  await rm(profile, { recursive: true, force: true });
}
