# Tech debt tracker

Known problems that are not fixed yet. One entry per item.

| Area | Problem | Impact | Owner | Status |
| --- | --- | --- | --- | --- |
| CI | No CI pipeline: `.github/` holds only issue forms and the PR template. `nix flake check` and the history secret scan run only on a developer machine. | A broken package or a leaked secret is noticed only when someone runs the checks. | lunitrixx | open |
| Checks | `nix flake check` on x86_64-linux omits `aarch64-linux` ("The check omitted these incompatible systems"); nothing builds the aarch64 packages before a consumer does. | An aarch64-only break reaches consumers. | lunitrixx | open |
| serum2 | Manual-download packages (`requiresManualDownload`) are left out of `checks`, so `serum2` is only built on a machine that has the archive in its store. | A break in `serum2` is not caught by `nix flake check`. | lunitrixx | accepted |
| win-iso-remaster | `--no-bios-prompt` removes `boot/bootfix.bin`; not verified on hardware. | The BIOS boot path of a remastered ISO may not work. | lunitrixx | open |
