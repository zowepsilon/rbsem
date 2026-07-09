open Ast

(* note: added in OCaml 5.5 *)
(* a better name would be Option::is_some_and *)
let option_exists (f: 'a -> bool) (x: 'a option) : bool =
  match x with
  | None -> false
  | Some x -> f x

let rec is_free_in (x: var_name) (e: MlSem.expr) : bool =
  match e with
  | Lit _ -> false
  | Var y -> x = y
  | Tuple elmts -> List.exists (is_free_in x) elmts
  | FieldAccess (e, _) -> is_free_in x e
  | MatchWith (scrutinee, branches) ->
      is_free_in x scrutinee || List.exists (fun (p, e) -> not (is_free_in_pat x p) && is_free_in x e) branches
  | Fun (y, e) -> x <> y && is_free_in x e
  | RecordLit (base, fields) ->
      option_exists (is_free_in x) base
      || List.exists (fun (_, e) -> is_free_in x e) fields
  | _ -> assert false

and is_free_in_pat (x : var_name) (p : MlSem.ty) : bool =
  match p with
  | TyVar _ -> false
  | TyBind y -> x = y
  | TySymbol _ -> false
  | TyName _ -> false
  | TyEnum -> false
  | TyInt -> false
  | TyEmpty -> false
  | TyTuple elmts -> List.exists (is_free_in_pat x) elmts
  | TyNot p -> is_free_in_pat x p
  | TyArrow (p1, p2) -> is_free_in_pat x p1 || is_free_in_pat x p2
  | TyOr (p1, p2) -> is_free_in_pat x p1 || is_free_in_pat x p2
  | TyAnd (p1, p2) -> is_free_in_pat x p1 || is_free_in_pat x p2
  | TyRecord (base, fields, _tail) ->
      (option_exists (is_free_in_pat x) base)
      || (List.exists (fun (_, p) -> is_free_in_pat x p) fields)
  | TyConstr (_c, t) -> is_free_in_pat x t

let vv e env = MlSem.Constr ("V", Tuple [e; env])
let vvp e env = MlSem.TyConstr ("V", TyTuple [e; env])
let rr e = MlSem.Constr ("R", e)
let rrp e = MlSem.TyConstr ("R", e)

let value (e: MlSem.expr) : MlSem.expr =
  let open MlSem in
  assert (not (is_free_in "env" e));
  Fun ("env", vv e (Var "env"))

let return (e : MlSem.expr) : MlSem.expr =
  let open MlSem in
  Fun ("env", rr e)

let bind (m : MlSem.expr) (f: MlSem.expr) : MlSem.expr =
  let open MlSem in
  Fun ("env", MatchWith (App (m, Var "env"), [
    vvp (TyBind "v") (TyBind "env1"), App (App (f, Var "v"), Var "env");
    rrp (TyBind "r"), rr (Var "r");
  ]))

let extract (m : MlSem.expr) : MlSem.expr =
  let open MlSem in
  Fun ("env", MatchWith (App (m, RecordLit (None, [])), [
    vvp (TyBind "v") (TyBind "_"), Var "v";
    rrp (TyBind "r"), Var "r";
  ]))