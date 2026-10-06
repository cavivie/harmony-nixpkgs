{
  lib,
  runCommand,
  writeText,
  lndir,
  release,
  sdkMetadata,
}:

components:

let
  componentList = lib.unique components;
  componentPaths = lib.concatMapStringsSep " " lib.escapeShellArg componentList;
  setupHook = writeText "harmonyos-sdk-setup-hook" ''
    export DEVECO_COMMANDLINE_HOME="@out@"
    export DEVECO_SDK_HOME="@out@/sdk"
    export DEVECO_NODE_HOME="@out@/tool/node"
    export NODE_HOME="@out@/tool/node"
    export HDC_HOME="@out@/sdk/default/openharmony/toolchains"
    export OHOS_NDK_HOME="@out@/sdk/default/openharmony/native"
    export PATH="@out@/bin:@out@/tool/node/bin:@out@/sdk/default/openharmony/toolchains:@out@/sdk/default/openharmony/native/llvm/bin:$PATH"
  '';
in
runCommand "harmonyos-sdk-${release.commandLineToolsVersion}"
  {
    nativeBuildInputs = [ lndir ];
    preferLocalBuild = true;
    passthru = {
      inherit release;
      components = componentList;
    };
  }
  ''
    mkdir -p "$out/bin" "$out/nix-support" "$out/sdk/default"
    ln -s ${lib.escapeShellArg sdkMetadata} "$out/sdk/default/sdk-pkg.json"
    for component in ${componentPaths}; do
      lndir -silent "$component" "$out"
    done

    if [ -x "$out/sdk/default/openharmony/toolchains/hdc" ]; then
      ln -s "$out/sdk/default/openharmony/toolchains/hdc" "$out/bin/hdc"
    fi

    substituteAll ${setupHook} "$out/nix-support/setup-hook"
  ''
