# CrowdSec OpenResty bouncer - the Lua remediation component that runs *inside*
# the web server. Not packaged in nixpkgs at all; upstream ships it as a
# Debian/RPM package plus an install.sh.
#
# Why this package exists: CrowdSec's AppSec component never blocks anything by
# itself. It only inspects a copy of a request that a bouncer sends it over
# loopback and returns a verdict; the bouncer is what enforces. Without this
# component OpenResty does no request inspection at all, so "CrowdSec as a WAF"
# is not true without it. nixpkgs has `crowdsec` and `crowdsec-firewall-bouncer`
# (iptables/nftables, IP remediation only) and nothing that lives in the web
# server.
#
# How the upstream `openresty-opm` dependency was resolved
# -------------------------------------------------------
# Upstream's Debian dependencies are `openresty`, `openresty-opm` and
# `gettext-base`. `opm` exists solely so that install.sh can fetch Lua rocks
# from the network at install time - a build that reaches the network is not
# reproducible and cannot work in the Nix sandbox, so it is replaced by real
# derivation inputs:
#
#   * install.sh's `check_lua_dependency` fetches exactly one rock:
#     `ledgetech/lua-resty-http=0.17.1`. That becomes `luajitPackages.lua-resty-http`
#     (0.17.2 in our nixpkgs base - a patch ahead of upstream's pin), wired into
#     the Lua search path below instead of being copied into openresty's lualib.
#   * Everything else the Lua actually requires is already in OpenResty or
#     LuaJIT: `cjson` and `ngx.ssl` (lua-resty-core) ship with openresty,
#     `bit` and `ffi` are LuaJIT builtins. Verified by grepping every `require`
#     in the release tarball: bit, bit32, cjson, ffi, ngx.ssl, resty.http and
#     the in-tree `plugins.crowdsec.*` modules.
#   * The shared Lua library `crowdsecurity/lua-cs-bouncer` (v1.0.17 for this
#     release) is *not* a submodule - upstream's Makefile git-clones it at a
#     pinned tag. We therefore fetch the published release tarball, which has it
#     already assembled, rather than cloning two repositories at build time.
#
# `gettext-base` is only used by install.sh to render the two config files from
# templates with `envsubst`. In Nix the consuming NixOS module generates the
# config, so this package ships the templates and the Lua and renders nothing.
#
# Interface for the consuming NixOS module (headfirst-msp/nix-modules)
# -------------------------------------------------------------------
# Stable paths in the store:
#
#   $out/lualib/crowdsec.lua                 entry point, `require "crowdsec"`
#   $out/lualib/plugins/crowdsec/*.lua       its `plugins.crowdsec.*` modules
#   $out/share/crowdsec-openresty-bouncer/crowdsec_openresty.conf.template
#                                            the snippet to `include` in the
#                                            OpenResty `http` block
#   $out/share/crowdsec-openresty-bouncer/crowdsec-openresty-bouncer.conf.template
#                                            the bouncer config template
#   $out/share/crowdsec-openresty-bouncer/templates/{ban,captcha}.html
#                                            default ban/captcha pages, already
#                                            referenced by the config template
#
# Both templates still carry `envsubst`-style placeholders, and *every* one of
# them has to be substituted by the consuming module - leaving any in place
# yields a bouncer that starts, logs nothing alarming, and enforces nothing.
#
# crowdsec_openresty.conf.template - upstream's file, with the Lua search path
# already rewritten to store paths (upstream's `$prefix/../lualib/...` assumes
# the Debian layout). Left open:
#
#   ${SSL_CERTS_PATH}         CA bundle for `lua_ssl_trusted_certificate`
#                             (upstream leaves this one too)
#   ${BOUNCER_CONFIG_PATH}    path to the rendered bouncer config; upstream's
#                             install.sh `sed`s the same literal
#                             /etc/crowdsec/bouncers/crowdsec-openresty-bouncer.conf
#
# crowdsec-openresty-bouncer.conf.template - upstream's config_example.conf,
# with BAN_TEMPLATE_PATH / CAPTCHA_TEMPLATE_PATH repointed from Debian's
# /var/lib/crowdsec/lua/templates to the store (install.sh does the same `sed`).
# Left open, both from upstream:
#
#   ${CROWDSEC_LAPI_URL}      API_URL, the local API to poll for decisions
#   ${API_KEY}                API_KEY, from `cscli bouncers add`
#
# The Lua search path is also exposed as `passthru.luaPackagePath`, for a module
# that would rather assemble the nginx snippet itself.
#
# AppSec is off unless the rendered bouncer config sets
# `APPSEC_URL=http://127.0.0.1:7422`. With it empty the bouncer still does IP
# remediation and inspects no request - a healthy-looking half-installation.
{
  lib,
  stdenvNoCC,
  fetchurl,
  luajitPackages,
}:

let
  # `require "crowdsec"` and `require "plugins.crowdsec.*"` resolve from our own
  # lualib; `resty.http` from nixpkgs; the trailing `;;` keeps OpenResty's
  # compiled-in default, which is where cjson and ngx.ssl come from.
  mkLuaPackagePath =
    out:
    "${out}/lualib/?.lua;"
    + "${out}/lualib/?/init.lua;"
    + "${luajitPackages.lua-resty-http}/share/lua/5.1/?.lua;;";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "crowdsec-openresty-bouncer";
  version = "1.2.2";

  # The release asset, not the git tag: upstream's git tree carries no Lua at
  # all (the Makefile clones lua-cs-bouncer into it), while the published
  # tarball is the assembled tree the .deb is built from.
  src = fetchurl {
    url = "https://github.com/crowdsecurity/cs-openresty-bouncer/releases/download/v${finalAttrs.version}/crowdsec-openresty-bouncer.tgz";
    hash = "sha256-sR9UyclGMH31ozE9ucDjkJA2MNIvsnGrYqBRoJbfQbg=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lualib $out/share/crowdsec-openresty-bouncer
    cp -r lua/lib/. $out/lualib/
    cp -r templates $out/share/crowdsec-openresty-bouncer/
    cp config/config_example.conf \
      $out/share/crowdsec-openresty-bouncer/crowdsec-openresty-bouncer.conf.template
    substituteInPlace $out/share/crowdsec-openresty-bouncer/crowdsec-openresty-bouncer.conf.template \
      --replace-fail "/var/lib/crowdsec/lua/templates" \
                     "$out/share/crowdsec-openresty-bouncer/templates"

    cp openresty/crowdsec_openresty.conf \
      $out/share/crowdsec-openresty-bouncer/crowdsec_openresty.conf.template
    substituteInPlace $out/share/crowdsec-openresty-bouncer/crowdsec_openresty.conf.template \
      --replace-fail "'\$prefix/../lualib/plugins/crowdsec/?.lua;;'" \
                     "'${mkLuaPackagePath (placeholder "out")}'" \
      --replace-fail "/etc/crowdsec/bouncers/crowdsec-openresty-bouncer.conf" \
                     "\''${BOUNCER_CONFIG_PATH}"

    runHook postInstall
  '';

  # Guards the interface documented above: the paths the consuming module
  # references have to exist, every Debian-layout path has to have been
  # rewritten to the store, and the set of placeholders left in the two
  # templates has to be exactly the documented one. The last part is the
  # important one - a placeholder the header does not mention is a value the
  # module will not substitute, and an unsubstituted API_URL or APPSEC_URL is a
  # bouncer that comes up healthy and enforces nothing.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    share=$out/share/crowdsec-openresty-bouncer
    test -f $out/lualib/crowdsec.lua
    test -f $out/lualib/plugins/crowdsec/config.lua
    test -f $share/templates/ban.html
    test -f $share/templates/captcha.html

    # The AppSec key has to survive: without it there is no request inspection.
    grep -q '^APPSEC_URL=' $share/crowdsec-openresty-bouncer.conf.template
    grep -q "^BAN_TEMPLATE_PATH=$share/templates/ban.html\$" \
      $share/crowdsec-openresty-bouncer.conf.template
    grep -q "^CAPTCHA_TEMPLATE_PATH=$share/templates/captcha.html\$" \
      $share/crowdsec-openresty-bouncer.conf.template
    grep -q "$out/lualib/?.lua" $share/crowdsec_openresty.conf.template

    for f in crowdsec_openresty.conf.template crowdsec-openresty-bouncer.conf.template; do
      if grep -qE '/var/lib/crowdsec|/etc/crowdsec|\$prefix' $share/$f; then
        echo "$f still carries a Debian-layout path" >&2
        exit 1
      fi
    done

    # Sorted, deduplicated list of every ''${...} left in the two templates.
    found=$(grep -ohE '[$][{][A-Z_]+[}]' $share/*.template | sort -u | tr '\n' ' ')
    expected='${"\${API_KEY} \${BOUNCER_CONFIG_PATH} \${CROWDSEC_LAPI_URL} \${SSL_CERTS_PATH} "}'
    if [ "$found" != "$expected" ]; then
      echo "placeholders changed upstream - header comment is now wrong" >&2
      echo "  expected: $expected" >&2
      echo "  found:    $found" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    luaPackagePath = mkLuaPackagePath finalAttrs.finalPackage.outPath;
  };

  meta = {
    description = "CrowdSec remediation component for OpenResty, with AppSec (WAF) request inspection";
    homepage = "https://github.com/crowdsecurity/cs-openresty-bouncer";
    changelog = "https://github.com/crowdsecurity/cs-openresty-bouncer/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    maintainers = [ ];
  };
})
