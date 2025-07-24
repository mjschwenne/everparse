{
  description = "A Flake for Everparse packaging & development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    fstar.url = "github:FStarLang/FStar";
    karamel.url = "github:FStarLang/karamel";
    karamel.inputs.fstar.follows = "fstar";
    pulse = {
      url = "github:mjschwenne/pulse";
      inputs = {
        fstar.follows = "fstar";
        karamel.follows = "karamel";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    rust-overlay,
    fstar,
    karamel,
    pulse,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        fstar-nixpkgs = import fstar.inputs.nixpkgs {inherit system;};
        fstarp = fstar.packages.${system}.fstar;
        karamelp = karamel.packages.${system}.karamel.overrideAttrs {
          patches = [./nix/karamel-install.patch];
        };
        pulsep = pulse.packages.${system}.pulse;
        everparse = pkgs.callPackage ./nix/everparse.nix {
          fstar = fstarp;
          karamel = karamelp;
          z3 = fstar.packages.${system}.z3;
          ocamlPackages = fstar-nixpkgs.ocaml-ng.ocamlPackages_4_14;
          pulse = pulsep;
        };
        rustPlatform' = pkgs.makeRustPlatform {
          cargo = pkgs.rust-bin.stable.latest.default;
          rustc = pkgs.rust-bin.stable.latest.default;
        };
        cborrs = pkgs.callPackage ./nix/cborrs.nix {rustPlatform = rustPlatform';};
        evercosign = pkgs.callPackage ./nix/evercosign.nix {rustPlatform = rustPlatform';};
        dir-locals = pkgs.callPackage ./nix/dir-locals.nix {
          karamel = karamelp;
          everparse-home = builtins.getEnv "PWD";
        };
      in {
        packages = {
          inherit everparse cborrs evercosign;
          default = everparse;
        };
        devShells.default = with pkgs;
          mkShell {
            buildInputs =
              [
                rust-bin.stable.latest.default
                fstarp
                fstar.packages.${system}.z3
                karamelp
                pulsep
                openssl
                gnused
                dir-locals
              ]
              ++ (with fstar-nixpkgs.ocaml-ng.ocamlPackages_4_14; [
                ocaml
                dune_3
                batteries
                stdint
                ppx_deriving_yojson
                zarith
                pprint
                menhir
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
                findlib
                karamelp.passthru.lib
              ]);
            dontDetectOcamlConflicts = true;
            shellHook = ''
              export FSTAR_EXE=${fstarp}/bin/fstar.exe
              export PULSE_HOME=${pulsep}
              export KRML_HOME=${karamelp}
              export EVERPRASE_HOME=./.
              ln -f -s ${dir-locals}/dir-locals.el .dir-locals.el
            '';
          };
      }
    );
}
