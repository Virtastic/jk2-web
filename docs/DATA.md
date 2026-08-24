# Supplying game data (demo + full retail)

The engines ship **no retail data** — you bring your own (GPL covers the *code*, not id/Raven's
assets). Each game loads its `.pk3` archives from `play/<game>/<gamedir>/`. The dev server
(`shared/web/server.py`) exposes `GET /__paks?dir=<gamedir>` which lists every `*.pk3` there, and
each `play/<game>/index.html` auto-discovers and loads **all** of them — so the *same* code path
serves the tiny free demo and the full retail install. Drop paks in, reload, done.

## Where the paks go

| Game | Port | Data dir | Retail paks (typical) | Run |
|------|------|----------|-----------------------|-----|
| JK2 | 8793 | `play/jk2/base/` (retail) · `play/jk2/demo/` (demo) | `assets0.pk3`, `assets1.pk3`, `assets2.pk3`, `assets5.pk3` | `python3 shared/web/server.py jk2` |

Then open `http://localhost:<port>/` (append `?args=+devmap <map>` to jump straight into a map).

## Demo checksum vs retail

These Raven engines gate demo vs retail themselves, in `FS_SetRestrictions()`
(`qcommon/files_pc.cpp`):

- **Demo mode**: the engine cannot resolve `productid.txt`, so it sets `fs_restrict 1`, restarts
  the filesystem on `DEMOGAME`, and requires **exactly one** pak whose checksum matches the
  built-in `DEMO_PAK_CHECKSUM` — any extra/altered pak → hard error `Corrupted pk3`. So the demo
  dir holds precisely the genuine `assets0.pk3` and nothing else. Do not add paks to `demo/`.
- **Retail mode**: drop the retail `assets*.pk3` into `play/jk2/base/` and reload. That is the
  whole procedure.

**There is no marker file to create.** An earlier version of this document said to add a
`productid.txt` to `base/`; that is wrong, and it would not have worked anyway — the file is not
a marker but a key, checked byte-for-byte against the scrambled `fs_scrambledProductId` table in
`files_common.cpp`, with a mismatch being a fatal `Invalid product identification`. `FS_ReadFile`
resolves it through the whole search path, **including inside the paks**, and the retail data
already ships it:

| Game | `productid.txt` lives in |
|------|--------------------------|
| JKA  | `assets2.pk3` |
| JK2  | `assets0.pk3` |

So a complete retail set drops the demo restrictions by itself. The failure mode to know about is
an *incomplete* set: pick only `assets0.pk3` + `assets1.pk3` on JK2 and there is no
`productid.txt` anywhere, the engine silently falls back to demo mode, and the multi-pak search
path then dies on `Corrupted pk3`. `play/jk2/index.html` now pre-checks the selected paks for a
`productid.txt` entry (by slicing each zip's tail, where the central directory lives) and explains
the problem instead of letting the engine fail that way.

**Status: JKA retail is verified end-to-end** — Steam install (`assets0..3.pk3`, 1.22 GB, 23,744
files), unrestricted `base/` search path, real main menu, `map yavin1` loads and plays. See
`docs/WASM_ADAPTATIONS.md`. The JK2 retail path is still unverified.

## Memory ceiling (why full-load, and its limit)

Paks are currently `fetch()` + `FS.writeFile` into MEMFS (the wasm heap). We can't use
`FS.createLazyFile` HTTP-Range streaming because modern browsers hard-block the synchronous XHR it
needs on the main thread ("Cannot do synchronous binary XHRs outside webworkers"). Full-load is
fine for the demo and **retail SP** (~0.5GB of paks + working set ≈ 1–1.5GB, under the 4GB wasm32
ceiling; the initial heap is 512MB, grows as needed). A title whose data approaches ~3GB (e.g. a
full install with movies) would need the engine moved into a **Web Worker + WORKERFS** so sync
reads stream from disk — the one known scaling task, tracked for later, not needed for SP campaigns.

## Saves / configs

Persisted in IndexedDB at `/userdata` (mounted via IDBFS, flushed every 15s and on tab hide).
They survive reloads and are independent of the paks you mount.
