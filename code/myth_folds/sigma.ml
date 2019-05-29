open Core
open Printf
open Lang

module type Sigma_Sig = sig
  type t

  val empty           : t
  val append          : t  -> t  -> t
  val make_from_data  : id -> ctor list -> t

  val lookup_ctor     : id -> t -> (typ * id) option
  val lookup_ctor_exn : id -> t ->  typ * id
  val ctor_datatype   : id -> t -> id

  val restrict        : id -> t -> t
  val types           : t  -> typ list
  val ctors           : id -> t -> (id * (typ * id)) list
  val show            : t -> string

  val is_recursive    : t -> id -> bool
end

(* A signature stores the definitions of all constructors and datatypes currently  *)
(* available for use.                                                              *)
module Sigma = struct
  (* A single entry of a signature.                                                *)
  type entry = { ctor_name     : id       (* The name of the constructor.          *)
               ; datatype_name : id       (* The name of the datatype it inhabits. *)
               ; ctor_type     : typ      (* The type of the constructor contents. *)
               }
  [@@deriving ord, show, hash]
  (* A signature is a list of entries.                                             *)
  type t = entry list
  [@@deriving ord, show, hash]

  let empty : t = []                      (* Create an empty signature.            *)
  let append : t -> t -> t = (@)          (* Append two signatures.                *)
  let make_entry c d t =                  (* Create an entry.                      *)
      { ctor_name = c; datatype_name = d; ctor_type = t }

  (* Create a signature consisting from the constructors of a datatype.            *)
  let make_from_data (d:id) (cs:ctor list) : t =
    List.map ~f:(fun (c, t) -> make_entry c d t) cs

  (* Look up the type and datatype of a constructor name.                         *)
  let rec lookup_ctor (c:id) (s:t) : (typ * id) option =
    match s with
    | [] -> None
    | hd :: tl -> if hd.ctor_name = c then Some (hd.ctor_type, hd.datatype_name)
                  else lookup_ctor c tl

  (* Look up the type and datatype of a constructor name.  Exception if not found.*)
  let lookup_ctor_exn (c:id) (s:t) : typ * id =
    match lookup_ctor c s with
    | Some ans -> ans
    | None -> internal_error "lookup_ctor_exn" (sprintf "ctor not found: %s" c)

  (* Determine the datatype of a constructor.                                     *)
  let ctor_datatype (c:id) (s:t) : id = snd (lookup_ctor_exn c s)

  (* Eliminates all constructors except those inhabiting datatype d.              *)
  let restrict (d:id) (s:t) : t =
    List.filter ~f:(fun e -> e.datatype_name = d) s

  (* Returns a list of all datatypes found in s as TBases.                        *)
  let types (s:t) : typ list =
    List.map ~f:(fun e -> e.datatype_name) s |>
    List.dedup_and_sort ~compare:String.compare |>
    List.map ~f:(fun d -> TBase d)

  (* Returns a list of all constructors for a particular datatype.               *)
  let ctors (dt:id) (s:t) : (id * (typ * id)) list =
    List.filter ~f:(fun e -> dt = e.datatype_name) s |>
    List.map    ~f:(fun e -> (e.ctor_name, (e.ctor_type, e.datatype_name)))

  let is_recursive
      (s:t)
      (type_name:id)
    : bool =
    let rec contains_t
        (t:typ)
      : bool =
      begin match t with
        | TBase i ->
          i = type_name
        | TArr (t1,t2) ->
          contains_t t1 || contains_t t2
        | TTuple ts ->
          List.exists ~f:contains_t ts
        | TRcd _ -> failwith "cannot do"
        | TUnit -> false
      end
    in
    List.exists
      ~f:(fun (_,(t,_)) -> contains_t t)
      (ctors type_name s)

  let add_ctors_env (e:env) (s:t) : env =
    let ts = types s in
    let tis =
      List.map
        ~f:(function (TBase i) -> i | _ -> failwith "not happen")
        ts
    in
    List.fold_left
      ~f:(fun e ti ->
          let ctors =
            ctors
              ti
              s
          in
          List.fold_left
            ~f:(fun e (s,(_,_)) ->
                (s,VFun ("i",(ECtor (s,EVar "i")), ref []))::e
              )
            ~init:e
            ctors)
      ~init:e
      tis
end
