# 0002 MCP servers in their own set pkgs.mcp

Status: accepted (2026-11-04, recorded during the template migration on 2026-11-06).

## Context

MCP servers should keep their upstream names. nixpkgs already has a top-level `forgejo-mcp`, an
unrelated Go server, so a by-name `forgejo-mcp` would shadow it for every consumer of
`overlays.default`.

## Decision

MCP servers live in `pkgs/mcp/<name>/package.nix` without a shard. `pkgs/mcp-overlay.nix` exposes
them as `pkgs.mcp.<name>`; `pkgs/overlay.nix` combines it with the by-name overlay. `overlays.mcp`
adds only the set. In the flat `packages` output a server is `mcp-<name>`.

## Rejected alternatives

- A by-name entry under a changed name (the first version was `mcp-forgejo`): it hides the upstream
  name and still fills the top-level namespace.

## Consequences

- `pkgs.mcp.forgejo-mcp` is ours, `pkgs.forgejo-mcp` stays nixpkgs'.
- Consumers that only want the MCP servers use `overlays.mcp` and keep nixpkgs' other packages.
