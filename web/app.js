"use strict";

(async () => {
  const canvas = document.getElementById("game");
  const status = document.getElementById("status");
  const memory = new odin.WasmMemoryInterface();
  const graphics = new odin.WebGLInterface(memory);
  const input = { x: 0, y: 0, held: false, pressed: false, wheelX: 0, wheelY: 0 };
  let primaryPointer = null;
  let contextLost = false;
  let lastPlayerCount = 0;

  function showError(error) {
    status.hidden = false;
    status.textContent = `Could not load the game. ${error.message || error} Reload to try again.`;
    document.documentElement.dataset.gameReady = "false";
    console.error(error);
  }

  function resize() {
    const { width, height } = canvas.getBoundingClientRect();
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const pixelWidth = Math.max(1, Math.round(width * ratio));
    const pixelHeight = Math.max(1, Math.round(height * ratio));
    if (canvas.width !== pixelWidth) canvas.width = pixelWidth;
    if (canvas.height !== pixelHeight) canvas.height = pixelHeight;
    return { width, height, ratio };
  }

  function pointerPosition(event) {
    const rect = canvas.getBoundingClientRect();
    input.x = event.clientX - rect.left;
    input.y = event.clientY - rect.top;
  }

  canvas.addEventListener("pointerdown", event => {
    if (event.button !== 0 || primaryPointer !== null) return;
    primaryPointer = event.pointerId;
    canvas.setPointerCapture(event.pointerId);
    canvas.focus({ preventScroll: true });
    pointerPosition(event);
    input.held = input.pressed = true;
    event.preventDefault();
  });
  canvas.addEventListener("pointermove", event => {
    if (primaryPointer === null || primaryPointer === event.pointerId) pointerPosition(event);
  });
  function releasePointer(event) {
    if (event.pointerId !== primaryPointer) return;
    pointerPosition(event);
    primaryPointer = null;
    input.held = false;
  }
  canvas.addEventListener("pointerup", releasePointer);
  canvas.addEventListener("pointercancel", releasePointer);
  canvas.addEventListener("lostpointercapture", releasePointer);
  window.addEventListener("blur", () => {
    primaryPointer = null;
    input.held = input.pressed = false;
  });
  canvas.addEventListener("keydown", event => {
    if ((event.key === "Enter" || event.key === " ") && !event.repeat) {
      input.pressed = true;
      event.preventDefault();
    }
  });
  canvas.addEventListener("wheel", event => {
    const unit = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? canvas.clientHeight : 1;
    input.wheelX -= event.deltaX * unit / 100;
    input.wheelY -= event.deltaY * unit / 100;
    event.preventDefault();
  }, { passive: false });
  new ResizeObserver(resize).observe(canvas);
  canvas.addEventListener("webglcontextlost", event => {
    event.preventDefault();
    contextLost = true;
    showError(new Error("The graphics context was lost."));
  });
  canvas.addEventListener("webglcontextrestored", () => location.reload());
  window.addEventListener("pagehide", event => {
    if (!event.persisted && memory.exports?.shutdown) memory.exports.shutdown();
  });
  window.addEventListener("error", event => showError(event.error || event.message));

  async function loadImage(path, width, height) {
    const image = new Image();
    image.src = path;
    await image.decode();
    if (image.naturalWidth !== width || image.naturalHeight !== height) {
      throw new Error(`Unexpected dimensions for ${path}.`);
    }
    return image;
  }

  function parseFont(text) {
    const fields = line => Object.fromEntries(
      Array.from(line.matchAll(/(\w+)=(-?\d+)/g), match => [match[1], Number(match[2])])
    );
    const lines = text.split(/\r?\n/);
    const common = fields(lines.find(line => line.startsWith("common ")) || "");
    const count = fields(lines.find(line => line.startsWith("chars ")) || "").count;
    const glyphs = lines.filter(line => line.startsWith("char ")).map(fields);
    if (!(common.lineHeight > 0) || common.scaleW !== 512 || common.scaleH !== 1024 ||
        count !== glyphs.length || glyphs.length > 128) {
      throw new Error("Invalid font metrics.");
    }
    for (const glyph of glyphs) {
      const values = [glyph.id, glyph.x, glyph.y, glyph.width, glyph.height,
        glyph.xoffset, glyph.yoffset, glyph.xadvance];
      if (!values.every(Number.isFinite) || glyph.x < 0 || glyph.y < 0 ||
          glyph.x + glyph.width > common.scaleW || glyph.y + glyph.height > common.scaleH) {
        throw new Error("Invalid font glyph.");
      }
    }
    return { lineHeight: common.lineHeight, glyphs };
  }

  try {
    const assets = [
      ["assets/example-tiles.webp", 640, 128],
      ["assets/example-factory.webp", 192, 128],
      ["assets/example-player-board.webp", 384, 256],
      ["assets/light-wood-table.webp", 512, 512],
      ["assets/fonts/spectral-semibold.png", 512, 1024],
    ];
    const [images, font] = await Promise.all([
      Promise.all(assets.map(asset => loadImage(...asset))),
      fetch("assets/fonts/spectral-semibold.fnt").then(async response => {
        if (!response.ok) throw new Error("Could not fetch font metrics.");
        return parseFont(await response.text());
      }),
    ]);
    resize();
    await odin.runWasm("game.wasm", null, {
      // Reuse Odin's WebGL bridge; only image upload and browser state are custom.
      webgl: graphics.getWebGL1Interface(),
      nbg: {
        read_input(pointer) {
          const { width, height, ratio } = resize();
          memory.loadF32Array(pointer, 8).set([
            width, height, ratio, input.x, input.y, input.wheelX, input.wheelY,
            document.hidden || contextLost ? 0 : 1,
          ]);
          memory.loadI32Array(pointer + 32, 2).set([Number(input.held), Number(input.pressed)]);
          input.pressed = false;
          input.wheelX = input.wheelY = 0;
          const count = memory.exports.get_player_count();
          if (count !== lastPlayerCount) {
            lastPlayerCount = count;
            canvas.dataset.playerCount = String(count);
            canvas.setAttribute("aria-label", `Tile game, ${count} players. Click, tap, or press Enter to change player count.`);
          }
        },
        upload_image(handle, asset) {
          const texture = graphics.textures[handle];
          const image = images[asset];
          if (!texture || !image) return false;
          const gl = graphics.ctx;
          gl.bindTexture(gl.TEXTURE_2D, texture);
          gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
          gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
          return gl.getError() === gl.NO_ERROR;
        },
        read_font(pointer, capacity, heightPointer) {
          if (font.glyphs.length > capacity) return 0;
          memory.loadF32Array(heightPointer, 1)[0] = font.lineHeight;
          for (const [index, glyph] of font.glyphs.entries()) {
            const address = pointer + index * 32;
            memory.loadU32Array(address, 1)[0] = glyph.id;
            memory.loadF32Array(address + 4, 7).set([
              glyph.x, glyph.y, glyph.width, glyph.height,
              glyph.xoffset, glyph.yoffset, glyph.xadvance,
            ]);
          }
          return font.glyphs.length;
        },
        report_error(pointer, length) {
          throw new Error(memory.loadString(pointer, length));
        },
      },
    }, memory);
    status.hidden = true;
    document.documentElement.dataset.gameReady = "true";
    window.Telegram?.WebApp?.ready();
    window.Telegram?.WebApp?.expand();
  } catch (error) {
    showError(error);
  }
})();
