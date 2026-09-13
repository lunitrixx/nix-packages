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
  inputs,
  lib,
  ...
}:
let
  byNameDir = ../../../pkgs/by-name;
  overlay = import ../../../pkgs/by-name-overlay.nix byNameDir;
in
{
  perSystem =
    { system, ... }:
    let
      pkgs =
        (import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }).extend
          overlay;

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
        pi-coding-agent = {
          package = pkgs.pi-coding-agent;
          test = runTest "pi" "${pkgs.pi-coding-agent}/bin/pi" "--version" "^[0-9]+\\.[0-9]+\\.[0-9]+";
        };
        wails3 = {
          package = pkgs.wails3;
          test = runTest "wails3" "${pkgs.wails3}/bin/wails3" "version" "v[0-9]+\\.[0-9]+\\.[0-9]+";
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
        # The bouncer is a Lua module for OpenResty, not a binary - so "run it"
        # means: render the snippet this package ships exactly as the consuming
        # NixOS module will, start a real openresty on it and serve a request.
        #
        # init_by_lua does `require "crowdsec"`, which pulls in every plugin plus
        # `resty.http`. That is what proves the opm dependency was resolved for
        # real: a missing rock or a lua_package_path still pointing at the Debian
        # layout fails here instead of at the edge in production. `openresty -t`
        # is not enough - it parses the config but logs init_by_lua output to the
        # old cycle's error log, so nothing is left to assert on.
        #
        # Both templates the package ships are rendered here, the config one
        # included: config.lua rejects any key it does not know, so loading the
        # real template is what catches an upstream key the package did not keep
        # up with. The LAPI it is pointed at does not exist (nothing listens in
        # a build sandbox), which is fine - in live mode the bouncer only calls
        # out per request, and a refused call fails open, so the request still
        # reaches the origin. Nothing here needs the network.
        crowdsec-openresty-bouncer = {
          package = pkgs.crowdsec-openresty-bouncer;
          test =
            pkgs.runCommand "smoke-crowdsec-openresty-bouncer"
              {
                preferLocalBuild = true;
                nativeBuildInputs = [
                  pkgs.openresty
                  pkgs.curl
                ];
              }
              ''
                mkdir -p $out $PWD/prefix/conf $PWD/prefix/logs
                share=${pkgs.crowdsec-openresty-bouncer}/share/crowdsec-openresty-bouncer

                substitute $share/crowdsec-openresty-bouncer.conf.template prefix/conf/bouncer.conf \
                  --replace-fail '${"\${CROWDSEC_LAPI_URL}"}' http://127.0.0.1:18098 \
                  --replace-fail '${"\${API_KEY}"}' smoke-test-key

                substitute $share/crowdsec_openresty.conf.template prefix/conf/crowdsec.conf \
                  --replace-fail '${"\${SSL_CERTS_PATH}"}' ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
                  --replace-fail '${"\${BOUNCER_CONFIG_PATH}"}' $PWD/prefix/conf/bouncer.conf

                cat > prefix/conf/nginx.conf <<EOF
                pid $PWD/prefix/logs/nginx.pid;
                error_log $PWD/prefix/logs/error.log info;
                events { worker_connections 16; }
                http {
                  access_log $PWD/prefix/logs/access.log;
                  include $PWD/prefix/conf/crowdsec.conf;
                  server {
                    listen 127.0.0.1:18099;
                    location / { content_by_lua_block { ngx.say("origin ok") } }
                  }
                }
                EOF

                openresty -p $PWD/prefix -c $PWD/prefix/conf/nginx.conf
                for _ in $(seq 1 50); do
                  [ -s prefix/logs/nginx.pid ] && break
                  sleep 0.2
                done

                curl -sS --fail http://127.0.0.1:18099/ > $out/body
                openresty -p $PWD/prefix -c $PWD/prefix/conf/nginx.conf -s stop

                cp prefix/logs/error.log $out/log
                grep -q "origin ok" $out/body
                grep -E -- "\[Crowdsec\] Initialisation done" $out/log
                # config.lua logs this for any key it does not recognise.
                if grep -q "unsupported configuration" $out/log; then
                  echo "the shipped config template has a key this bouncer rejects" >&2
                  exit 1
                fi
                echo "smoke-crowdsec-openresty-bouncer: openresty loaded the Lua module and served a request"
              '';
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
    {
      checks = lib.listToAttrs (
        lib.map (name: lib.nameValuePair "smoke-${name}" tests.${name}.test) (
          lib.filter (name: lib.meta.availableOn pkgs.stdenv.hostPlatform tests.${name}.package) (
            lib.attrNames tests
          )
        )
      );
    };
}
