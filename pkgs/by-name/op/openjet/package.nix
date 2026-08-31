# OpenJet - written fresh; nixpkgs does not ship it. First Python package in
# this repository.
#
# Non-obvious decisions, in the order a reader will trip over them:
#
#   - SOURCE IS THE PyPI WHEEL, not a GitHub tag. Upstream's newest tag is
#     `v0.5.0` but the `pyproject.toml` at that tag declares
#     `version = "0.4.31"`, and there is no `v0.4.31` tag at all - the tag
#     numbering and the declared version disagree upstream, so a tag is not a
#     usable version pin. The repository tree also carries three overlapping
#     Python roots (`src/`, `open_jet/`, `openjet/`) that
#     `[tool.setuptools.packages.find]` all matches, while the wheel contains
#     only what actually ships. PyPI publishes no sdist, so building from
#     released source is not an option either. The wheel is `py3-none-any`
#     (pure Python, nothing to autoPatchelf), so the *wheel* imposes no
#     architecture restriction. `meta.platforms` is still `linux`, which is what
#     this repository builds and what upstream's classifiers list (Linux and
#     Windows). Note the cost: that admits openjet to `checks.aarch64-linux`,
#     where `faster-whisper` pulls in ctranslate2/onnxruntime/av/numpy and is
#     unlikely to be cached. `nix flake check` here omits aarch64 today, so
#     nothing pays for it yet; narrow to `[ "x86_64-linux" ]` if that changes and
#     aarch64 is not a real target.
#
#   - THIS IS THE CLI ONLY. `buildPythonApplication` sets
#     `passthru.pythonModule = false`, and the package lands at `pkgs.openjet`,
#     not in `python3Packages`, so upstream's Python SDK is NOT importable by a
#     consumer: `python3.withPackages (ps: [ pkgs.openjet ])` builds without
#     error and `import openjet` then fails. The wheel does ship the SDK shims
#     (`openjet/`, `openjet/sdk/`, `open_jet/`) and `pythonImportsCheck` checks
#     them, but only inside this package's own environment. Exposing the SDK
#     would mean a `python3Packages.openjet`, which would put a top-level `src`
#     package on shared Python paths - upstream's own naming, and a real
#     collision hazard. Not done until someone actually needs the SDK.
#
#   - OPENTELEMETRY CONSTRAINTS ARE RELAXED. Upstream requires
#     `opentelemetry-sdk>=1.40` and `opentelemetry-exporter-otlp-proto-http>=1.40`;
#     this repository's pinned nixpkgs has 1.34.0 and bumping `flake.lock` for
#     one package is not on the table. The relaxation is proved rather than
#     assumed: `src/session_logging.py` is the only module that touches the OTel
#     API (it imports the SDK's logs/metrics/trace providers and all three
#     OTLP-over-HTTP exporters at module level), so `pythonImportsCheck` imports
#     it. The build goes red if the 1.34 API cannot carry those imports. A full
#     OTLP/HTTP export round-trip against a local collector was verified by hand
#     on 2026-08-31 and succeeded.
#
#   - BOTH THE `mcp` AND THE `cloud` EXTRA ARE IN. `openjet mcp` is a documented
#     subcommand, so `mcp` is a normal runtime dependency here.
#
#     `cloud` (`keyring`, `litellm`) was left out when this package was added,
#     on the reasoning that it only drives upstream's "Slipstream" feature and
#     needs an OpenAI Codex subscription. That reasoning was wrong, and this is
#     the correction. `litellm` is the *only* runtime in openjet that accepts a
#     `base_url` for an OpenAI-compatible endpoint: `src/runtime_registry.py:73`
#     passes `base_url` into `LiteLLMClient`, and `src/airgap.py` explicitly
#     permits a loopback one. The default `llama_cpp` runtime cannot be pointed
#     anywhere - `src/runtime_registry.py:82` builds `LlamaServerClient` without
#     `host`/`port`, so its `127.0.0.1:18080` defaults stand and it *spawns its
#     own* `llama-server`; `openai_codex` does take a `base_url` but speaks
#     ChatGPT's Responses API under OAuth, which a llama-server does not
#     implement. So without `cloud`, an openjet on a host that already runs an
#     OpenAI-compatible server cannot talk to it at all - it dies in
#     `_import_litellm` (`src/litellm_client.py:158-165`) with
#     `LiteLLMUnavailableError`. Upstream documents exactly this case
#     (<https://www.openjet.dev/docs>, "Connecting OpenJet to Existing Local
#     Servers") and its very first line is `pipx install 'open-jet[cloud]'`.
#     Loopback servers get a local placeholder key automatically, so no API key
#     is required or stored, and `airgapped: true` still rejects every
#     non-loopback endpoint. Both hosts that carry openjet run such a server.
#
#     The imports stay lazy either way - `litellm` inside a function in
#     `src/litellm_client.py`, `keyring` inside three functions in
#     `src/api_auth.py` - so adding the extra changes nothing structurally; it
#     only makes those functions succeed. Upstream asks for `keyring>=25` and
#     `litellm>=1.74`; the pinned nixpkgs has 25.7.0 and 1.86.0, so unlike the
#     OpenTelemetry entry above no constraint has to be relaxed.
#
#     Cost, measured: the closure goes from 1.13 GB to 1.27 GB. Nothing
#     alarming in it - no CUDA, no browser - mostly `openai`, `aiohttp`,
#     `cryptography` (via keyring's SecretStorage backend) and their
#     dependencies. One oddity worth knowing: nixpkgs' `python3Packages.openai`
#     carries its voice helpers, so `sounddevice` and `portaudio` end up in the
#     closure of a terminal tool that never plays audio.
#
#     Cosmetic, and not worth a dependency: litellm 1.86 warns twice on import
#     that it cannot pre-load the Bedrock and SageMaker event-stream shapes
#     because `botocore` is missing. Neither AWS runtime is reachable from
#     openjet's config, and `botocore` is not in the wheel's METADATA - the
#     warnings are noise on the way to the first chat, nothing more.
#
#     `smoke-openjet-litellm` in `pkgs/smoke-tests.nix` guards this. IT MATCHES
#     ON TWO ERROR STRINGS ON PURPOSE, so a bump that changes upstream's or
#     litellm's wording will fail it: it requires the litellm connection error
#     and rejects `LiteLLM support is not installed`. A check that only imported
#     the module would pass with the extra dropped again - the import is lazy -
#     which is exactly the regression it exists to catch. If a bump reddens it,
#     re-read the wording, do not weaken the assertion.
#
#     TWO MORE LAZY IMPORTS ARE NOT DECLARED BY UPSTREAM AT ALL, and are left
#     out here too: `src/runtime_limits.py:81-84` imports `gguf` and
#     `transformers.models.qwen2.tokenization_qwen2` inside
#     `_get_local_gguf_token_counter`, under `except ImportError: return None`.
#     Neither is in the wheel's METADATA. Consequence: exact token counting for
#     local Qwen2-family GGUF models silently falls back to the estimator.
#     Both exist in the pinned nixpkgs (`python3Packages.gguf`,
#     `python3Packages.transformers`), so this can be turned on - but
#     `transformers` is a very large closure to add for one code path, and
#     adding an undeclared dependency puts this package ahead of upstream's own
#     metadata. Recorded rather than fixed; revisit if exact counts matter.
#
#   - STATE IS REDIRECTED OUT OF THE STORE (`postInstall`). Upstream writes its
#     config, its downloaded GGUF models and its lifetime token totals *next to
#     its own code*, which under Nix is the read-only store: `openjet setup`
#     would try to write `config.yaml` into `/nix/store`. Eight call sites go
#     through `openjet_install_root()` in `src/app_paths.py`, so that one
#     function is repointed at `$OPENJET_HOME`, else `$XDG_DATA_HOME/openjet`,
#     else `~/.local/share/openjet`. The three sites that bypass it are patched
#     individually: `src/config.py` (`CONFIG_PATH`), `src/app.py`
#     (`totals.json`) and `src/setup.py` (the model-discovery root).
#
#     The directory is created eagerly inside the accessor, and two failure
#     modes are guarded because `src/config.py:11`/`:38` call it at *import*
#     time, so anything escaping breaks even `openjet --version`: a failing
#     `mkdir` (read-only or absent parent, e.g. `HOME=/homeless-shelter` in the
#     build sandbox) raises `OSError`, and `Path.home()` raises `RuntimeError`
#     when there is neither `$HOME` nor a passwd entry for the uid - a container
#     started with `--user 12345`. The latter falls back to a per-uid directory
#     under `$TMPDIR`.
#
#     THE `RuntimeError` GUARD DOES NOT MAKE THAT CONTAINER CASE WORK, it only
#     stops this package's own patch from being the thing that breaks it.
#     Upstream calls `Path.home()` unguarded at module scope in
#     `src/observation/processors.py:16`
#     (`_FASTER_WHISPER_DOWNLOAD_ROOT`), which is imported on the way to
#     `src.cli`, so with no `$HOME` and no passwd entry even `openjet --version`
#     still dies there. Measured. Not patched: it is upstream's bug, unrelated
#     to the store redirect, and a second undocumented delta to re-check at
#     every bump. Set `$HOME` if you run this in such a container.
#
#     Side effect of creating it in the accessor: any invocation creates the
#     directory, including a pure `openjet --version`. It creates an empty
#     directory and nothing else - no config file is written until something
#     calls `save_config`. Making it lazy would mean patching every writer
#     individually (`save_config`, the totals writer, the provisioner), which is
#     more surface to re-verify at each bump than the empty directory is worth.
#
#     `src/setup.py`'s entry is redundant with `provisioning.MODELS_DIR`, which
#     the same `roots` list already contains - it is patched anyway so that no
#     `/nix/store` path survives in a list a user can see in `openjet setup`.
#
#     `substituteInPlace` on the *installed* files rather than a `.patch`: the
#     source here is a wheel, so there is no unpacked tree for `patch` to apply
#     to in `postPatch`.
#
#     Also removed: `load_config()`'s first candidate `Path("config.yaml")`,
#     which read the config from the current working directory. That is worse
#     than no fallback - it makes the tool's configuration depend on which
#     directory it was started in.
#
#   - A SYSTEM CONFIG LAYER IS READ UNDERNEATH THE USER'S FILE
#     (`/etc/openjet/config.yaml`, overridable with `$OPENJET_SYSTEM_CONFIG` so
#     a home-manager-only install can use it too). This exists so a host can
#     *declare* its endpoint - both hosts that carry openjet run an
#     OpenAI-compatible server on a fixed loopback address, and that address
#     belongs in their NixOS configuration, not in whatever a person typed into
#     `openjet setup`. It cannot be done any other way: after the redirect
#     above there is exactly one config path, `save_config()` writes to it, so
#     a store symlink would make saving fail and an activation script that
#     overwrites the file would eat what `openjet setup` and `/model` wrote.
#
#     WATCH THE MERGE - `load_config()` WAS FIRST-MATCH-WINS. It looped over a
#     candidate list and returned the first file that existed, so simply adding
#     a second entry would make the system file *replace* the user's whole
#     config (`setup_complete`, hardware profile, downloaded model paths,
#     telemetry consent), which is the opposite of the point. The patched
#     `load_config()` therefore merges, and the two halves of the file get
#     different rules:
#
#       - `model_profiles` merges by profile `name`, and a system entry wins a
#         name collision. Every system entry ends up in the result, so a
#         host-declared profile cannot be lost and `/model <name>` always
#         works. User-only profiles keep their place and their values.
#       - every other key comes from the system only where the user file has no
#         opinion at all (`key not in user`). So a fresh user gets the host's
#         active selection - `active_model_profile` plus the top-level keys
#         `apply_model_profile` copies out of a profile (`runtime`, `provider`,
#         `model`, `base_url`, `context_window_tokens`) - and chat works out of
#         the box, while a `/model` switch is written to the user's file and
#         survives the next rebuild.
#
#     `save_config()` is untouched and still writes `CONFIG_PATH`, the user
#     file, only - it is the single writer in the tree (`CONFIG_PATH` appears
#     nowhere else in `src/`). The system file belongs to the NixOS generation
#     and is never written. The one way to aim a write at it would be to point
#     `$OPENJET_SYSTEM_CONFIG` at the user's own path; that is guarded by
#     dropping the layer when the two resolve to the same file. An unreadable
#     or non-mapping system file is ignored rather than fatal, because
#     `load_config()` runs on every invocation.
#
#     The consequence of those two rules meeting, measured with
#     `openjet --context 4096`: the user's top-level `context_window_tokens`
#     becomes 4096 and stays there (`--status` shows 4096, and that is what
#     `create_runtime_client` reads), while `--models` still lists the profile
#     with the host's 32768, because the profile entry itself is the system's.
#     Re-selecting that profile with `/model` re-applies the host's values.
#     That is the rule working, not a leak: the host owns the profile, the user
#     owns the current selection.
#
#     Note what a save materialises: once the user saves anything, the merged
#     `model_profiles` (system entries included) land in their file. That is
#     harmless - the system entry still wins the name on the next merge, so a
#     host that changes its `base_url` still takes effect.
#
#     Two further `openjet_install_root()` users were checked and are fine
#     redirected: `src/llama_server.py` looks for a bundled
#     `llama.cpp/build/bin` and `src/skills/discovery.py` for a bundled
#     `skills/` directory. Neither exists in the wheel, so both were dead paths;
#     after the redirect they point at the writable home, which is exactly where
#     `src/provisioning.py` builds llama.cpp into. Two sites are *not* state and
#     their store path is left in place: `src/workflows/daemon.py:233` computes
#     the `sys.path` import root (see the next entry) and
#     `src/context_index.py:175` probes for a `tests/` directory next to the
#     code.
#
#   - THE WORKFLOW RUNNER NEEDS THE DEPENDENCY PATHS PASSED DOWN. Separate from
#     the state problem and just as invisible from the build:
#     `src/workflows/daemon.py:44-64` spawns the runner as
#     `sys.executable -c "import sys; sys.path.insert(0, <install root>); from
#     src.cli import main; main()"`. `buildPythonApplication` puts the
#     dependencies on `sys.path` with a `site.addsitedir()` line inside
#     `.openjet-wrapped` and never exports `PYTHONPATH`, so `sys.executable` is
#     the bare interpreter and the child sees only openjet's own
#     site-packages - it dies on `ModuleNotFoundError: No module named 'yaml'`
#     while `openjet workflow start` exits 0 and `workflow status` still reports
#     `state=idle` with a pid. Fixed by having `_runner_bootstrap()` prepend the
#     parent's own `sys.path` to the child's.
#
#     Deliberately NOT fixed with `makeWrapperArgs = [ "--prefix PYTHONPATH …" ]`,
#     which is the usual nixpkgs answer: this is a coding agent that runs
#     arbitrary shell commands on the user's behalf, and an exported PYTHONPATH
#     would leak this package's whole dependency closure into every one of them,
#     shadowing the user's own Python environment.
#
#   - `openjet --update` IS A NO-OP THAT LIES. `src/self_update.py` runs `git`
#     in its own parent directory and re-runs upstream's `install.sh`. In the
#     store there is no git repository, so `_repo_tracking_target()` returns
#     None, `available_update()` returns None, and the command prints
#     "open-jet repo is already up to date." and exits 0 - it does not error
#     out. Measured, not assumed. Updating this package means bumping it here.
#     Left unpatched: the delta would be cosmetic and would have to be
#     re-checked at every bump. But the message is misleading rather than merely
#     useless, so know about it before trusting it on a host.
#
#   - EXTERNAL BINARIES ARE NOT WRAPPED IN. The tool shells out to `git`,
#     `nvidia-smi`, `rocm-smi`, `vulkaninfo`, `llama-server`, `sudo`, `sysctl`,
#     `ps` and friends. Every one is hardware probing, a privileged action, or
#     an optional runtime the *user* provides: `nvidia-smi`/`rocm-smi` belong to
#     the host's driver, and pinning a store `llama-server` would silently pick
#     a build with the wrong acceleration. Upstream treats them all as optional.
#     Do not add them to a `makeWrapper` PATH.
#
#   - TELEMETRY IS OPT-IN, so nothing is patched. `src/app.py:693-703`
#     (`_effective_broadcast_config`) only enables the exporter when
#     `telemetry.consent == "granted"` in the config, and the default config has
#     no `telemetry` key, so broadcasting is off until a user answers the consent
#     prompt (`src/app.py:746`, shown once on first TUI start; suppressible with
#     `OPENJET_TELEMETRY_NO_PROMPT=1`). The endpoint
#     (`https://telemetry.openjet.dev`, `src/config.py:14`) can be overridden
#     with `OPENJET_TELEMETRY_ENDPOINT`. Duplicating upstream's own default in a
#     patch would only rot.
{
  lib,
  python3Packages,
  versionCheckHook,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "openjet";
  version = "0.4.31";
  format = "wheel";

  src = python3Packages.fetchPypi {
    pname = "open_jet";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-lcYO129lFIJq80zmtda1mirn28nVORkFnhPJvGsLo/U=";
  };

  # See the header: pinned nixpkgs has OpenTelemetry 1.34.0, upstream asks for
  # >=1.40. pythonImportsCheck below is what proves the relaxation holds.
  pythonRelaxDeps = [
    "opentelemetry-exporter-otlp-proto-http"
    "opentelemetry-sdk"
  ];

  dependencies = with python3Packages; [
    faster-whisper
    hf-transfer
    hf-xet
    httpx
    huggingface-hub
    opentelemetry-exporter-otlp-proto-http
    opentelemetry-sdk
    prompt-toolkit
    pyyaml
    rich
    tiktoken

    # The `mcp` extra - a normal dependency here, see the header.
    mcp

    # The `cloud` extra. litellm is the only runtime that can be pointed at an
    # already-running OpenAI-compatible server; keyring comes with it. See the
    # header.
    keyring
    litellm
  ];

  # Redirect the install root at a writable per-user path. See the header for
  # why this is substituteInPlace on the installed files and not a patch.
  postInstall = ''
    pushd $out/${python3Packages.python.sitePackages}

    substituteInPlace src/app_paths.py \
      --replace-fail 'from pathlib import Path' 'import os
    import tempfile
    from pathlib import Path


    def _openjet_state_root() -> Path:
        """Writable state root; the Nix store this code lives in is read-only."""
        override = os.environ.get("OPENJET_HOME", "").strip()
        if override:
            root = Path(override).expanduser()
        else:
            xdg = os.environ.get("XDG_DATA_HOME", "").strip()
            if xdg:
                base = Path(xdg).expanduser()
            else:
                try:
                    base = Path.home() / ".local" / "share"
                except RuntimeError:
                    # No $HOME and no passwd entry for this uid - e.g. a
                    # container started with `--user 12345`. Path.home()
                    # raises RuntimeError, not OSError, so it needs its own
                    # guard: this function runs at import time (config.py),
                    # so an escaping exception would break `openjet --version`.
                    base = Path(tempfile.gettempdir()) / f"openjet-{os.getuid()}"
            root = base / "openjet"
        try:
            root.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass
        return root' \
      --replace-fail 'return Path(__file__).resolve().parent.parent' 'return _openjet_state_root()'

    substituteInPlace src/config.py \
      --replace-fail 'CONFIG_PATH = Path(__file__).resolve().parent.parent / "config.yaml"' 'CONFIG_PATH = openjet_install_root() / "config.yaml"

    # System-level config layer, read underneath the writable user file. See
    # the header for the merge semantics; save_config() never writes here.
    OPENJET_SYSTEM_CONFIG_PATH = Path("/etc/openjet/config.yaml")


    def _openjet_system_config_path() -> Path | None:
        """Path of the system layer, or None when there is nothing to layer."""
        override = os.environ.get("OPENJET_SYSTEM_CONFIG", "").strip()
        path = Path(override).expanduser() if override else OPENJET_SYSTEM_CONFIG_PATH
        try:
            if path.resolve(strict=False) == CONFIG_PATH.resolve(strict=False):
                # Pointed at the user own file - merging it with itself would
                # only give the system half precedence over nothing.
                return None
        except OSError:
            return None
        return path


    def _openjet_read_config(path: Path | None) -> dict:
        """Read one config file; unreadable or non-mapping YAML is no layer."""
        if path is None:
            return {}
        try:
            if not path.exists():
                return {}
            raw = yaml.safe_load(path.read_text()) or {}
        except (OSError, yaml.YAMLError):
            return {}
        return dict(raw) if isinstance(raw, dict) else {}


    def _openjet_merge_model_profiles(system: object, user: object) -> list:
        """Merge by profile name; a system entry wins a name collision.

        A host-declared profile must be impossible to lose, so every system
        entry ends up in the result - substituted in place where the user has
        a profile of the same name, appended otherwise. User-only profiles
        keep their order and their values.
        """
        by_name: dict = {}
        for item in system if isinstance(system, list) else []:
            if isinstance(item, dict):
                name = str(item.get("name") or "").strip().lower()
                if name:
                    by_name[name] = item
        merged: list = []
        seen: set = set()
        for item in user if isinstance(user, list) else []:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or "").strip().lower()
            merged.append(by_name.get(name, item) if name else item)
            if name:
                seen.add(name)
        for name, item in by_name.items():
            if name not in seen:
                merged.append(item)
        return merged


    def _openjet_merge_system_config(system: dict, user: dict) -> dict:
        """Layer the system config underneath the user config."""
        merged = dict(user)
        for key, value in system.items():
            if key == "model_profiles":
                continue
            # The system supplies a value only where the user file has no
            # opinion - so a fresh user gets the host choice, and a /model
            # switch survives the next rebuild.
            if key not in merged:
                merged[key] = value
        profiles = _openjet_merge_model_profiles(
            system.get("model_profiles"), user.get("model_profiles")
        )
        if profiles:
            merged["model_profiles"] = profiles
        return merged' \
      --replace-fail '    for candidate in [Path("config.yaml"), CONFIG_PATH]:
            if candidate.exists():
                raw = yaml.safe_load(candidate.read_text()) or {}
                return normalize_config(raw)
        return {}' '    system_path = _openjet_system_config_path()
        system_exists = system_path is not None and system_path.exists()
        if not CONFIG_PATH.exists() and not system_exists:
            return {}
        return normalize_config(
            _openjet_merge_system_config(
                _openjet_read_config(system_path), _openjet_read_config(CONFIG_PATH)
            )
        )'

    substituteInPlace src/app.py \
      --replace-fail 'return Path(__file__).resolve().parent.parent / "totals.json"' 'from .app_paths import openjet_install_root

            return openjet_install_root() / "totals.json"'

    substituteInPlace src/setup.py \
      --replace-fail 'Path(__file__).resolve().parent.parent / "models",' 'OPENJET_HOME / "models",'

    substituteInPlace src/workflows/daemon.py \
      --replace-fail 'f"sys.path.insert(0, {str(package_root)!r}); "' 'f"sys.path[:0] = {[p for p in sys.path if p]!r}; "
            f"sys.path.insert(0, {str(package_root)!r}); "'

    popd
  '';

  # src.session_logging is the module that imports the OpenTelemetry SDK and the
  # OTLP-over-HTTP exporters at module level, so importing it here is what
  # proves the relaxed constraint against 1.34.0. src.cli is the entry point and
  # pulls in the rest of the tree; openjet/open_jet are the SDK shim packages.
  #
  # src.litellm_client is the module behind the `cloud` extra, but importing it
  # proves little on its own: it imports litellm inside `_import_litellm`
  # (line 160), not at module level. So litellm and keyring are imported
  # directly as well - that is what makes the build go red if the extra is
  # dropped again or its dependencies stop importing.
  pythonImportsCheck = [
    "src.cli"
    "src.session_logging"
    "src.app_telemetry"
    "src.observation.bridge"
    "src.litellm_client"
    "litellm"
    "keyring"
    "openjet"
    "open_jet"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Local AI coding agent: terminal UI and Python SDK for self-hosted OpenAI-compatible runtimes";
    homepage = "https://openjet.dev/";
    changelog = "https://github.com/L-Forster/open-jet/releases";
    license = lib.licenses.agpl3Only;
    mainProgram = "openjet";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
