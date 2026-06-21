{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_latest,
  ripgrep,
}:
buildNpmPackage {
  pname = "pi-coding-agent";
  version = "0.79.9";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v0.79.9";
    hash = "sha256-+h1D51JM4F2iHCzTA57A5/uAzHQBKSlz/7x3/PtQhec=";
  };

  npmDepsHash = "sha256-uej0uXVbihmxpuvviCK/5JFSEqDamIW5ETOL/ZKW45g=";
  npmWorkspace = "packages/coding-agent";
  npmRebuildFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    runHook preBuild
    npx tsgo -p packages/ai/tsconfig.build.json
    npx tsgo -p packages/tui/tsconfig.build.json
    npx tsgo -p packages/agent/tsconfig.build.json
    npm run build --workspace=packages/coding-agent
    runHook postBuild
  '';

  postInstall = ''
    local nm="$out/lib/node_modules/pi-monorepo/node_modules"
    for ws in @earendil-works/pi-ai:packages/ai \
              @earendil-works/pi-agent-core:packages/agent \
              @earendil-works/pi-tui:packages/tui; do
      IFS=: read -r pkg src <<< "$ws"
      rm "$nm/$pkg"
      cp -r "$src" "$nm/$pkg"
    done
    find "$nm" -type l -lname '*/packages/*' -delete
    find "$nm/.bin" -xtype l -delete
  '';

  # Resolve the user's home at runtime; a plain derivation has no HM `config`.
  postFixup = ''
    wrapProgram $out/bin/pi \
      --run 'export NPM_CONFIG_PREFIX="$HOME/.pi/npm"' \
      --run 'export PATH="$HOME/.pi/npm/bin:$PATH"' \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs_latest
          ripgrep
        ]
      }
  '';

  nativeBuildInputs = [ makeWrapper ];

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
