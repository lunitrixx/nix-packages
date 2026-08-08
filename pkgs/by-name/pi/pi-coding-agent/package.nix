{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_latest,
  ripgrep,
}:
let
  version = "0.84.1";
  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${version}";
    hash = "sha256-lg+I4S/aAjazjhGZU567ow+rksoNiqOqjHl//TjAMes=";
  };
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version src;

  npmDepsHash = "sha256-tufyZQRPAUeDtiq0UQodbKA/Y9xUAvNT8K+NWFjkeME=";
  npmWorkspace = "packages/coding-agent";
  npmRebuildFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    mkdir -p packages/ai/src/providers/data
    shopt -s dotglob
    cp -r ${./models-data}/* packages/ai/src/providers/data/
    npx tsgo -p packages/telemetry/tsconfig.build.json
    npx tsgo -p packages/ai/tsconfig.build.json
    npx tsgo -p packages/tui/tsconfig.build.json
    npx tsgo -p packages/agent/tsconfig.build.json
    npx tsgo -p packages/protocol/tsconfig.build.json
    npx tsgo -p packages/client/tsconfig.build.json
    npm run build --workspace=packages/coding-agent
  '';

  postInstall = ''
    local nm="$out/lib/node_modules/pi-monorepo/node_modules"
    for ws in @earendil-works/pi-ai:packages/ai \
              @earendil-works/pi-agent-core:packages/agent \
              @earendil-works/pi-tui:packages/tui \
              @earendil-works/pi-telemetry:packages/telemetry \
              @earendil-works/pi-protocol:packages/protocol \
              @earendil-works/pi-client:packages/client; do
      IFS=: read -r pkg src <<< "$ws"
      rm "$nm/$pkg"
      cp -r "$src" "$nm/$pkg"
    done
    find "$nm" -type l -lname '*/packages/*' -delete
    find "$nm/.bin" -xtype l -delete
  '';

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
