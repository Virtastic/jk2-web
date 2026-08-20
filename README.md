# Star Wars Jedi Knight II: Jedi Outcast — WebAssembly (browser) port

Browser / WebAssembly port of **Star Wars Jedi Knight II: Jedi Outcast**, built from the original 2002 Raven Software GPL source drop. Renders and plays in the browser — Ghoul2 skeletal characters, saber, Force.

## Layout
- `games/jk2/` — original GPL engine source (pristine import + `__EMSCRIPTEN__`-guarded port commits)
- `shared/wasm-build/` — Emscripten toolchain flags, platform layer, per-game build scripts, CDP test harnesses
- `shared/web/` — COOP/COEP dev server (`server.py`)
- `play/jk2/` — the browser entry page
- `docs/WASM_ADAPTATIONS.md` — the engineering log; `docs/DATA.md` — how to supply game data

## Build & run
```sh
source shared/wasm-build/env.sh              # Emscripten 6.0.1 (any install; see env.sh)
shared/wasm-build/build-jk2.sh                # engine  -> play/jk2/{jk2.js,.wasm}
shared/wasm-build/build-jk2-modules.sh        # game DLL -> play/jk2/qagame.wasm
python3 shared/web/server.py jk2             # dev server on :8793
# open http://localhost:8793/
```

Both scripts are needed: the engine alone boots to the menu, but loading a map requires the
game module (`qagame.wasm`), which is where SP keeps game + cgame.

Smoke tests (need `npm install` for the `ws` client, and Chrome/Chromium on PATH or `$CHROME`):

```sh
node shared/wasm-build/console-check.mjs 8793 "+map <map>" jk2   # errors/warnings on a real boot
node shared/wasm-build/verify-jk-play.mjs jk2 8793 "+map <map>"  # is it actually drawing?
node shared/wasm-build/boot-log.mjs 8793 "+map <map>"           # the engine boot log, verbatim
```

**Game data is bring-your-own** — retail pk3s are never committed (GPL covers the *code*, not
id/Raven's assets). See `docs/DATA.md`.

Built with the Claude Agent SDK.
