# 0001 zabbix74 as one attrset-valued package

Status: accepted (recorded during the template migration on 2026-11-06; the decision is older).

## Context

Zabbix 7.4 has many variants from one source: server and proxy per database, agent, agent2, web.
nixpkgs builds them with `zabbixFor "v74"`, which returns an attrset. `nix-images` wires
`pkgs.zabbix74.server-pgsql` and its siblings directly.

## Decision

`pkgs/by-name/za/zabbix74/package.nix` reproduces nixpkgs' `zabbixFor "v74"` block and returns
`recurseIntoAttrs (...)`. The version and hash live once in `versions.nix`; the component files are
vendored verbatim. The flake's `packages` and `checks` flatten the attrset into `zabbix74-<sub>`
build targets, because flake outputs must be flat derivations.

## Rejected alternatives

- One by-name file per variant, as for NetBird: it breaks the `pkgs.zabbix74.<sub>` access that
  `nix-images` relies on.

## Consequences

- The attrset shape is part of the contract with consumers and must not change.
- This shape is used only when a consumer needs the attrset access; other multi-component packages
  use one by-name file per component.
