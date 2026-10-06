{
  description = "Nix-packaged HarmonyOS SDK and command-line tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      releases = import ./nix/releases.nix;
      latestVersion = "26.0.0.851";

      packageSetFor =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          release = releases.${latestVersion};
          componentOutputs = pkgs.callPackage ./nix/release.nix { inherit release; };
          componentView =
            name:
            pkgs.runCommand "harmonyos-${name}-${release.commandLineToolsVersion}" { } ''
              mkdir -p "$out/sdk/default"
              ln -s ${componentOutputs.sdk}/default/${name} "$out/sdk/default/${name}"
            '';
          sdkPackages = {
            command-line-tools = componentOutputs.tools;
            openharmony-sdk = componentView "openharmony";
            hms-sdk = componentView "hms";
          };
          mkSdk = pkgs.callPackage ./nix/mk-sdk.nix {
            inherit release;
            sdkMetadata = "${componentOutputs.sdk}/default/sdk-pkg.json";
          };
          sdk = componentsFn: mkSdk (componentsFn sdkPackages);
          fullSdk = sdk (components: builtins.attrValues components);
          versionSlug = builtins.replaceStrings [ "." ] [ "-" ] release.commandLineToolsVersion;
          installer = pkgs.callPackage ./nix/install-sdk.nix {
            inherit release system;
            source = release.sources.${system};
          };
        in
        {
          inherit
            pkgs
            release
            sdkPackages
            sdk
            fullSdk
            installer
            versionSlug
            ;
        };
    in
    {
      lib = {
        inherit releases latestVersion;
        supportedSystems = systems;
      };

      sdk = forAllSystems (system: (packageSetFor system).sdk);

      overlays.default = final: _prev: {
        harmonySdkPackages = (packageSetFor final.system).sdkPackages;
        harmonySdk = (packageSetFor final.system).sdk;
      };

      packages = forAllSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        packageSet.sdkPackages
        // {
          sdk = packageSet.fullSdk;
          "sdk-${packageSet.versionSlug}" = packageSet.fullSdk;
          "command-line-tools-${packageSet.versionSlug}" = packageSet.sdkPackages.command-line-tools;
          "openharmony-sdk-${packageSet.versionSlug}" = packageSet.sdkPackages.openharmony-sdk;
          "hms-sdk-${packageSet.versionSlug}" = packageSet.sdkPackages.hms-sdk;
          install-sdk = packageSet.installer;
          "install-sdk-${packageSet.versionSlug}" = packageSet.installer;
          default = packageSet.fullSdk;
        }
      );

      apps = forAllSystems (
        system:
        let
          packageSet = packageSetFor system;
          app = {
            type = "app";
            program = "${packageSet.installer}/bin/harmonyos-sdk-install";
            meta.description = "Import an official HarmonyOS SDK archive into the Nix store";
          };
        in
        {
          install-sdk = app;
          "install-sdk-${packageSet.versionSlug}" = app;
        }
      );

      devShells = forAllSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        {
          default = packageSet.pkgs.mkShellNoCC {
            packages = [ packageSet.fullSdk ];
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          packageSet = packageSetFor system;
        in
        {
          installer = packageSet.pkgs.runCommand "check-harmonyos-sdk-installer" { } ''
            ${packageSet.installer}/bin/harmonyos-sdk-install --help > "$out"
            touch invalid-archive.zip
            if ${packageSet.installer}/bin/harmonyos-sdk-install invalid-archive.zip > installer.log 2>&1; then
              echo "installer accepted an invalid archive" >&2
              exit 1
            fi
            grep -q "archive checksum does not match" installer.log
          '';
          sdk-layout = packageSet.pkgs.runCommand "check-harmonyos-sdk-layout" { } ''
            test -x ${packageSet.fullSdk}/bin/hvigorw
            test -x ${packageSet.fullSdk}/bin/ohpm
            test -x ${packageSet.fullSdk}/bin/hdc
            test -f ${packageSet.fullSdk}/sdk/default/sdk-pkg.json
            grep -q '"apiVersion": "${toString packageSet.release.apiVersion}"' \
              ${packageSet.fullSdk}/sdk/default/sdk-pkg.json
            test -x ${packageSet.fullSdk}/sdk/default/openharmony/native/llvm/bin/clang
            test -f ${packageSet.fullSdk}/sdk/default/hms/ets/uni-package.json
            touch "$out"
          '';
          sdk-tools = packageSet.pkgs.runCommand "check-harmonyos-sdk-tools" { } ''
            source ${packageSet.fullSdk}/nix-support/setup-hook
            hvigorw -v
            ohpm --version
            hdc --version
            aarch64-unknown-linux-ohos-clang --version
            touch "$out"
          '';
        }
      );

      formatter = forAllSystems (system: (packageSetFor system).pkgs.nixfmt-tree);
    };
}
