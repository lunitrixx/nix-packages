{
  pkgs,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = [
    pkgs.git
  ];

  # https://devenv.sh/git-hooks/
  git-hooks.hooks.markdownlint.excludes = [
    # Third-party skills keep their upstream formatting so updates stay diffable (see .agents/skills/THIRD_PARTY.md).
    "^\\.agents/skills/(verification-before-completion|systematic-debugging|test-driven-development|receiving-code-review|grilling)/"
    # The PR template is a form text, not a document: it does not start with a heading.
    "^\\.forgejo/pull_request_template\\.md$"
  ];
}
