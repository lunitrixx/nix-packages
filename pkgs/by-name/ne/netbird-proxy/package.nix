# NetBird reverse proxy - https://docs.netbird.io/manage/reverse-proxy
#
# An official part of a self-hosted NetBird server, but not (yet) packaged in
# nixpkgs. It is built here from the same source as the other components, via
# the parent 'netbird' derivation, so it stays version-matched with them.
{ netbird }:

netbird.override {
  componentName = "proxy";
}
