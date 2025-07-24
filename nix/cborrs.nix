{rustPlatform, ...}: let
  pname = "cborrs";
  version = "v2025.07.22";
in
  rustPlatform.buildRustPackage {
    inherit pname version;

    src = ./../src/cbor/pulse/det/rust;

    cargoHash = "sha256-1ZYJXRYaLhf0DQpTnncy07wWj6yoX24VQWaNTo/WNqM=";

    installPhase = ''
      mkdir -p $out/lib
      cp target/x86_64-unknown-linux-gnu/release/libcborrs.rlib $out/lib
    '';
  }
