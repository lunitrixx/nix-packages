# nixpkgs-update: no auto update
# updated via the parent 'netbird' derivation
#
# BROKEN as of netbird 0.75.0: the UI now uses //go:embed all:frontend/dist
# which requires a pre-built React frontend (npm/pnpm install + vite build).
# The old wails-free Go build no longer works. Re-enabling this needs a
# full two-phase build (frontend → go build with CGO).
{ netbird }:

(netbird.override {
  componentName = "ui";
}).overrideAttrs
  (old: {
    meta = old.meta // {
      broken = true;
    };
  })
