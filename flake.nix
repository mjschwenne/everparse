{
  description = "A Flake for Everparse packaging & development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    fstar.url = "github:FStarLang/FStar";
    karamel.url = "github:FStarLang/karamel";
    karamel.inputs.fstar.follows = "fstar";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    fstar,
    karamel,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        fstarp = fstar.packages.${system}.fstar;
        karamelp = karamel.packages.${system}.karamel.overrideAttrs {
          patches = [./nix/karamel-install.patch];
        };
        everparse = pkgs.callPackage ./nix/everparse.nix {
          fstar = fstarp;
          karamel = karamelp;
          z3 = fstar.packages.${system}.z3;
          ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;
        };
        dir-locals = pkgs.callPackage ./nix/dir-locals.nix {
          karamel = karamelp;
          everparse-home = builtins.getEnv "PWD";
        };
      in {
        packages = {
          inherit everparse;
          default = everparse;
        };
        devShells.default = with pkgs;
          mkShell {
            buildInputs =
              [
                fstarp
                karamelp
                fstar.packages.${system}.z3
                gnused
                dir-locals
              ]
              ++ (with pkgs.ocaml-ng.ocamlPackages_4_14; [
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
              export KRML_HOME=${karamelp}
              export EVERPRASE_HOME=./.
              ln -f -s ${dir-locals}/dir-locals.el .dir-locals.el
            '';
          };
      }
    );
}
