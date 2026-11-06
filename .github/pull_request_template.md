Before you submit:

- Work on a branch named `feat/<topic>` or `fix/<topic>`, never on `main`.
- Title the PR `type(scope): summary` (Conventional Commits). It becomes the squash commit title, with the PR number appended: `type(scope): summary (#N)`.
- Run `nix fmt`, `devenv test` and `nix flake check`, and fix what they report.
- Dependency change (nixpkgs base, vendored or pinned version)? Only with approval; say who approved it.
- User-facing change? Add a changelog fragment with `changelog-add`.
- Update the docs the change touches (README, `docs/`).
- Used AI tools? Name them in the description and review the diff yourself before you ask for a review.

Replace this text with a description of what the PR does and why, and how it was verified.
