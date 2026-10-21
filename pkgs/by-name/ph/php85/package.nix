# Vendored from nixpkgs' pkgs/development/interpreters/php/default.nix (the
# php85 entry at nixos-26.05), pinned ahead of the channel to PHP 8.5.12, the
# 2026-10-21 security release fixing CVE-2026-109618 and CVE-2026-109619.
#
# The build itself is nixpkgs' generic.nix, called with our version, hash and
# patches, so nothing of the PHP build is copied here. Deltas from upstream:
#   - version and hash: 8.5.12 instead of 8.5.10
#   - patches: upstream fixes applied on top of the release, empty for now
#
# To take an upstream fix without a release, append a fetchpatch of the php-src
# commit to `patches` below. To take the next release, set `version` and `hash`.
{
  callPackage,
  fetchpatch,
  stdenv,
  llvmPackages,
  pcre2,
  path,
}:

let
  version = "8.5.12";
  hash = "sha256-/7YO3EN87WO1E35JhNs3moERxQBJxxFRDYuVgnfvwag=";
  patches = [ ];

  base = callPackage (path + "/pkgs/development/interpreters/php/generic.nix") {
    stdenv = if stdenv.cc.isClang then llvmPackages.stdenv else stdenv;
    pcre2 = pcre2.override {
      withJitSealloc = false; # See https://bugs.php.net/bug.php?id=78927 and https://bugs.php.net/bug.php?id=78630
    };
    inherit version hash;
    extraPatches = patches;
    # make test loads the shared filter.so into the CLI only, but the filter OOM
    # tests start php-cgi themselves with no extension, so it reports "undefined
    # function filter_input()". The wrapper adds filter.so unless the arguments
    # already load it, because a second load is a warning that fails every test.
    packageOverrides = _: prev: {
      extensions = prev.extensions // {
        filter = prev.extensions.filter.overrideAttrs (_: {
          preCheck = ''
            cgi=$(command -v php-cgi)
            export TEST_PHP_CGI_EXECUTABLE=$PWD/php-cgi-filter
            printf '#!/bin/sh\ncase " $* " in\n  *" extension="*filter.so*) exec %s "$@" ;;\n  *) exec %s -d extension=%s "$@" ;;\nesac\n' "$cgi" "$cgi" "$PWD/modules/filter.so" > $TEST_PHP_CGI_EXECUTABLE
            chmod +x $TEST_PHP_CGI_EXECUTABLE
          '';
        });
      };
    };
  };
in
base.withExtensions (
  { all, ... }:
  with all;
  [
    bcmath
    calendar
    curl
    ctype
    dom
    exif
    fileinfo
    filter
    ftp
    gd
    gettext
    gmp
    iconv
    intl
    ldap
    mbstring
    mysqli
    mysqlnd
    openssl
    pcntl
    pdo
    pdo_mysql
    pdo_odbc
    pdo_pgsql
    pdo_sqlite
    pgsql
    posix
    readline
    session
    simplexml
    sockets
    soap
    sodium
    sysvsem
    sqlite3
    tokenizer
    xmlreader
    xmlwriter
    zip
    zlib
  ]
)
