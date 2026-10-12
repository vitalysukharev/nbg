# Browser build

Requires Odin and LLVM's `wasm-ld` linker (`lld` on Arch Linux). No Emscripten,
raylib web library, JavaScript package manager, or image/font decoder is needed.

From the project root:

```sh
bash scripts/build-web.sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory build/web
```

Open <http://localhost:8000>. Click, tap, or press Enter/Space on the canvas to
cycle through two, three, and four players. Resizing or rotating the viewport
recalculates the shared Clay layout. Pointer capture keeps touch gestures stable,
and rendering accounts for device pixel ratio (capped at 2).

The complete static bundle is in `build/web/`. Deploy that directory as a unit;
serve `.wasm` as `application/wasm` and enable HTTP compression. Keep textures
and the font outside WASM so browsers can cache them independently. The page
must be served over HTTP or HTTPS, rather than opened directly with `file://`.

`main_web.odin` provides the browser entry point and animation-frame export.
`renderer_web.odin` batches textured triangles through `vendor:wasm/WebGL`,
including nine-slice boards, repeating wood, rounded slots, bitmap text, and
scissor clipping. The shader sources there are the starting point for additional
effects. `web/app.js` adds browser image uploads, font metrics, input, and resizing
to the matching `odin.js` copied from the installed compiler.

Desktop keeps its raylib renderer; layouts, sprite descriptors, theme, and rules
are shared. Rebuild after changing Odin code or assets. The build script also
accepts an output directory: `bash scripts/build-web.sh /path/to/output`.

Run the browser checks after building (Node 22+ and Chromium required):

```sh
node scripts/test-web.mjs
```

The test starts a temporary localhost server and headless Chromium. It checks
actual WebGL output, mouse/touch/keyboard input, held presses, all player counts
across portrait and landscape sizes, high-DPI sizing, and missing-asset feedback.
It writes a browser screenshot to `bin/wasm-browser-preview.png` and shuts down
its server and browser. Set `CHROMIUM` if the browser executable has another name.

For a Telegram Mini App, host the bundle over HTTPS and configure the app URL in
Telegram. If the host page loads Telegram's Web App SDK, this page calls `ready()`
and `expand()` once assets and WASM are initialized. Bot configuration and SDK
loading are separate from this local browser build.
