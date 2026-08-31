# Smoke tests: actually execute the CLI packages, not just build them.
#
# Each test is a trivial runCommand (preferLocalBuild) that runs the binary
# with a version command and greps the expected output. A broken binary
# (wrong interpreter, truncated copy, wrong payload) fails the build of the
# test derivation, so `nix flake check` goes red.
#
# A test is only registered where its package is actually available
# (lib.meta.availableOn) - the same filter the flake's `packages` output
# applies, so a x86_64-only binary is never executed on aarch64.
#
# Packages without a meaningful headless entry point are deliberately absent
# here - they are still built by the `packages` attrset that `checks`
# includes:
#   - netbird-ui, fontbase, ray, vital        (GUI apps, no display in a build)
#   - toneboosters-archive                    (VST/VST3 plugins)
#   - netbird-relay, netbird-upload           (no --version flag; need a
#                                              configured environment to run)
#   - zabbix74-web                            (PHP frontend, needs a web server)
{
  pkgs,
  lib,
  system,
}:
let
  # runTest <name> <bin> <args> <grep-regex>
  # Runs the binary, captures the output, and requires the regex to match -
  # exit status 0 alone is not enough, because a binary that ignores its
  # arguments and prints its help also exits 0.
  runTest =
    name: bin: args: assertion:
    pkgs.runCommand "smoke-${name}"
      {
        preferLocalBuild = true;
      }
      ''
        mkdir -p $out
        ${bin} ${args} > $out/log 2>&1
        grep -E -- "${assertion}" $out/log
        echo "smoke-${name}: ${name} ran and matched ${assertion}"
      '';

  # <name> -> { package = <the drv it tests>; test = <the smoke drv> }
  # `package` drives the availability filter, `test` is what gets built.
  tests = {
    omp = {
      package = pkgs.omp;
      test = runTest "omp" "${pkgs.omp}/bin/omp" "--version" "^omp/[0-9]+\\.[0-9]+\\.[0-9]+";
    };
    pi-coding-agent = {
      package = pkgs.pi-coding-agent;
      test = runTest "pi" "${pkgs.pi-coding-agent}/bin/pi" "--version" "^[0-9]+\\.[0-9]+\\.[0-9]+";
    };
    wails3 = {
      package = pkgs.wails3;
      test = runTest "wails3" "${pkgs.wails3}/bin/wails3" "version" "v[0-9]+\\.[0-9]+\\.[0-9]+";
    };
    herdr = {
      package = pkgs.herdr;
      test = runTest "herdr" "${pkgs.herdr}/bin/herdr" "--version" "^herdr [0-9]+\\.[0-9]+\\.[0-9]+";
    };
    # `--version` returns before load_config(), so it reads no config file and
    # touches no network - it prints "open-jet <version>" from
    # importlib.metadata. It does create an empty state directory, because
    # src/config.py resolves the (redirected) install root at import time; that
    # is fine in the build sandbox, where HOME is unwritable and the mkdir is
    # swallowed. Anchored and version-pinned so a wrong version fails.
    openjet = {
      package = pkgs.openjet;
      test =
        runTest "openjet" "${pkgs.openjet}/bin/openjet" "--version"
          "^open-jet ${lib.escapeRegex pkgs.openjet.version}$";
    };
    # The `cloud` extra is only useful if the litellm runtime actually runs, and
    # nothing about the closure proves that: litellm is imported lazily inside
    # `LiteLLMClient._import_litellm`, so a missing dependency surfaces as
    # `LiteLLMUnavailableError` at chat time and nowhere earlier. This test
    # writes upstream's documented `model_profiles` entry for an
    # already-running OpenAI-compatible server into a scratch state directory,
    # points it at a loopback port nothing listens on, and requires the failure
    # to be a *connection* error - which is only reachable once litellm is
    # importable. `airgapped: true` keeps the run offline (it also blocks
    # litellm's own model-cost-map fetch, which warns and falls back to its
    # bundled copy), so this works in the build sandbox.
    openjet-litellm = {
      package = pkgs.openjet;
      test =
        pkgs.runCommand "smoke-openjet-litellm"
          {
            preferLocalBuild = true;
          }
          ''
            mkdir -p $out
            export HOME=$TMPDIR/home
            export OPENJET_HOME=$HOME/state
            mkdir -p "$OPENJET_HOME"
            cat > "$OPENJET_HOME/config.yaml" <<'EOF'
            active_model_profile: llama-server
            runtime: litellm
            provider: openai-compatible
            model: openai/local
            base_url: http://127.0.0.1:18099/v1
            context_window_tokens: 32768
            airgapped: true
            model_profiles:
              - name: llama-server
                runtime: litellm
                provider: openai-compatible
                model: openai/local
                base_url: http://127.0.0.1:18099/v1
                context_window_tokens: 32768
            EOF

            ${pkgs.openjet}/bin/openjet --status > $out/status 2>&1
            grep -E -- "^Runtime: litellm$" $out/status
            grep -E -- "^Air-gapped: true$" $out/status

            ${pkgs.openjet}/bin/openjet chat "say hi" > $out/log 2>&1 || true
            if grep -q -- "LiteLLM support is not installed" $out/log; then
              echo "smoke-openjet-litellm: the cloud extra is missing" >&2
              exit 1
            fi
            grep -E -- "LiteLLM provider .openai-compatible. connection failed" $out/log
            echo "smoke-openjet-litellm: litellm runtime reached the configured base_url"
          '';
    };
    netbird = {
      package = pkgs.netbird;
      test = runTest "netbird" "${pkgs.netbird}/bin/netbird" "version" "^[0-9]+\\.[0-9]+\\.[0-9]+";
    };
    netbird-management = {
      package = pkgs.netbird-management;
      test =
        runTest "netbird-management" "${pkgs.netbird-management}/bin/netbird-mgmt" "--version"
          "netbird-mgmt version [0-9]+\\.[0-9]+\\.[0-9]+";
    };
    netbird-signal = {
      package = pkgs.netbird-signal;
      test =
        runTest "netbird-signal" "${pkgs.netbird-signal}/bin/netbird-signal" "--version"
          "netbird-signal version [0-9]+\\.[0-9]+\\.[0-9]+";
    };
    netbird-proxy = {
      package = pkgs.netbird-proxy;
      test = runTest "netbird-proxy" "${pkgs.netbird-proxy}/bin/netbird-proxy" "--version" "Version: ";
    };
    # The dashboard is a static web frontend (no binary) - check the artifact.
    netbird-dashboard = {
      package = pkgs.netbird-dashboard;
      test =
        pkgs.runCommand "smoke-netbird-dashboard"
          {
            preferLocalBuild = true;
          }
          ''
            mkdir -p $out
            test -f ${pkgs.netbird-dashboard}/index.html
            echo "smoke-netbird-dashboard: index.html present"
          '';
    };
    # The overlay exposes zabbix74 as an attrset (pkgs.zabbix74.server); the
    # flat zabbix74-server names only exist in the flake's packages output.
    zabbix74-agent = {
      package = pkgs.zabbix74.agent;
      test = runTest "zabbix74-agent" "${pkgs.zabbix74.agent}/bin/zabbix_agentd" "-V" "Zabbix";
    };
    zabbix74-agent2 = {
      package = pkgs.zabbix74.agent2;
      test = runTest "zabbix74-agent2" "${pkgs.zabbix74.agent2}/bin/zabbix_agent2" "-V" "Zabbix";
    };
    zabbix74-server = {
      package = pkgs.zabbix74.server;
      test = runTest "zabbix74-server" "${pkgs.zabbix74.server}/bin/zabbix_server" "-V" "Zabbix";
    };
    zabbix74-server-mysql = {
      package = pkgs.zabbix74.server-mysql;
      test =
        runTest "zabbix74-server-mysql" "${pkgs.zabbix74.server-mysql}/bin/zabbix_server" "-V"
          "Zabbix";
    };
    zabbix74-server-pgsql = {
      package = pkgs.zabbix74.server-pgsql;
      test =
        runTest "zabbix74-server-pgsql" "${pkgs.zabbix74.server-pgsql}/bin/zabbix_server" "-V"
          "Zabbix";
    };
    zabbix74-proxy-sqlite = {
      package = pkgs.zabbix74.proxy-sqlite;
      test =
        runTest "zabbix74-proxy-sqlite" "${pkgs.zabbix74.proxy-sqlite}/bin/zabbix_proxy" "-V"
          "Zabbix";
    };
    zabbix74-proxy-mysql = {
      package = pkgs.zabbix74.proxy-mysql;
      test = runTest "zabbix74-proxy-mysql" "${pkgs.zabbix74.proxy-mysql}/bin/zabbix_proxy" "-V" "Zabbix";
    };
    zabbix74-proxy-pgsql = {
      package = pkgs.zabbix74.proxy-pgsql;
      test = runTest "zabbix74-proxy-pgsql" "${pkgs.zabbix74.proxy-pgsql}/bin/zabbix_proxy" "-V" "Zabbix";
    };
    claude-code = {
      package = pkgs.claude-code;
      test =
        runTest "claude-code" "${pkgs.claude-code}/bin/claude" "--version"
          "^[0-9]+\\.[0-9]+\\.[0-9]+";
    };
    # Tinkerwell is an Electron app: it refuses to start without an X
    # server and it does not survive the strict build sandbox, so this test
    # runs it on a virtual display with __noChroot. Nix 2.34 honours
    # __noChroot only when the global sandbox mode is 'relaxed', so build
    # this one check with:
    #   nix build .#checks.x86_64-linux.smoke-tinkerwell --option sandbox relaxed
    # (with the default sandbox = true it is refused; the package build
    # itself is still covered by the regular checks)
    #
    # The display comes from xvfb-run rather than a hand-started `Xvfb :99`
    # plus `sleep 2`: xvfb-run waits until the server actually accepts
    # connections and `-a` picks a free display number, so neither a slow
    # start under build load nor a display collision (__noChroot shares
    # /tmp/.X11-unix with the host) can decide the result. It also reaps the
    # server itself and passes the command's exit status through, so a
    # crashing tinkerwell still fails the check.
    tinkerwell = {
      package = pkgs.tinkerwell;
      test =
        pkgs.runCommand "smoke-tinkerwell"
          {
            preferLocalBuild = true;
            __noChroot = true;
            nativeBuildInputs = [ pkgs.xvfb-run ];
          }
          ''
            mkdir -p $out
            export HOME=$TMPDIR/home
            mkdir -p $HOME
            xvfb-run -a --server-args="-screen 0 1024x768x24" \
              ${pkgs.tinkerwell}/bin/tinkerwell --version > $out/log 2>&1
            grep -E -- "tinkerwell" $out/log
            echo "smoke-tinkerwell: tinkerwell ran and matched tinkerwell"
          '';
    };
  };
in
lib.listToAttrs (
  lib.map (name: lib.nameValuePair "smoke-${name}" tests.${name}.test) (
    lib.filter (name: lib.meta.availableOn pkgs.stdenv.hostPlatform tests.${name}.package) (
      lib.attrNames tests
    )
  )
)
