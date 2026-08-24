# syntax=docker/dockerfile:1
# =============================================================================================
# Jedi Knight II: Jedi Outcast — WebAssembly port.
#
# Two terminal stages, because the two audiences need different things:
#
#   runtime  (DEFAULT)  compiles the engine from the sources in this repo, then serves it.
#                       This is what `docker build .` gives you from a clean clone, and it is
#                       the only target that works without a prior local build:
#                           docker build -t jk2-web .
#                           docker run --rm -p 8080:80 jk2-web
#                       First build pulls emscripten/emsdk (~2-3 GB) and compiles for a few
#                       minutes; after that it is layer-cached.
#
#   prebuilt            PACKAGES an already-built play/jk2/ tree instead of compiling. The
#                       wasm/js are gitignored build products, so this target only works where
#                       they have been staged into the build context — the deploy workflow
#                       rsyncs them onto the runner. Selected explicitly:
#                           docker build --target prebuilt -t jk2:ovh .
#                       BuildKit skips stages the target does not depend on, so this never
#                       pulls or runs the toolchain: production builds exactly as fast as before.
#
# NO GAME DATA is baked in by either path beyond the freely-redistributable demo pak. Retail
# .pk3s live under play/jk2/base/ and are blocked by .dockerignore; the site is bring-your-own,
# demo, or Cloud Locker.
# =============================================================================================

# ---- prebuilt: package a tree that was built elsewhere (production/deploy path) --------------
FROM nginx:1.27-alpine AS prebuilt
LABEL org.opencontainers.image.title="jk2" \
      org.opencontainers.image.description="Jedi Knight II: Jedi Outcast — WebAssembly port" \
      org.opencontainers.image.licenses="GPL-2.0-or-later"
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
COPY play/jk2/ /usr/share/nginx/html/
# Fail loudly rather than shipping a site whose engine 404s. Without the staged build products
# this COPY still succeeds (the HTML pages are tracked), so the check has to be explicit.
RUN test -f /usr/share/nginx/html/jk2.wasm && test -f /usr/share/nginx/html/qagame.wasm || { \
      echo "FATAL: no engine in play/jk2/ — the --target prebuilt path packages an existing"; \
      echo "build and the wasm/js are gitignored, so nothing was staged into the context."; \
      echo "Either stage a build there, or use the default target which compiles from source:"; \
      echo "    docker build -t jk2-web ."; exit 1; }
HEALTHCHECK --interval=30s --timeout=4s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
EXPOSE 80

# ---- builder: compile engine + game module to wasm -------------------------------------------
FROM emscripten/emsdk:6.0.1 AS builder
WORKDIR /src
# Only the inputs the build actually reads. Copying the HTML here would make an edit to a page bust
# this (slow) compile layer, so the pages are taken from context in the runtime stage instead.
COPY games/jk2 /src/games/jk2
COPY shared    /src/shared
# build-jk2.sh         -> play/jk2/{jk2.js,jk2.wasm}   (MAIN_MODULE engine)
# build-jk2-modules.sh -> play/jk2/qagame.wasm         (SIDE_MODULE game/cgame/Icarus)
# env.sh finds emcc on PATH (the base image provides emcc 6.0.1 + python3 + node).
# No BuildKit cache mount on build-jk2/: a fresh compile (~3-4 min) is cheap and a cache mount is a
# correctness hazard here — it persisted a CRLF-broken engine-sources.txt and root-owned objects
# across failed builds. Reproducibility over a couple of minutes.
RUN bash shared/wasm-build/build-jk2.sh \
 && bash shared/wasm-build/build-jk2-modules.sh \
 && echo "=== ERRS engine:$(wc -c < build-jk2/build.errs) modules:$(wc -c < build-jk2/modules/build.errs) ===" \
 && test ! -s build-jk2/build.errs && test ! -s build-jk2/modules/build.errs \
 && ls -la play/jk2/jk2.js play/jk2/jk2.wasm play/jk2/qagame.wasm

# ---- runtime (DEFAULT): nginx serving the freshly compiled engine ----------------------------
FROM nginx:1.27-alpine AS runtime
LABEL org.opencontainers.image.title="jk2-web" \
      org.opencontainers.image.description="Jedi Knight II: Jedi Outcast — WebAssembly port (built from source)" \
      org.opencontainers.image.licenses="GPL-2.0-or-later"
# The purpose-built vhost: COOP/COEP/CORP on every response. (jk2 is single-threaded and does not
# strictly need cross-origin isolation to run, but the header set is kept identical to the rest of
# the Virtastic set, and the smoke test asserts it as a "config intact" check.)
COPY infra/nginx.conf /etc/nginx/conf.d/default.conf
# Static pages from context: a fast runtime-only rebuild when they change.
COPY play/jk2/index.html play/jk2/launcher.html /usr/share/nginx/html/
# og.png is what the OG/Twitter tags in both pages point at. The prebuilt target gets it
# from the wholesale play/jk2/ copy; this target copies file by file, so name it here too
# or a locally built container advertises a social card that 404s.
COPY play/jk2/og.png /usr/share/nginx/html/
# Built engine + game module from the builder stage.
COPY --from=builder /src/play/jk2/jk2.js      /usr/share/nginx/html/
COPY --from=builder /src/play/jk2/jk2.wasm    /usr/share/nginx/html/
COPY --from=builder /src/play/jk2/qagame.wasm /usr/share/nginx/html/
HEALTHCHECK --interval=30s --timeout=4s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
EXPOSE 80
