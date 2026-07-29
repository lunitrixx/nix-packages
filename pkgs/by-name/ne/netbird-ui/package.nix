# nixpkgs-update: no auto update
# updated via the parent 'netbird' derivation
#
# As of netbird 0.75.0 the UI uses //go:embed all:frontend/dist, which needs a
# pre-built React frontend (pnpm install + vite build). The parent netbird
# derivation now does a two-phase build: pnpm frontend first, then CGo build.
{ netbird }:

netbird.override {
  componentName = "ui";
}
