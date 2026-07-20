# Star Wars Jedi Knight II: Jedi Outcast — WebAssembly (browser) port

Browser / WebAssembly port of **Star Wars Jedi Knight II: Jedi Outcast**, built from the original 2002 Raven Software GPL source drop. Renders and plays in the browser — Ghoul2 skeletal characters, saber, Force.

## Layout
- `games/jk2/` — original GPL engine source (pristine import + `__EMSCRIPTEN__`-guarded port commits)
- `shared/wasm-build/` — Emscripten toolchain flags, platform layer, per-game build scripts, CDP test harnesses
- `shared/web/` — COOP/COEP dev server (`server.py`)
- `play//` — the browser entry page
- `docs/WASM_ADAPTATIONS.md` — the engineering log; `docs/DATA.md` — how to supply game data

## Build & run
```sh
source shared/wasm-build/env.sh          # Homebrew Emscripten 6.0.1
shared/wasm-build/build-jk2.sh
python3 shared/web/server.py jk2           # dev server on :8793
# open http://localhost:8793/
```

**Game data is bring-your-own** — retail pk3s are never committed (GPL covers the *code*, not
id/Raven's assets). See `docs/DATA.md`.

Built with the Claude Agent SDK.
