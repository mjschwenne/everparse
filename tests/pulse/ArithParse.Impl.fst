module ArithParse.Impl
#lang-pulse
include ArithParse.Spec
open LowParse.Spec.Base
open LowParse.Pulse.Base
open LowParse.Pulse.Combinators
open LowParse.Pulse.Int
open LowParse.Pulse.VCList
open LowParse.Pulse.Recursive
open Pulse.Lib.Pervasives
module S = Pulse.Lib.Slice

module U64 = FStar.UInt64
module U8 = FStar.UInt8
module PM = Pulse.Lib.SeqMatch

(* Validation *)

inline_for_extraction noextract [@@noextract_to "krml"]
let validate_header_rhs (lhs: U8.t) : validator (parse_header_rhs lhs) =
  ifthenelse_validator
    (parse_header_rhs lhs)
    (lhs = 255uy)
    (fun _ -> validate_weaken parse_header_rhs_kind (validate_synth (validate_u64) (HValue #lhs ())))
    (fun _ -> validate_weaken parse_header_rhs_kind (validate_synth validate_empty (HUnit #lhs ())))

inline_for_extraction noextract [@@noextract_to "krml"]
let validate_header : validator parse_header =
  validate_dtuple2 validate_u8 (leaf_reader_of_reader read_u8) validate_header_rhs

inline_for_extraction noextract [@@noextract_to "krml"]
let jump_header_rhs (lhs: U8.t) : jumper (parse_header_rhs lhs) =
  ifthenelse_jumper
    (parse_header_rhs lhs)
    (lhs = 255uy)
    (fun _ -> jump_ext (jump_synth jump_u64 (HValue #lhs ())) (parse_header_rhs lhs))
    (fun _ -> jump_ext (jump_synth jump_empty (HUnit #lhs ())) (parse_header_rhs lhs))

inline_for_extraction noextract [@@noextract_to "krml"]
let jump_header : jumper parse_header =
  jump_dtuple2 jump_u8 (leaf_reader_of_reader read_u8) jump_header_rhs

let write_header : l2r_leaf_writer serialize_header =
  l2r_leaf_write_dtuple2
    (l2r_leaf_write_u8 ())
    ()
    (fun lhs ->
      l2r_leaf_writer_ifthenelse
        (serialize_header_rhs lhs)
        (lhs = 255uy)
        (fun _ -> l2r_leaf_writer_ext (l2r_leaf_write_synth' (l2r_leaf_write_u64 ()) (HValue ()) (HValue?.v)) (serialize_header_rhs lhs))
        (fun _ -> l2r_leaf_writer_ext (l2r_leaf_write_synth' (l2r_leaf_write_empty) (HUnit ()) (HUnit?.v)) (serialize_header_rhs lhs))
    )

module SZ = FStar.SizeT

#push-options "--ifuel 4"

module Trade = Pulse.Lib.Trade.Util

inline_for_extraction noextract [@@noextract_to "krml"]
fn impl_validate_count_payload () : validate_recursive_step_count #_ serialize_expr_param =
  (#va: _)
  (#pm: _)
  (a: _)
  (bound: _)
  (#rem: _)
  (prem: _)
{
  parse_header_eq ();
  pts_to_serialized_ext_trade (serializer_of_tot_serializer tot_serialize_header) serialize_header a;
  let a1 = dtuple2_dfst _ jump_u8 _ a;
  Trade.trans _ _ (pts_to_serialized (serializer_of_tot_serializer tot_serialize_header) a #pm va);
  let kd = leaf_reader_of_reader read_u8 a1;
  Trade.elim _ _;
  if (kd = 255uy) {
    prem := 0sz;
    false
  }
  else if (kd = 254uy) {
    prem := 2sz;
    false
  } else {
    let len16 = FStar.Int.Cast.uint8_to_uint16 kd;
    prem := SZ.uint16_to_sizet len16;
    false
  }
}

let validate_expr : validator tot_parse_expr =
  [@@inline_let] let _ = parse_header_eq () in
  validate_recursive serialize_expr_param validate_header (impl_validate_count_payload ())

inline_for_extraction noextract [@@noextract_to "krml"]
fn impl_jump_count_payload () : jump_recursive_step_count #_ serialize_expr_param =
  (#va: _)
  (#pm: _)
  (a: _)
  (bound: _)
{
  parse_header_eq ();
  pts_to_serialized_ext_trade (serializer_of_tot_serializer tot_serialize_header) serialize_header a;
  let a1 = dtuple2_dfst _ jump_u8 _ a;
  Trade.trans _ _ (pts_to_serialized (serializer_of_tot_serializer tot_serialize_header) a #pm va);
  let kd = leaf_reader_of_reader read_u8 a1;
  Trade.elim _ _;
  if (kd = 255uy) {
    0sz;
  }
  else if (kd = 254uy) {
    2sz;
  } else {
    let len16 = FStar.Int.Cast.uint8_to_uint16 kd;
    SZ.uint16_to_sizet len16;
  }
}

let jump_expr : jumper tot_parse_expr =
  [@@inline_let] let _ = parse_header_eq () in
  jump_recursive serialize_expr_param jump_header (impl_jump_count_payload ())

(* Low-level data structure *)

noeq
type expr_base_t =
| EUPlus: (count: U8.t) -> (payload: with_perm (S.slice U8.t)) -> expr_base_t
| EUMinus: (fst: with_perm (S.slice U8.t)) -> (snd: with_perm (S.slice U8.t)) -> expr_base_t
| EValue of U64.t

noeq
type expr_t =
| EBase of expr_base_t // or value
| EPlus of with_perm (S.slice expr_t)
| EMinus: (fst: with_perm (ref expr_t)) -> (snd: with_perm (ref expr_t)) -> expr_t

(* Separation-logic predicate *)

[@@pulse_unfold]
let rel_base_EUPlus
  (count: U8.t)
  (pl: with_perm (S.slice U8.t))
  (n: nat)
  (sq: squash (n < 254))
  (l: nlist n expr)
: Tot slprop
= vmatch_and_const (pure (eq2 #nat n (U8.v count))) (pts_to_serialized_with_perm (serialize_nlist n serialize_expr)) pl l // FIXME: WHY WHY WHY WHY WHY WHY do I need this F*ing annotation on eq2? I wasted HOURS on this

let rel_base
  (base: expr_base_t)
  (e: expr)
: Tot slprop
= match base, e with
  | EUPlus count pl, Plus n sq l -> rel_base_EUPlus count pl n sq l
  | EUMinus fst snd, Minus v -> vmatch_pair (pts_to_serialized_with_perm serialize_expr) (pts_to_serialized_with_perm serialize_expr) (fst, snd) v
  | EValue vl, Value vh -> eq_as_slprop U64.t vl vh
  | _ -> pure False

let rec rel
  (low: expr_t)
  (high: expr)
: Tot slprop
  (decreases high)
= match low, high with
  | EBase vb, l -> rel_base vb l
  | EPlus s, Plus n _ l -> nlist_match_slice_wf n s l rel
  | EMinus pl1 pl2, Minus ph -> vmatch_pair (vmatch_ref_wf (Minus ph) rel) (vmatch_ref_wf (Minus ph) rel) (pl1, pl2) ph
  | _ -> pure False

let rel'
  (low: expr_t)
  (high: expr)
: Tot slprop
  (decreases high)
= match low, high with
  | EBase vb, l -> rel_base vb l
  | EPlus s, Plus n _ l -> nlist_match_slice0 rel n s l
  | EMinus pl1 pl2, Minus ph -> vmatch_pair (vmatch_ref rel) (vmatch_ref rel) (pl1, pl2) ph
  | _ -> pure False

let rel_eq
  (low: expr_t)
  (high: expr)
: Lemma
  (rel low high == rel' low high)
= match low, high with
  | EPlus s, Plus n _ l ->
    assert_norm (rel (EPlus s) (Plus n _ l) == nlist_match_slice_wf n s l (rel));
    assert_norm (rel' (EPlus s) (Plus n _ l) == nlist_match_slice0 rel n s l);
    nlist_match_slice_wf_eq (rel) n s l;
    ()
  | EMinus pl1 pl2, Minus ph ->
    assert (rel (EMinus pl1 pl2) (Minus ph) == vmatch_pair (vmatch_ref_wf (Minus ph) rel) (vmatch_ref_wf (Minus ph) rel) (pl1, pl2) ph) by (FStar.Tactics.trefl ());
    assert (rel' (EMinus pl1 pl2) (Minus ph) == vmatch_pair (vmatch_ref rel) (vmatch_ref rel) (pl1, pl2) ph) by (FStar.Tactics.trefl ());
    vmatch_ref_wf_eq (Minus ph) rel (pl1) (fst ph);
    vmatch_ref_wf_eq (Minus ph) rel (pl2) (snd ph);
    ()
  | _ -> ()

// from now on, rel should be opaque

let rel_base_cases_bool
  (low: expr_base_t)
  (high: expr)
: GTot bool
  (decreases high)
= match low, high with
  | EUPlus _ _, Plus _ _ _
  | EUMinus _ _, Minus _
  | EValue _, Value _
    -> true
  | _ -> false

ghost fn rel_base_cases
  (low: expr_base_t)
  (high: expr)
requires rel_base low high
ensures rel_base low high ** pure (rel_base_cases_bool low high == true)
{
  let g = rel_base_cases_bool low high;
  if (g) {
    ()
  } else {
    rewrite (rel_base low high) as (pure False);
    rewrite (pure False) as (rel_base low high)
  }
}

let rel_cases_bool
  (low: expr_t)
  (high: expr)
: GTot bool
  (decreases high)
= match low, high with
  | EPlus _, Plus _ _ _
  | EMinus _ _, Minus _
  | EBase _, _ -> true
  | _ -> false

ghost fn rel_cases
  (low: expr_t)
  (high: expr)
requires rel low high
ensures rel low high ** pure (rel_cases_bool low high == true)
{
  let g = rel_cases_bool low high;
  if (g) {
    ()
  } else {
    rewrite (rel low high) as (pure False);
    rewrite (pure False) as (rel low high)
  }
}

ghost
fn rewrite_with_trade_squash
  (#[FStar.Tactics.exact (`emp_inames)] is:inames)
  (p1 p2: slprop)
  (sq: squash (p1 == p2))
  requires p1
  ensures p2 ** (Trade.trade #is p2 p1)
{
  Trade.rewrite_with_trade #is p1 p2
}

inline_for_extraction noextract [@@noextract_to "krml"]
let get_header_type
  (h: header)
: Tot U8.t
= match h with
  | (| ty, _ |) -> ty

ghost fn unfold_vmatch_and_const
  (#tl #th: Type0)
  (const: slprop)
  (vmatch: tl -> th -> slprop)
  (xl: tl)
  (xh: th)
requires
  vmatch_and_const const vmatch xl xh
ensures
  const ** vmatch xl xh **
  Trade.trade (const ** vmatch xl xh) (vmatch_and_const const vmatch xl xh)
{
  Trade.rewrite_with_trade
    (vmatch_and_const const vmatch xl xh)
    (const ** vmatch xl xh)
}

inline_for_extraction noextract [@@noextract_to "krml"]
fn write_expr_base_payload_plus
  (xh1: header)
  (sq255: squash (get_header_type xh1 = 255uy == false))
  (sq254: squash (get_header_type xh1 = 254uy == false))
: vmatch_lens #_ #_ #_ (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
  (pts_to_serialized_with_perm (serialize_nlist (count_payload xh1) serialize_expr))
= (x1': _)
  (x: _)
{
  let y' : Ghost.erased expr = Ghost.hide (synth_expr (| xh1, Ghost.reveal x |));
  Trade.rewrite_with_trade
    (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1 x1' x)
    (rel_base x1' y');
  rel_base_cases _ _;
  let EUPlus count pl = x1';
  let n = Ghost.hide (Plus?.n y');
  let l = Ghost.hide (Plus?.l y');
  Trade.rewrite_with_trade
    (rel_base x1' y')
    (rel_base_EUPlus count pl n () l);
  Trade.trans _ (rel_base x1' y') _;
  unfold_vmatch_and_const (pure (eq2 #nat n (U8.v count))) (pts_to_serialized_with_perm (serialize_nlist n serialize_expr)) pl l;
  Trade.trans _ _ (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1 x1' x);
  Trade.elim_hyp_l _ _ _;
  pl
}

inline_for_extraction noextract [@@noextract_to "krml"]
fn write_expr_base_payload_minus
  (xh1: header)
  (sq255: squash (get_header_type xh1 = 255uy == false))
  (sq254: squash (get_header_type xh1 = 254uy == true))
: vmatch_lens #_ #_ #_ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
      (pair_to_nlist expr))
  (vmatch_pair (pts_to_serialized_with_perm serialize_expr)
      (pts_to_serialized_with_perm serialize_expr))
=
  (x1': _)
  (x: _)
{
  let y' : Ghost.erased expr = (synth_expr (| xh1, pair_to_nlist _ x |));
  Trade.rewrite_with_trade
    (vmatch_synth (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1) (pair_to_nlist _) x1' x)
    (rel_base x1' y');
  rel_base_cases _ _;
  let EUMinus fs sn = x1';
  let v = Ghost.hide (Minus?._0 y');
  Trade.rewrite_with_trade
    (rel_base x1' y')
    (vmatch_pair (pts_to_serialized_with_perm serialize_expr) (pts_to_serialized_with_perm serialize_expr) (fs, sn) v);
  Trade.trans _ (rel_base x1' y') _;
  (fs, sn)
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_base_payload'
  (xh1: header)
: l2r_writer (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
    (serialize_nlist 
      (count_payload xh1)
      serialize_expr
    )
= l2r_writer_ifthenelse
    (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
    (serialize_nlist 
      (count_payload xh1)
      serialize_expr
    )
    (get_header_type xh1 = 255uy)
    (fun _ ->
      [@@inline_let] let _ = LowParse.Spec.VCList.parse_nlist_nil_as_synth_eq parse_expr in
      l2r_writer_ext
        (l2r_write_synth_recip
          _
          (empty_to_nlist expr) (empty_to_nlist_recip expr)
          (l2r_write_empty _)
        )
        _
    )
    (fun _ -> l2r_writer_ifthenelse
      (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
      (serialize_nlist 
        (count_payload xh1)
        serialize_expr
      )
      (get_header_type xh1 = 254uy)
      (fun _ ->
        [@@inline_let] let _ = LowParse.Spec.VCList.parse_nlist_pair_as_synth_eq parse_expr in
        l2r_writer_ext
          (l2r_write_synth_recip
            (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
            (pair_to_nlist expr) (pair_to_nlist_recip expr)
            (l2r_writer_lens
              (write_expr_base_payload_minus xh1 () ())
              (l2r_write_nondep_then_direct
                (l2r_write_copy serialize_expr)
                ()
                (l2r_write_copy serialize_expr)
              )
            )
          )
          (serialize_nlist 
            (count_payload xh1)
            serialize_expr
          )
      )
      (fun _ ->
        l2r_writer_lens
          (write_expr_base_payload_plus xh1 () ())
          (l2r_write_copy _)
      )
    )

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_base_payload
  (xh1: header)
: l2r_writer (vmatch_dep_proj2 (vmatch_synth rel_base synth_expr) xh1)
      (spec_serialize_recursive_payload serialize_expr_param xh1)
= l2r_writer_ext
    (write_expr_base_payload' xh1)
    (spec_serialize_recursive_payload serialize_expr_param xh1)

inline_for_extraction noextract [@@noextract_to "krml"]
let mk_header
  (lhs: U8.t)
  (rhs: header_rhs lhs)
: Tot header
= (| lhs, rhs |)

fn expr_base_get_header
    (xl: expr_base_t)
    (xh:
      erased (dtuple2 header
            (parse_recursive_payload_t expr
                header
                count_payload))
    )
requires
      (vmatch_synth rel_base synth_expr xl xh)
returns res: header
ensures
      (vmatch_synth rel_base synth_expr xl xh ** pure (res == dfst xh))
{
  unfold (vmatch_synth rel_base synth_expr xl xh);
  let xh' = Ghost.hide (synth_expr xh);
  rel_base_cases xl xh';
  match xl {
    EUPlus count payload -> {
      let n = Ghost.hide (Plus?.n xh');
      let l : Ghost.erased (nlist (Ghost.reveal n) expr) = Ghost.hide (Plus?.l xh');
      Trade.rewrite_with_trade (rel_base xl xh') (rel_base_EUPlus count payload n () l);
      unfold (vmatch_and_const (pure (eq2 #nat n (U8.v count))) (pts_to_serialized_with_perm (serialize_nlist n serialize_expr)) payload l);
      fold (vmatch_and_const (pure (eq2 #nat n (U8.v count))) (pts_to_serialized_with_perm (serialize_nlist n serialize_expr)) payload l);
      Trade.elim _ _;
      fold (vmatch_synth rel_base synth_expr xl xh);
      mk_header count (HUnit #count () ())
    }
    EValue v -> {
      let v' : Ghost.erased U64.t = Value?._0 xh';
      Trade.rewrite_with_trade (rel_base xl xh') (eq_as_slprop U64.t v v');
      unfold (eq_as_slprop U64.t v v');
      fold (eq_as_slprop U64.t v v');
      Trade.elim _ _;
      fold (vmatch_synth rel_base synth_expr xl xh);
      mk_header 255uy (HValue () v)
    }
    EUMinus _ _ -> {
      fold (vmatch_synth rel_base synth_expr xl xh);
      mk_header 254uy (HUnit () ())
    }
  }
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_base_dtuple2 : l2r_writer (vmatch_synth rel_base synth_expr)
  (serialize_dtuple2 serialize_header (spec_serialize_recursive_payload serialize_expr_param))
= l2r_write_dtuple2_recip_explicit_header
    write_header
    expr_base_get_header
    ()
    write_expr_base_payload

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_base' : l2r_writer #expr_base_t #expr rel_base #_ #_ (serialize_expr') =
  l2r_write_synth_recip _ synth_expr synth_expr_recip write_expr_base_dtuple2

let write_expr_base : l2r_writer #expr_base_t #expr rel_base #_ #_ (serialize_expr) =
  [@@inline_let] let _ = parse_expr_eq () in
  l2r_writer_ext write_expr_base' _

inline_for_extraction noextract [@@noextract_to "krml"]
fn write_expr_rec_base
  ()
: vmatch_lens #_ #_ #_ (vmatch_with_cond rel EBase?) rel_base
= (x1': _)
  (x: _)
{
  vmatch_with_cond_elim_trade rel EBase? x1' x;
  rel_cases _ _;
  let EBase res = x1';
  Trade.rewrite_with_trade
    (rel x1' x)
    (rel_base res x);
  Trade.trans _ (rel x1' x) _;
  res
}

ghost fn vmatch_synth_elim_trade
  (#tl: Type0)
  (#th1 #th2: Type0)
  (vmatch: tl -> th1 -> slprop)
  (f21: th2 -> GTot th1)
  (xh: tl)
  (xl2: th2)
requires
  vmatch_synth vmatch f21 xh xl2
ensures
  vmatch xh (f21 xl2) **
  Trade.trade
    (vmatch xh (f21 xl2))
    (vmatch_synth vmatch f21 xh xl2)
{
  Trade.rewrite_with_trade
    (vmatch_synth vmatch f21 xh xl2)
    (vmatch xh (f21 xl2))
}

inline_for_extraction noextract [@@noextract_to "krml"]
fn write_expr_rec_not_base_payload_plus_lens
  (xh1: header)
  (sqplus: squash (get_header_type xh1 = 254uy == false))
: vmatch_lens #_ #_ #_ (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1)
  (nlist_match_slice0 rel (count_payload xh1))
=
  (x1': _)
  (x: _)
{
  vmatch_dep_proj2_elim_trade (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1 x1' x;
  vmatch_synth_elim_trade (vmatch_with_cond rel (pnot EBase?)) synth_expr x1' (| xh1, Ghost.reveal x |);
  Trade.trans _ _ (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1 x1' x);
  let y' : Ghost.erased expr = Ghost.hide (synth_expr (| xh1, Ghost.reveal x |));
  vmatch_with_cond_elim_trade rel (pnot EBase?) x1' y';
  Trade.trans _ _ (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1 x1' x);
  rel_cases _ _;
  rel_eq x1' y';
  let EPlus s = x1';
  let n = Ghost.hide (Plus?.n y');
  let l = Ghost.hide (Plus?.l y');
  Trade.rewrite_with_trade
    (rel x1' y')
    (nlist_match_slice0 rel (count_payload xh1) s l);
  Trade.trans _ (rel x1' y') _;
  s
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base_payload_plus
  (w: l2r_writer rel serialize_expr)
  (xh1: header)
  (sqplus: squash (get_header_type xh1 = 254uy == false))
: l2r_writer (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1
      )
      (spec_serialize_recursive_payload serialize_expr_param xh1)
= l2r_writer_ext
    (l2r_writer_lens
      (write_expr_rec_not_base_payload_plus_lens xh1 sqplus)
      (l2r_write_nlist_as_slice0 rel serialize_expr w (count_payload xh1))
    )
    _

inline_for_extraction noextract [@@noextract_to "krml"]
fn write_expr_rec_not_base_payload_minus_lens
  (xh1: header)
  (sqplus: squash (get_header_type xh1 = 254uy == true))
: vmatch_lens #_ #_ #_ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr))
  (vmatch_pair (vmatch_ref rel) (vmatch_ref rel))
= (x1': _)
  (x': _)
{
  vmatch_synth_elim_trade (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr) _ _;
  vmatch_dep_proj2_elim_trade (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1 _ _;
  Trade.trans _ _ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr) _ _);
  vmatch_synth_elim_trade (vmatch_with_cond rel (pnot EBase?))
              synth_expr _ _;
  Trade.trans _ _ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr) _ _);
  vmatch_with_cond_elim_trade rel (pnot EBase?) _ _;
  Trade.trans _ _ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr) _ _);
  rel_cases _ _;
  let EMinus fs sn = x1';
  with y' . assert (rel x1' y');
  let ph = Ghost.hide (Minus?._0 y');
  rel_eq x1' y';
  Trade.rewrite_with_trade (rel x1' y') (vmatch_pair (vmatch_ref rel) (vmatch_ref rel) (fs, sn) ph);
  Trade.trans _ _ (vmatch_synth (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?))
              synth_expr)
          xh1)
      (pair_to_nlist expr) _ _);
  (fs, sn)
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base_payload_minus
  (w: l2r_writer rel serialize_expr)
  (xh1: header)
  (sqplus: squash (get_header_type xh1 = 254uy == true))
: l2r_writer (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1
      )
      (spec_serialize_recursive_payload serialize_expr_param xh1)
=
        [@@inline_let] let _ = LowParse.Spec.VCList.parse_nlist_pair_as_synth_eq parse_expr in
        l2r_writer_ext
          (l2r_write_synth_recip
            _
            (pair_to_nlist expr) (pair_to_nlist_recip expr)
            (l2r_writer_lens
              (write_expr_rec_not_base_payload_minus_lens xh1 ())
              (l2r_write_nondep_then_direct
                (l2r_write_ref w)
                ()
                (l2r_write_ref w)
              )
            )
          )
          (serialize_nlist 
            (count_payload xh1)
            serialize_expr
          )
 
inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base_payload
  (w: l2r_writer rel serialize_expr)
  (xh1: header)
: l2r_writer (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1
      )
      (spec_serialize_recursive_payload serialize_expr_param xh1)
= l2r_writer_ifthenelse
    (vmatch_dep_proj2 (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr) xh1)
    (spec_serialize_recursive_payload serialize_expr_param xh1)
    (get_header_type xh1 = 254uy)
    (write_expr_rec_not_base_payload_minus w xh1)
    (write_expr_rec_not_base_payload_plus w xh1)

fn expr_get_header
    (xl: expr_t)
    (xh:
      erased (dtuple2 header
            (parse_recursive_payload_t expr
                header
                count_payload))
    )
requires
      (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr xl xh)
returns res: header
ensures
      (
          vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr xl xh **
          pure (res == dfst xh))
{
  vmatch_synth_elim_trade
    (vmatch_with_cond rel (pnot EBase?)) synth_expr xl xh;
  let xh' = Ghost.hide (synth_expr xh);
  vmatch_with_cond_elim_trade rel (pnot EBase?) xl xh';
  Trade.trans _ _ (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr xl xh);
  rel_cases _ _;
  rel_eq xl xh';
  match xl {
    EPlus s -> {
      let n = Ghost.hide (Plus?.n xh');
      let l = Ghost.hide (Plus?.l xh');
      Trade.rewrite_with_trade
        (rel xl xh')
        (nlist_match_slice0 rel n s l);
      Trade.trans _ (rel xl xh') _;
      nlist_match_slice0_elim_trade rel n s l;
      Trade.trans _ _ (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr xl xh);
      S.pts_to_len s.v;
      PM.seq_list_match_length rel _ _;
      let len = S.len s.v;
      Trade.elim _ _;
      let res32 = SZ.sizet_to_uint32 len;
      let res8 = FStar.Int.Cast.uint32_to_uint8 res32;
      mk_header res8 (HUnit () ())
    }
    EMinus fs sn -> {
      Trade.elim _ _;
      mk_header 254uy (HUnit () ())
    }
  }
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base_dtuple2
  (w: l2r_writer rel serialize_expr)
:
l2r_writer (vmatch_synth (vmatch_with_cond rel (pnot EBase?)) synth_expr)
  (serialize_dtuple2 serialize_header (spec_serialize_recursive_payload serialize_expr_param))
= l2r_write_dtuple2_recip_explicit_header
    write_header
    expr_get_header
    ()
    (write_expr_rec_not_base_payload w)

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base'
  (w: l2r_writer rel serialize_expr)
: l2r_writer #expr_t #expr (vmatch_with_cond rel (pnot EBase?)) #_ #_ (serialize_expr') =
  l2r_write_synth_recip _ synth_expr synth_expr_recip (write_expr_rec_not_base_dtuple2 w)

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec_not_base
  (w: l2r_writer rel serialize_expr)
: l2r_writer (vmatch_with_cond rel (pnot EBase?)) serialize_expr
= [@@inline_let] let _ = parse_expr_eq () in
  l2r_writer_ext (write_expr_rec_not_base' w) _

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr_rec
  (w: l2r_writer rel serialize_expr)
: l2r_writer #expr_t #expr rel #_ #_ (serialize_expr)
=
  l2r_writer_ifthenelse_low
    _
    serialize_expr
    EBase?
    (l2r_writer_lens
      (write_expr_rec_base ())
      write_expr_base
    )
    (write_expr_rec_not_base w)

fn rec write_expr
  (x': expr_t)
  (#x: Ghost.erased expr)
  (out: S.slice U8.t)
  (offset: SZ.t)
  (#v: Ghost.erased bytes)
requires
    (pts_to out v ** rel x' x ** pure (
      l2r_writer_for_pre serialize_expr x offset v
    ))
returns res: SZ.t
ensures exists* v' .
  pts_to out v' ** rel x' x ** pure (
  l2r_writer_for_post serialize_expr x offset v res v'
)
{
  write_expr_rec write_expr x' #x out offset #v
}

inline_for_extraction noextract [@@noextract_to "krml"]
let write_expr' : l2r_writer rel serialize_expr = write_expr
