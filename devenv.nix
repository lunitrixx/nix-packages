{
  pkgs,
  lib,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    # Source hashes for version bumps (see docs/PACKAGING.md).
    pkgs.nurl
  ];

  # https://devenv.sh/integrations/claude-code/#mcp-servers
  # mkForce replaces the whole set from devenv-base: this package set has nothing to do with the
  # headfirst Forgejo, so its MCP server is left out. The nixos server answers nixpkgs and option
  # lookups (used by the nixos skill).
  claude.code.mcpServers = lib.mkForce {
    nixos = {
      type = "stdio";
      command = lib.getExe pkgs.mcp-nixos;
    };
  };

  # https://devenv.sh/git-hooks/
  git-hooks.hooks.markdownlint.excludes = [
    # Third-party skills keep their upstream formatting so updates stay diffable (see .agents/skills/THIRD_PARTY.md).
    "^\\.agents/skills/(verification-before-completion|systematic-debugging|test-driven-development|receiving-code-review|grilling)/"
    # The PR template is a form text, not a document: it does not start with a heading.
    "^\\.github/pull_request_template\\.md$"
  ];
  # The CHANGELOG history from before the fragments repeats "### Added" / "### Fixed" under each day.
  git-hooks.hooks.markdownlint.settings.configuration.MD024 = {
    siblings_only = true;
  };

  # The full `nix flake check` builds every package, including large unfree AppImages, and is run on its
  # own. Here only formatting and evaluation of every output are checked.
  enterTest = ''
    nix fmt -- --ci
    nix flake check --no-build
  '';
}
