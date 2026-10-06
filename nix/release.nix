{
  lib,
  stdenv,
  stdenvNoCC,
  requireFile,
  unzip,
  autoPatchelfHook,
  release,
}:

let
  source =
    release.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "HarmonyOS command-line tools are unavailable for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "harmonyos-command-line-tools-components";
  version = release.commandLineToolsVersion;

  outputs = [
    "out"
    "tools"
    "sdk"
  ];
  outputBin = "tools";
  outputDev = "tools";

  src = requireFile {
    inherit (source) name;
    sha256 = source.hash;
    message = ''
      HarmonyOS command-line tools are distributed through account-bound signed URLs.
      Download ${source.name} from Huawei Developer, then add it to the Nix store:

        nix store add --mode flat --name ${source.name} /path/to/${source.name}
    '';
  };
  sourceRoot = "command-line-tools";

  nativeBuildInputs = [ unzip ] ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenvNoCC.hostPlatform.isLinux stdenv.cc.cc.lib;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out" "$tools" "$sdk"
    cp version.txt "$out/"

    for entry in *; do
      if [ "$entry" != sdk ]; then
        cp -R "$entry" "$tools/"
      fi
    done

    cp -R sdk/. "$sdk/"

    chmod -R u+w "$tools" "$sdk"
    patchShebangs "$tools/bin" "$tools/hvigor/bin" "$tools/ohpm/bin"

    runHook postInstall
  '';

  preFixup = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    addAutoPatchelfSearchPath "$sdk/default/openharmony/toolchains"
    addAutoPatchelfSearchPath "$sdk/default/openharmony/native/llvm/lib"
    addAutoPatchelfSearchPath "$sdk/default/hms/toolchains"
    addAutoPatchelfSearchPath "$sdk/default/hms/native/BiSheng/lib"
    addAutoPatchelfSearchPath "$tools/tool/node/lib"
  '';

  autoPatchelfIgnoreMissingDeps = stdenvNoCC.hostPlatform.isLinux;
  dontFixup = stdenvNoCC.hostPlatform.isDarwin;

  meta = {
    description = "Components from the HarmonyOS command-line tools distribution";
    homepage = "https://developer.huawei.com/consumer/en/download/";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames release.sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
