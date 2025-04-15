{
  description = "A Flake for Everparse packaging & development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/a999c1cc0c9eb2095729d5aa03e0d8f7ed256780";
    fstar.url = "github:FStarLang/FStar/8080c2c10e2a15fdacea6df31f0921850294cd37";
    karamel.url = "github:FStarLang/karamel/86f99f08afa04ca792f9c4f64f24db4c0fdbc46c";
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
        dir-locals = pkgs.callPackage ./nix/dir-locals.nix {
          karamel = karamelp;
        };
      in {
        packages.default = pkgs.callPackage ./everparse.nix {
          fstar = fstarp;
          karamel = karamelp;
        };
        devShells.default = with pkgs;
          mkShell {
            buildInputs =
              [
                fstarp
                karamelp
                z3_4_8_5
                ocaml
                dune_3
                gnused
                dir-locals
              ]
              ++ (with pkgs.ocamlPackages; [
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

            shellHook = ''
              export KRML_HOME=${karamelp}
              export EVERPRASE_HOME=./.
              ln -f -s ${dir-locals}/dir-locals.el .dir-locals.el
            '';
          };
      }
    );
}
