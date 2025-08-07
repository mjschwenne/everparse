{
  fstar,
  karamel,
  pulse,
  gnused,
  ocamlPackages,
  removeReferencesTo,
  stdenv,
  symlinks,
  openssl,
  rust-bin,
  which,
  z3,
}: let
  pname = "everparse";
  version = "v2025.07.22";
  propagatedBuildInputs = with ocamlPackages; [
    batteries
    stdint
    ppx_deriving_yojson
    zarith
    pprint
    menhirLib
    sedlex
    process
    fix
    wasm
    ctypes
    visitors
    uucp
    hex
    sexplib
    re
    sha
    mtime
    memtrace
    karamel.passthru.lib
  ];
  nativeBuildInputs =
    [
      fstar
      rust-bin.stable.latest.default
      removeReferencesTo
      symlinks
      which
      z3
      gnused
      openssl
    ]
    ++ (with ocamlPackages; [ocaml dune_3 findlib menhir]);
in
  stdenv.mkDerivation {
    inherit version pname propagatedBuildInputs nativeBuildInputs;

    src = ./..;
    outputs = ["out"];

    KRML_HOME = karamel;
    PULSE_HOME = pulse;
    enableParallelBuilding = true;

    configurePhase = ''
      export FSTAR_EXE=${fstar}/bin/fstar.exe
      patchShebangs --build ./src/3d/version.sh
    '';

    patches = [./no-cargo-build.patch];

    installPhase = ''
      mkdir -p $out/bin
      cp -r ./bin/* $out/bin
      mkdir -p $out/lib
      mkdir -p $out/lib/lowparse
      cp -r ./src/lowparse/* $out/lib/lowparse
      mkdir -p $out/lib/3d/prelude
      cp ./src/3d/EverParseEndianness.h $out/lib/3d
      cp -r ./src/3d/prelude $out/lib/3d/prelude
      mkdir -p $out/lib/asn1
      cp -r ./src/ASN1/*.fst $out/lib/asn1
      cp -r ./src/ASN1/*.fst.checked $out/lib/asn1
      mkdir -p $out/evercddl
      cp -r ./lib/evercddl $out/evercddl
      mkdir -p $out/cddl
      cp -r ./src/cddl/pulse $out/cddl
      cp -r ./src/cddl/spec $out/cddl
      mkdir -p $out/src/cddl/tool
      cp -r ./src/cddl/tool/extraction-c $out/src/cddl/tool/extraction-c
      cp -r ./src/cddl/tool/extraction-rust $out/src/cddl/tool/extraction-rust
      mkdir -p $out/cbor
      cp -r ./src/cbor/pulse $out/cbor
      cp -r ./src/cbor/spec $out/cbor
    '';
    postInstall = ''
      # OCaml leaves its full store path in produced binaries
      # Thus we remove every reference to it
      for binary in $out/bin/*
      do
        remove-references-to -t '${ocamlPackages.ocaml}' $binary
      done

      cp -r ./. $home
    '';

    dontFixup = true;
    dontDetectOcamlConflicts = true;
  }
