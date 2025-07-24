{
  rustPlatform,
  perl,
  ...
}: let
  pname = "evercosign";
  version = "v2025.07.22";
in
  rustPlatform.buildRustPackage {
    inherit pname version;

    src = ./../src/cose/rust;

    nativeBuildInputs = [perl];

    cargoHash = "sha256-Q0TN1g1zcMvufR0tJLwL+AGdFe+zCylhRo53BPQiir8=";
  }
