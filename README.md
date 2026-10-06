# HarmonyOS Nixpkgs

Reproducible Nix packages for the HarmonyOS SDK and command-line tools published
by Huawei Developer.

The repository treats each Huawei command-line tools release as one tested bill
of materials. OpenHarmony base components, HarmonyOS/HMS extensions, Hvigor,
ohpm, hdc, Node.js and the native toolchain always originate from the same
official distribution archive.

## Supported hosts

- Apple Silicon macOS (`aarch64-darwin`)
- x86-64 Linux (`x86_64-linux`)
- ARM64 Linux (`aarch64-linux`)

## Use as a Flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    harmony-nixpkgs.url = "github:cavivie/harmony-nixpkgs";
  };

  outputs = { nixpkgs, harmony-nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      harmonySdk = harmony-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
        command-line-tools
        openharmony-sdk
        hms-sdk
      ]);
    in {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [ harmonySdk ];
      };
    };
}
```

Huawei distributes these archives through account-bound signed URLs. Such URLs
are credentials and must not be committed to source control, Nix derivations or
CI logs. Download the archive for your host from Huawei Developer, then run the
repository-owned installer:

```bash
nix run github:cavivie/harmony-nixpkgs#install-sdk -- \
  ~/Downloads/commandline-tools-mac-arm64-26.0.0.851.zip
```

The installer selects the manifest entry for the current host, verifies its
SHA-256 and imports it under the canonical Nix store name. A version-specific
entry point is retained with every release:

```bash
nix run github:cavivie/harmony-nixpkgs#install-sdk-26-0-0-851 -- <archive>
```

The underlying operation is `nix store add --mode flat --name <name> <archive>`;
the installer provides the host selection and integrity checks around it. The
default package is then the complete SDK:

```bash
nix develop github:cavivie/harmony-nixpkgs
hvigorw -v
ohpm --version
hdc --version
```

Adding an SDK package to a development shell's `packages` activates its setup
hook and exports:

- `DEVECO_COMMANDLINE_HOME`
- `DEVECO_SDK_HOME`
- `DEVECO_NODE_HOME`
- `NODE_HOME`
- `HDC_HOME`
- `OHOS_NDK_HOME`

The relevant command-line, device-tool and native-toolchain directories are also
added to `PATH`.

## Package model

One upstream archive is downloaded, unpacked and patched once. Its physical Nix
outputs preserve the upstream dependency boundary:

- `command-line-tools`: Hvigor, ohpm, bundled Node.js and supporting tools;
- `sdk`: the OpenHarmony base SDK and HarmonyOS/HMS extensions as one payload.

The package set exposes `openharmony-sdk` and `hms-sdk` as lightweight views of
that payload, so consumers can select components without duplicating the
archive or introducing cyclic references between upstream SDK libraries.

The composed package is:

- `sdk`: the complete, composed developer environment.

Linux ELF binaries are patched for the Nix store, including NixOS hosts. SDK
contents remain read-only; selecting another SDK version belongs in the Nix
configuration rather than an imperative SDK manager.

## Release model

`main` tracks the newest verified stable HarmonyOS command-line tools BOM. A
consumer's `flake.lock` pins the exact repository revision and therefore the
complete SDK dependency graph.

Unversioned package names such as `sdk` and `command-line-tools` follow that
stable BOM. Every retained BOM is also exposed through versioned aliases:

```bash
nix build .#sdk-26-0-0-851
nix build .#command-line-tools-26-0-0-851
```

The release manifest, rather than README prose or a mutable SDK manager, is the
source of truth for tool, SDK, API and platform versions. Preview or beta
branches should only be introduced when Huawei publishes a corresponding
channel with an independently maintainable lifecycle.

## Releases and provenance

Canonical archive names, hashes and the SDK/API relationship are declared in
[`nix/releases.nix`](nix/releases.nix). Signed download URLs remain outside the
repository. CI receives its URL through an encrypted repository secret, imports
the archive into the Nix store and relies on the same manifest hash.

This repository does not redistribute the SDK archives. The MIT license covers
only the Nix expressions and repository-owned source code. Huawei's terms apply
to the downloaded HarmonyOS SDK and tools, which are marked unfree in Nix.

## Maintenance

For each new release:

1. obtain the official archive for every supported host;
2. compute its SRI SHA-256 with `nix store prefetch-file --json <url>`;
3. inspect `version.txt` and component metadata below `sdk/default`;
4. add the canonical filename and hash, without its signed URL, and update
   `latestVersion`;
5. update the corresponding CI secret and run native checks on every supported
   host.

```bash
nix flake check --all-systems --no-build
nix build .#sdk
nix develop --command hvigorw -v
```
