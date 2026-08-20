# jk2-web

A browser / WebAssembly port of **Star Wars Jedi Knight II: Jedi Outcast** (single-player), built
from Raven's **original** 2002 GPL source drop (grayj/Jedi-Outcast mirror).

The engine is **GPLv2** — see `LICENSE`, and `games/jk2/LICENSE.txt` in the drop itself. Retail game
data is **not** included and is not redistributable: players supply their own legally-obtained copy,
or run the official free demo mission.

## Hard rule: strictly original sources

`games/jk2/` holds the pristine GPL drop (one "pristine import" commit). Every browser adaptation is
a separate reviewable commit on top. **Do not copy code from OpenJK, iortcw, or ET:Legacy** — consult
them for understanding only. The diff of `games/jk2` against its import commit *is* the port.

## Layout

- `games/jk2/` — the original engine sources (pristine import + port commits)
- `shared/wasm-build/` — `env.sh` (toolchain flags), `sys_emscripten/` + `sys_emscripten_jk/` (our
  platform layer), `build-jk2.sh` / `build-jk2-modules.sh`, and the CDP test harnesses
- `shared/web/` — `server.py` (COOP/COEP dev server, HTTP-Range for pk3 streaming) and
  `net-relay.mjs` (a standalone WebSocket relay; unused by this single-player port, see below)
- `play/jk2/` — `launcher.html` (entry: cloud / hosted / demo / bring-your-own) and `index.html`
  (the game page). Retail pk3s live in `play/jk2/base/` locally and are **never** committed.
- `cloud/` — optional Cloud Locker backend: OAuth sign-in plus S3 (or local-disk) storage for game
  data and saves. Not required to play.
- `docs/WASM_ADAPTATIONS.md` — the running engineering log (read/update this)

## Toolchain

Homebrew Emscripten **6.0.1** (`emcc`). Flags live in `shared/wasm-build/env.sh` — source it, don't
hardcode. No `-flto`. Single-threaded. See `docs/WASM_ADAPTATIONS.md`.

## Build / run

```sh
source shared/wasm-build/env.sh
shared/wasm-build/build-jk2.sh              # engine   -> play/jk2/{jk2.js,jk2.wasm}
shared/wasm-build/build-jk2-modules.sh      # game dll -> play/jk2/qagame.wasm
python3 shared/web/server.py jk2            # COOP/COEP dev server on :8793
node shared/wasm-build/console-check.mjs 8793 "+set sv_pure 0 +devmap kejim_post"
```

The two build scripts are separate on purpose: the game/cgame logic is an Emscripten **side module**
(`qagame.wasm`) that the engine `dlopen`s per map, mirroring the original's per-map DLL reload.

## Testing

The harnesses in `shared/wasm-build/*.mjs` drive a real headless Chrome over CDP — they boot the
actual engine and assert on what it renders and logs, rather than on mocks:

```sh
node shared/wasm-build/map-sweep.mjs 8793 "<map1,map2,...>"        # whole campaign, one session
node shared/wasm-build/verify-menu.mjs 8793 <map>                  # menus, incl. same-map reload
node shared/wasm-build/verify-transition.mjs 8793 <mapA> <mapB>    # scripted level transition
node shared/wasm-build/verify-jk-save.mjs jk2 8793 "+devmap <map>" # save round-trip incl. reload
node shared/wasm-build/verify-cinematic.mjs 8793 <name[,name]>     # RoQ video + audio
```

Two rules earned the hard way, worth keeping in mind when adding a probe (the full list is in the
engineering log):

- **A null result is evidence only if the instrument is proven live.** Run a positive control in the
  same session — twice in this port a "0" came from a probe that could not print at all.
- **A control must assert that the thing it removed is actually gone**, and print that assertion
  beside the result. `git stash` is a no-op on a change that is already committed.

## Scope notes

- **Single-player only.** The multiplayer sources (`games/jk2/CODE-mp/`) are part of the pristine
  drop but are not built. `shared/web/net-relay.mjs` and the relay plumbing in `index.html` are
  therefore inert here; they are kept because the relay is a standalone, documented utility
  (`docs/SECURITY.md`) rather than dead code inside the engine.
- **State.** The campaign runs end to end: 26/26 maps load and reach gameplay in one session, saves
  survive a page reload, scripted level transitions carry the player, and the RoQ cinematics play
  with audio. See `docs/WASM_ADAPTATIONS.md` for what was adapted and why.
