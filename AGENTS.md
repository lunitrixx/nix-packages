# AGENTS.md

Map of this repository for AI coding agents. Keep this file short. Details live in `docs/`.

## Project

- Name: `lunitrixx-nix-packages`
- Purpose: Custom Nix package set modelled on nixpkgs: an overlay that adds our packages on top of nixpkgs (anything we do not define falls through to nixpkgs)
- Stack: `Nix flake (flake-parts, import-tree), nixpkgs nixos-26.05, nixfmt-tree; dev shell devenv 2.4.1 with headfirst-msp/devenv-base`

## Commands

- Setup: `devenv shell` (run first; it also generates `.mcp.json`, `.pi/settings.json` and `.claude/`, which are not committed)
- Secrets are declared in `secretspec.toml`. Run a command that needs them as `secretspec run --reason "<why>" -- <command>`; SecretSpec asks for a reason in a session it detects as an agent and logs it. Never read a secret out of the environment into files, logs or replies. Setup per person: `docs/SECRETS.md`.
- Test: `nix flake check` (builds every package that needs no manual download and runs the smoke tests; must pass before every change is finished). Quick check of hooks, formatting and evaluation: `devenv test`
- Lint: `nix fmt` (nixfmt-tree, formats every `.nix` file; run before finishing a change). Check only: `nix fmt -- --ci`
- Build: `nix build .#<name>`, for example `nix build .#netbird .#zabbix74-agent2 .#mcp-forgejo-mcp`
- Source hash for a bump: `nurl <repo-url> <tag>` for a Git source, `nix store prefetch-file <url>` for a `fetchurl` tarball; `vendorHash` / `npmDepsHash` come from the mismatch error of one build

## This project

- `flake.nix` holds only the inputs, `mkFlake` and the import-tree root. Every output is one file in `modules/flake/`; files and directories starting with `_` are skipped by import-tree. Layout and mechanism: `docs/ARCHITECTURE.md`.
- `pkgs/by-name/**` and `pkgs/mcp/**` are plain nixpkgs-style package trees, never flake modules. A new `package.nix` is a new package; there is no central registration.
- Packaging rules (vendoring from nixpkgs, multi-component and attrset-valued packages, unfree and manual-download packages, bumps): `docs/PACKAGING.md`. Read it before adding or bumping a package.
- Always pin a specific version and hash. Never track a branch or `latest`.
- Do not change dependencies without approval: this includes `nix flake update` (the nixpkgs base in `flake.lock`) and any vendored package version. The skill `version-update` does approved bumps.
- The exposed overlays name their arguments `final`/`prev`; `nix flake check` requires it.
- `packages.<system>` is flat (`zabbix74-agent2`, `mcp-forgejo-mcp`); the overlay and `legacyPackages` keep the nesting (`pkgs.zabbix74.agent2`, `pkgs.mcp.forgejo-mcp`). `nix-images` uses `pkgs.zabbix74.<component>`, so that shape is a contract.
- A bump reaches consumers only after they update the input named `lunitrixx` (`nix flake update lunitrixx` or `devenv update lunitrixx`). `headfirst-msp/devenv-base` consumes `mcp.forgejo-mcp` this way.
- The repository is hosted on GitHub (`lunitrixx/nix-packages`); use `gh`, not `fj`.
- Pull requests: never open one without asking first, and never merge one without explicit confirmation; a green check is not a verified change. Always squash-merge with one clean message whose title ends with the PR number: `type(scope): summary (#N)`.
- Commits: `type(scope): summary` (types feat, fix, chore, docs, refactor, test, perf; summary imperative, at most 72 characters); the body explains why. One message per change. No trailer block on commits or PRs.
- After a change to the structure, entry points or commands, check that `README.md` is still accurate.

## Where knowledge lives

- Architecture and layers: `docs/ARCHITECTURE.md`
- Product behaviour: `docs/product-specs/index.md`
- Design decisions: `docs/design-docs/index.md`
- Plans: `docs/PLANS.md`. Active plans in `docs/exec-plans/active/`, finished ones in `docs/exec-plans/completed/`
- Known tech debt: `docs/exec-plans/tech-debt-tracker.md`
- Security rules: `docs/SECURITY.md`
- Secrets (SecretSpec, declared secrets, setup): `docs/SECRETS.md`
- Packaging rules and how to add or bump a package: `docs/PACKAGING.md`

## Plans, skills and tools

- Multi-step work gets a plan in `docs/exec-plans/active/` before implementation, as described in `docs/PLANS.md`. Move it to `docs/exec-plans/completed/` when the work is done.
- A plan is detailed and researched: goal, sources with versions, rejected alternatives, steps and verification. Its required sections are listed in `docs/PLANS.md`.
- Plans and skills never open with a role line such as "You are an expert in ...". State the purpose and the procedure directly.
- Skills are written once in `.agents/skills/<name>/SKILL.md`. devenv links each skill directory into `.claude/skills/` on shell entry. Edit the source, then re-enter the shell.
- Some skills are adapted copies of upstream skills. Before changing or updating one, read `.agents/skills/THIRD_PARTY.md`.
- Pi and Claude Code are installed by devenv through the shared base `headfirst-msp/devenv-base` (`devenv.yaml`). `.pi/settings.json` and `.claude/` are generated and not committed. Personal Pi settings go to `~/.pi/agent/settings.json`, personal Claude settings to `.claude/settings.local.json`.

## Boundaries

- Never commit to `main`. Branches: `feat/<topic>` or `fix/<topic>`.
- Delete a branch once its pull request is merged: on GitHub (`gh pr merge --squash -d` or the button after the merge) and locally (`git branch -d <branch>`, `git fetch --prune`).
- Never commit secrets. `.env` is never read into docs or commits.
- Never bypass git hooks (`--no-verify`, `-n`) on commit or push. When a hook fails, fix the cause. A false positive of the secret scan is silenced with a `betterleaks:allow` comment or an entry in `.betterleaksignore`, and only after the user confirms it is not a secret.
- Secrets are declared in `secretspec.toml` and provided by SecretSpec from each person's own store. Never write a secret value into the repository, and never read it out of the environment into files, logs or replies.
- Update the matching doc in the same change when behaviour changes.
- Record architecture decisions in `docs/design-docs/` as short records.
- Every lock or pin file of any tool or package manager is committed. Never add one to `.gitignore`.
- Change dependencies only through the tool that owns the lock file. Never edit a lock file by hand.

## Changelog (mandatory)

Record every user-facing change as one fragment in `changelog.d/`, never by editing `CHANGELOG.md`.

- Create it with `changelog-add "What changed for the reader, and why"`. It writes
  `changelog.d/YYYYMMDD-<hex>.md` with one Markdown bullet. The date is the day of the change. There
  are no versions and no `Unreleased` heading.
- A branch with `feat`, `fix` or `perf` commits needs a fragment. The hook `changelog-required`
  checks it on push.
- `CHANGELOG.md` is rendered from the fragments on `main` with `changelog-render`. A branch never
  edits it, so parallel branches do not conflict.

## Language (mandatory)

All code, in any programming or markup language (PHP, JavaScript, TypeScript,
Shell, PowerShell, HTML, CSS, SQL, Nix, Terraform, YAML, ...), and all Git
artifacts are written in English only, never in German:

- Identifiers, file and directory names, tests and test names
- Comments of every kind (line, block, doc comments, PHPDoc, JSDoc, HTML and CSS comments)
- Log messages and exception or error texts in code
- Commit messages, branch names, PR titles and bodies, issues, review comments
- CHANGELOG.md entries and tags

German is allowed only in chat replies to the user. User-visible product texts
(UI labels, mails, PDFs) follow the product's language, not this rule; translation
keys stay English. Before every commit and PR, check your own text; if it contains
German, rewrite it in English first.

## Writing and comments (mandatory)

Applies to code, comments, commit messages, PR texts, docs and the CHANGELOG.

- No em dashes or en dashes. Use the plain hyphen-minus `-`.
- No emojis, decorative symbols or emoji bullets. No filler such as "Certainly",
  "Great question" or marketing wording.
- Keep prose short and factual.

Comments:

- Write a comment only where the code does not explain itself: a non-obvious
  decision, a workaround, a constraint, an edge case.
- Explain why, not what. Never restate the code.
- Doc comments follow the language standard (PHPDoc, JSDoc, docstrings, ...) with one
  summary line. Document parameters only when names and types do not make them obvious.
- Do not comment trivial code. A variable named `$user` needs no comment.
- No banner comments, section dividers, commented-out code or change logs in code.
