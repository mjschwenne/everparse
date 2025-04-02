module CDDL.Pulse.AST.Parse
include CDDL.Pulse.AST.Ancillaries
include CDDL.Pulse.AST.Base
include CDDL.Pulse.AST.Literal
include CDDL.Pulse.AST.Parse.ElemType
include CDDL.Pulse.Parse.ArrayGroup
include CDDL.Pulse.Parse.MapGroup
include CDDL.Pulse.AST.Types
include CDDL.Pulse.AST.Env
open Pulse.Lib.Pervasives
module Cbor = CBOR.Spec.API.Format
module Bundle = CDDL.Pulse.Bundle.Base // for bundle_attr

[@@sem_attr; Bundle.bundle_attr]
let ancillary_validate_env
  (#cbor_t: Type)
  (vmatch: perm -> cbor_t -> Cbor.cbor -> slprop)
  (se: sem_env)
= (t: typ { typ_bounded se.se_bound t}) -> option (impl_typ vmatch (typ_sem se t))

[@@sem_attr; Bundle.bundle_attr]
let ancillary_validate_env_is_some
  (#cbor_t: Type)
  (#vmatch: perm -> cbor_t -> Cbor.cbor -> slprop)
  (#se: sem_env)
  (env: ancillary_validate_env vmatch se)
: Tot (ancillary_validate_env_bool se.se_bound)
= fun t -> Some? (env t)

[@@sem_attr; Bundle.bundle_attr]
let ancillary_validate_env_extend
  (#cbor_t: Type)
  (#vmatch: perm -> cbor_t -> Cbor.cbor -> slprop)
  (#se: sem_env)
  (env1: ancillary_validate_env vmatch se)
  (se2: sem_env {
    sem_env_included se se2
  })
: Tot (ancillary_validate_env vmatch se2)
= fun t ->
  if typ_bounded se.se_bound t
  then begin
    (env1 t)
  end
  else None

[@@sem_attr; Bundle.bundle_attr]
let ancillary_validate_env_set
  (#cbor_t: Type)
  (#vmatch: perm -> cbor_t -> Cbor.cbor -> slprop)
  (#se: sem_env)
  (env: ancillary_validate_env vmatch se)
  (t': typ { typ_bounded se.se_bound t'})
  (i: impl_typ vmatch (typ_sem se t'))
: Tot (ancillary_validate_env vmatch se)
= fun t ->
  if t = t'
  then Some i
  else env t

module U64 = FStar.UInt64
module U8 = FStar.UInt8
module I64 = FStar.Int64
module V = CDDL.Pulse.AST.Validate
module SZ = FStar.SizeT

[@@sem_attr]
let validate_ask_for_type
  (#t #t2 #t_arr #t_map: Type0)
  (#vmatch: (perm -> t -> Cbor.cbor -> slprop))
  (#vmatch2: (perm -> t2 -> (Cbor.cbor & Cbor.cbor) -> slprop))
  (#cbor_array_iterator_match: (perm -> t_arr -> list Cbor.cbor -> slprop))
  (#cbor_map_iterator_match: (perm -> t_map -> list (Cbor.cbor & Cbor.cbor) -> slprop))
  (impl: cbor_impl vmatch vmatch2 cbor_array_iterator_match cbor_map_iterator_match)
  (#v_sem_env: sem_env)
  (env: validator_env vmatch v_sem_env { SZ.fits_u64 })
  (a: option (ask_for v_sem_env))
  (sq: squash (option_ask_for_is_type v_sem_env a))
: impl_typ vmatch (option_ask_for_get_type v_sem_env a sq)
= let Some (AskForType t t_wf guarded) = a in
  V.validate_typ impl env guarded t t_wf

[@@sem_attr; Bundle.bundle_attr]
let ancillary_validate_env_set_ask_for
  (#cbor_t: Type)
  (#vmatch: perm -> cbor_t -> Cbor.cbor -> slprop)
  (#se: sem_env)
  (env: ancillary_validate_env vmatch se)
  (a: option (ask_for se))
  (sq: squash (option_ask_for_is_type se a))
  (i: impl_typ vmatch (typ_sem se (AskForType?.t (Some?.v a))))
: Tot (ancillary_validate_env vmatch se)
= ancillary_validate_env_set env _ i

[@@sem_attr]
let validate_ask_for_array_group
  (#t #t2 #t_arr #t_map: Type0)
  (#vmatch: (perm -> t -> Cbor.cbor -> slprop))
  (#vmatch2: (perm -> t2 -> (Cbor.cbor & Cbor.cbor) -> slprop))
  (#cbor_array_iterator_match: (perm -> t_arr -> list Cbor.cbor -> slprop))
  (#cbor_map_iterator_match: (perm -> t_map -> list (Cbor.cbor & Cbor.cbor) -> slprop))
  (impl: cbor_impl vmatch vmatch2 cbor_array_iterator_match cbor_map_iterator_match)
  (#v_sem_env: sem_env)
  (env: validator_env vmatch v_sem_env { SZ.fits_u64 })
  (a: option (ask_for v_sem_env))
  (sq: squash (option_ask_for_is_array_group v_sem_env a))
: impl_array_group cbor_array_iterator_match (array_group_sem v_sem_env (AskForArrayGroup?.t (Some?.v a)))
= let Some (AskForArrayGroup t t_wf) = a in
  V.validate_array_group impl env t t_wf
