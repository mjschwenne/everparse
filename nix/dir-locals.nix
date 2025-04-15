{
  pkgs,
  karamel,
  everparse-home,
  stdenv,
  ...
}:
stdenv.mkDerivation {
  pname = "dir-locals.el";
  version = "2025-04-08";

  dontUnpack = true;

  dirlocal =
    pkgs.writeText ".dir-locals.el"
    /*
    lisp
    */
    ''
      ((fstar-mode .
                   ((fstar-subp-prover-args .
                       ("--include"
                         "${karamel}/krmllib"
                         "--include"
                         "${everparse-home}/src/lowparse"
                         "--include"
                         "${everparse-home}/src/ASN1")
                       )))))
    '';

  installPhase = ''
    mkdir $out
    cp $dirlocal $out/dir-locals.el
  '';
}
