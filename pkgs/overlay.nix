# The complete overlay of this repository: the top-level packages from
# pkgs/by-name plus the MCP server set pkgs.mcp from pkgs/mcp. Both the exposed
# overlays.default and the flake's own base set use this file, so they cannot
# drift apart.
final: prev:
import ./by-name-overlay.nix ./by-name final prev // import ./mcp-overlay.nix ./mcp final prev
