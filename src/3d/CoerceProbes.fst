(*
   Copyright 2025 Microsoft Research

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain as copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)
module CoerceProbes
(*
  This module implements a pass over the source AST,
  elaborating CoerceProbeFunctionStubs into ProbeFunctions, 
  by coercing a 32-bit layout type into a 64-bit layout type 
*)
open FStar.Mul
open FStar.List.Tot
open Ast
open FStar.All
module H = Hashtable
module B = Binding
open GlobalEnv

let probe_return_unit 
: probe_action
= with_dummy_range <|
  Probe_atomic_action <|
  Probe_action_return (with_dummy_range (Constant Unit))

let print_probe_qualifier = function
  | PQWithOffsets -> "WithOffsets"
  | PQRead i -> Printf.sprintf "Read %s" (print_integer_type i)
  | PQWrite i -> Printf.sprintf "Write %s" (print_integer_type i)


let find_probe_fn (e:B.env) (q:probe_qualifier)
: ML ident
= match GlobalEnv.extern_probe_fn_qual (B.global_env_of_env e) (Some q) with
  | None ->
    error (Printf.sprintf "Cannot find probe function for %s" (print_probe_qualifier q))
          dummy_range
  | Some id ->
    id
  
let find_extern_coercion (e:B.env) (t0:typ) (t1:typ)
: ML ident
= match GlobalEnv.resolve_extern_coercion (B.global_env_of_env e) t0 t1 with
  | None ->
    error (Printf.sprintf "Cannot find coercion for %s to %s" (print_typ t0) (print_typ t1))
          dummy_range
  | Some id ->
    id

let read_and_coerce_pointer (e:B.env) (fid:ident) (k:probe_action)
: ML probe_action
= let reader = find_probe_fn e (PQRead UInt32) in
  let writer = find_probe_fn e (PQWrite UInt64) in
  let coercion = find_extern_coercion e tuint32 tuint64 in
  let fid64 = {fid with v = { fid.v with name = fid.v.name ^ "_64" } } in
  let fid_expr = with_dummy_range <| Identifier fid in
  let fid64_expr = with_dummy_range <| Identifier fid64 in
  with_dummy_range <|
  Probe_action_let 
    fid
    (Probe_action_read reader)
    (with_dummy_range <|
      Probe_action_let fid64
        (Probe_action_call coercion [fid_expr])
        (with_dummy_range <| 
          Probe_action_seq (with_dummy_range <| Probe_atomic_action (Probe_action_write writer fid64_expr)) k))

let integer_type_of_type t
: option integer_type
= if eq_typ t tuint8 then Some UInt8
  else if eq_typ t tuint16 then Some UInt16
  else if eq_typ t tuint32 then Some UInt32
  else if eq_typ t tuint64 then Some UInt64
  else None 

let rec head_type (e:B.env) (t:typ) : ML ident =
  match (Binding.unfold_typ_abbrev_only e t).v with
  | Type_app hd _ _ _ -> hd
  | Pointer t _ -> head_type e t

let probe_and_copy_type (e:B.env) (t:typ) (k:probe_action)
: ML probe_action
= let probe_and_copy_n = find_probe_fn e PQWithOffsets in
  let t = B.unfold_typ_abbrev_and_enum e t in
  match integer_type_of_type t with
  | None -> (
      if eq_typ t tunit then k else
      let id = head_type e t in
      match GlobalEnv.find_probe_fn (B.global_env_of_env e) (SimpleProbeFunction id) with
      | None ->
        error 
          (Printf.sprintf "Cannot find probe function for type %s" (print_typ t))
          t.range
      | Some id ->
        with_dummy_range <|
        Probe_action_seq
          (with_dummy_range <| (Probe_action_var id))
          k
  )
  | Some i -> 
    let size =
      match i with
      | UInt8 -> 1
      | UInt16 -> 2
      | UInt32 -> 4
      | UInt64 -> 8
    in
    with_dummy_range <|
    Probe_action_seq
      (with_dummy_range <| Probe_atomic_action (Probe_action_copy probe_and_copy_n (with_dummy_range <| Constant (Int UInt64 size))))
      k
  
let rec write_n_bytes_zero (e:B.env) (n:int) (k:probe_action)
: ML probe_action
= let writei t
    : ML probe_action
    = let writer = find_probe_fn e (PQWrite t) in
      with_dummy_range <|
      Probe_action_seq
        (with_dummy_range <| Probe_atomic_action (Probe_action_write writer (with_dummy_range <| Constant (Int t 0))))
        k
  in
  match n with
  | 0 -> k
  | 1 -> writei UInt8
  | 2 -> writei UInt16
  | 4 -> writei UInt32
  | 8 -> writei UInt64
  | _ -> 
    if n > 8
    then write_n_bytes_zero e (n - 8) (write_n_bytes_zero e 8 k)
    else if n > 4
    then write_n_bytes_zero e (n - 4) (write_n_bytes_zero e 4 k)
    else if n > 2
    then write_n_bytes_zero e (n - 2) (write_n_bytes_zero e 2 k)
    else write_n_bytes_zero e (n - 1) (write_n_bytes_zero e 1 k)

let skip_bytes (n:int) (k:probe_action)
: ML probe_action
= with_dummy_range <|
    Probe_action_seq 
      (with_dummy_range <| Probe_atomic_action (Probe_action_skip (with_dummy_range <| Constant (Int UInt64 n))))
      k

let probe_and_copy_alignment 
    (e:B.env)
    (n0 n1:int)
    (k:probe_action)
: ML probe_action
= if n0=n1
  then (
    let probe_and_copy_n = find_probe_fn e PQWithOffsets in
    with_dummy_range <|
      Probe_action_seq
        (with_dummy_range <| Probe_atomic_action 
          (Probe_action_call probe_and_copy_n [with_dummy_range <| Constant (Int UInt64 n0)]))
        k
  )
  else (
    skip_bytes n0 (write_n_bytes_zero e n1 k)
  )

let alignment_bytes (af:atomic_field)
: ML int
= match af.v.field_array_opt with
  | FieldArrayQualified ({v=Constant (Int _ n)}, ByteArrayByteSize) -> n
  | _ -> failwith "Not an alignment field"

let rec coerce_record (e:B.env) (r0 r1:record)
: ML probe_action
= match r0, r1 with
  | hd0::tl0, hd1::tl1 -> (
    match hd0.v, hd1.v with
    | AtomicField af0, AtomicField af1 -> (
      match TypeSizes.is_alignment_field af0.v.field_ident,
            TypeSizes.is_alignment_field af1.v.field_ident
      with
      | true, true ->
        let n0 = alignment_bytes af0 in
        let n1 = alignment_bytes af1 in
        probe_and_copy_alignment e n0 n1 (coerce_record e tl0 tl1)
      | true, false ->
        let n0 = alignment_bytes af0 in
        skip_bytes n0 (coerce_record e tl0 r1)
      | false, true ->
        let n1 = alignment_bytes af1 in
        write_n_bytes_zero e n1 (coerce_record e r0 tl1)
      | false, false -> (
        if not (eq_idents af0.v.field_ident af1.v.field_ident)
        then failwith <|
              Printf.sprintf
                "Unexpected fields: cannot coerce field %s to %s"
                (print_ident af0.v.field_ident)
                (print_ident af1.v.field_ident)
        else (
          let t0_is_u32 =
            match af0.v.field_type.v with
            | Pointer _ (PQ UInt32) -> true
            | _ -> eq_typ af0.v.field_type tuint32
          in
          let t1_is_ptr64 =
            match af1.v.field_type.v with
            | Pointer _ (PQ UInt64) -> true
            | _ -> false
          in
          if t0_is_u32 && t1_is_ptr64
          then read_and_coerce_pointer e af0.v.field_ident (coerce_record e tl0 tl1)
          else if eq_typ af0.v.field_type af1.v.field_type
          then probe_and_copy_type e af0.v.field_type (coerce_record e tl0 tl1)
          else (
            match Generate32BitTypes.has_32bit_coercion e af0.v.field_type af1.v.field_type with
            | Some id ->
              with_dummy_range <|
              Probe_action_seq 
                (with_dummy_range <| Probe_action_var id)
                (coerce_record e tl0 tl1)
            | None ->
              failwith <|
                Printf.sprintf
                  "Unexpected fields: cannot coerce field %s of type %s to %s"
                  (print_ident af0.v.field_ident)
                  (print_typ af0.v.field_type)
                  (print_typ af1.v.field_type)
          )
        )
      )
    )
    | _ -> 
      failwith "Cannot yet coerce structs with non-atomic fields"
  )
  | [], [] ->
    probe_return_unit
  | _ -> failwith "Unexpected number of fields"

let rec optimize_coercion (p:probe_action)
: ML probe_action
= match p.v with
  | Probe_action_seq {v=Probe_atomic_action (Probe_action_copy f len)} k -> (
    let k = optimize_coercion k in
    let def () = { p with v = Probe_action_seq (with_dummy_range <| Probe_atomic_action (Probe_action_copy f len)) k } in
    match len.v with
    | Constant (Int UInt64 l0) -> (
      match k.v with
      | Probe_action_seq {v=Probe_atomic_action (Probe_action_copy g {v=Constant (Int UInt64 l1)})} k -> 
        if eq_idents f g || true
        then (

          { k with v = 
            Probe_action_seq 
              (with_dummy_range <| Probe_atomic_action (Probe_action_copy g {len with v=Constant (Int UInt64 (l0 + l1))}))
              k }
        )
        else def ()

      | Probe_atomic_action (Probe_action_copy g {v=Constant (Int UInt64 l1)}) -> 
        if eq_idents f g || true
        then { k with v=Probe_atomic_action (Probe_action_copy g {len with v=Constant (Int UInt64 (l0 + l1))}) }
        else def ()
      
      | _ -> def ()
    )
    | _ -> def ()
  )
  | Probe_action_seq a k ->
    { p with v = Probe_action_seq a (optimize_coercion k) }
  | Probe_action_let i a k ->
    { p with v = Probe_action_let i a (optimize_coercion k) }
  | _ -> p
  

let replace_stub (e:B.env) (d:decl { CoerceProbeFunctionStub? d.d_decl.v })
: ML decl
= let CoerceProbeFunctionStub i (CoerceProbeFunction (t0, t1)) = d.d_decl.v in
  let d0, _ = B.resolve_record_type e t0 in
  let d1, _ = B.resolve_record_type e t1 in
  let Record _ _ _ _ r0 = d0.d_decl.v in
  let Record _ _ _ _ r1 = d1.d_decl.v in
  let probe_action = optimize_coercion <| coerce_record e r0 r1 in
  let probe_fn = { 
      d.d_decl with
      v = ProbeFunction i [] probe_action (CoerceProbeFunction(t0, t1)) 
    }
  in
  { d with d_decl = probe_fn }

let replace_stubs (e:global_env) (ds:list decl)
: ML (list decl)
= let e = B.mk_env e in
  List.map 
    (fun (d:decl) ->
      if CoerceProbeFunctionStub? d.d_decl.v
      then replace_stub e d
      else d)
    ds