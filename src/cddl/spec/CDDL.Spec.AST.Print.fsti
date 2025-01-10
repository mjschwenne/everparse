module CDDL.Spec.AST.Print
include CDDL.Spec.AST.Elab

val typ_to_string
  (t: typ)
: Tot string

val ast0_wf_typ_result_to_string
  (t: Ghost.erased typ)
  (x: result (ast0_wf_typ t))
: Tot string
