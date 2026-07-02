# Stalwart Mail Server
#
# Vendored from nixpkgs (pkgs/by-name/st/stalwart/package.nix). Deltas from
# upstream:
#   * pinned version 0.16.11 (ahead of the nixpkgs channel at 0.15.5);
#   * added "enterprise" to buildFeatures (match the official Docker image);
#   * removed passthru.webadmin, passthru.spam-filter, passthru.tests,
#     and passthru.updateScript (not relevant for our package set).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  protobuf,
  bzip2,
  openssl,
  sqlite,
  zstd,
  stdenv,
  rocksdb,
  buildPackages,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stalwart";
  version = "0.16.11";

  src = fetchFromGitHub {
    owner = "stalwartlabs";
    repo = "stalwart";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0A8IjetGV4h4qdpm44eZb0sNQ4abulb2+VUAeYWItT0=";
  };

  cargoHash = "sha256-OpoQzNNm5JUrnk1tRZL9JUpDQnGH73Lj6SW52gSthl0=";

  depsBuildBuild = [
    pkg-config
    zstd
  ];

  nativeBuildInputs = [
    protobuf
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    bzip2
    openssl
    sqlite
    zstd
  ];

  nativeCheckInputs = [
    openssl
  ];

  buildNoDefaultFeatures = true;
  buildFeatures = [
    "sqlite"
    "postgres"
    "mysql"
    "rocks"
    "s3"
    "redis"
    "azure"
    "nats"
    "enterprise"
  ];

  env = {
    OPENSSL_NO_VENDOR = true;
    ZSTD_SYS_USE_PKG_CONFIG = true;
    ROCKSDB_INCLUDE_DIR = "${rocksdb}/include";
    ROCKSDB_LIB_DIR = "${rocksdb}/lib";
  }
  //
    lib.optionalAttrs
      (stdenv.hostPlatform.isLinux && (stdenv.hostPlatform.isAarch64 || stdenv.hostPlatform.isArmv7))
      {
        JEMALLOC_SYS_WITH_LG_PAGE = 16;
      };

  postInstall = ''
    mkdir -p $out/etc/stalwart
  '';

  doCheck = false;

  meta = {
    description = "Secure, modern, all-in-one mail and collaboration server";
    homepage = "https://github.com/stalwartlabs/stalwart";
    changelog = "https://github.com/stalwartlabs/stalwart/blob/main/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    mainProgram = "stalwart";
    maintainers = with lib.maintainers; [
      happysalada
      onny
      oddlama
      pandapip1
      norpol
    ];
  };
})
