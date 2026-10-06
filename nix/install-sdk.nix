{
  lib,
  nix,
  writeShellApplication,
  release,
  source,
  system,
}:

writeShellApplication {
  name = "harmonyos-sdk-install";
  runtimeInputs = [ nix ];

  text = ''
    usage() {
      cat <<'EOF'
    Usage: harmonyos-sdk-install <archive>

    Verify an official HarmonyOS command-line tools archive and import it into
    the Nix store under the canonical name expected by HarmonyOS Nixpkgs.
    EOF
    }

    case "''${1:-}" in
      -h|--help)
        usage
        exit 0
        ;;
    esac

    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi

    archive=$1
    expected_name=${lib.escapeShellArg source.name}
    expected_hash=${lib.escapeShellArg source.hash}

    if [[ ! -f "$archive" ]]; then
      echo "error: archive is not a regular file: $archive" >&2
      exit 1
    fi

    echo "Verifying $archive"
    actual_hash=$(nix hash file --type sha256 --sri "$archive")
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      echo "error: archive checksum does not match the release manifest" >&2
      echo "  expected: $expected_hash" >&2
      echo "  actual:   $actual_hash" >&2
      exit 1
    fi

    store_path=$(nix store add --mode flat --name "$expected_name" "$archive")

    cat <<EOF

    Imported HarmonyOS command-line tools successfully.
      Release:    ${release.commandLineToolsVersion}
      Host:       ${system}
      Store path: $store_path

    The SDK can now be built or entered with:
      nix build github:cavivie/harmony-nixpkgs#sdk
      nix develop github:cavivie/harmony-nixpkgs
    EOF
  '';

  meta = {
    description = "Import an official HarmonyOS SDK archive into the Nix store";
    license = lib.licenses.mit;
    platforms = [ system ];
    mainProgram = "harmonyos-sdk-install";
  };
}
