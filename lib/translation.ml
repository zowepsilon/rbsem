open Ast
open Ast.MlSem

let funn arg body = Fun (arg, body)
let vv e env = Constr ("V", Tuple [e; env])
let vvp e env = TyConstr ("V", TyTuple [e; env])
let rr e = Constr ("R", e)
let rrp e = TyConstr ("R", e)

let instance_var name = "attr_" ^ name
let class_var name = name
let default_env_name = "env"

let fresh =
  let i = ref 0 in
  fun name -> (incr i; name ^ string_of_int !i)

let value (e: expr) : expr =
  let env = fresh default_env_name in
  funn env (vv e (Var env))

let return (e : expr) : expr =
  funn (fresh default_env_name) (rr e)

let bind (m : expr) (f: expr) : expr =
  let env = fresh default_env_name in
  let env2 = fresh default_env_name in
  let v = fresh "__v" in
  funn env @@ MatchWith (App (m, Var env), [
    vvp (TyBind v) (TyBind env2), App (App (f, Var v), Var env2);
    rrp (TyBind "r"), rr (Var "r");
  ])

let ( >>= ) = bind

let extract (m : expr) : expr =
  funn "_" @@ MatchWith (App (m, RecordLit (None, [])), [
    vvp (TyBind "v") (TyBind "_"), Var "v";
    rrp (TyBind "r"), Var "r";
  ])

let get (x : var_name) : expr =
  let env = fresh default_env_name in
  funn env (vv (FieldAccess (Var env, x)) (Var env))

let set (x : var_name) (vall: expr) : expr =
  let env = fresh default_env_name in
  funn env (vv vall (RecordLit (Some (Var env), [x, vall])))

module Ruby = struct
  let rec expr (e : Ruby.expr) : expr =
    match e with
    | Lit lit -> value (Lit lit)
    | LocalVar x -> get x
    | InstVar x -> value (FieldAccess (Var "self", instance_var x))
    | ClassVar c -> value (Var (class_var c))
    | Self -> value (Var "self")
    | Nil -> value (Tuple [])
    | Call (receiver, meth, arg) ->
        let recv = fresh "__receiver" in
        let arg_name = fresh "__arg" in
        let call = App (FieldAccess (Var recv, meth), Var arg_name) in
        expr receiver >>= funn recv (expr arg >>= funn arg_name (value call))
    | LocalAssign (x, e) ->
        expr e >>= funn "v" (set x (Var "v"))
    | InstAssign (x, e) ->
        let self_assign = Assign ("self", RecordLit (Some (Var "self"), [x, Var "v"])) in
        expr e >>= funn "v" (Seq (self_assign, value (Var "v")))
    | IfThenElse (cond, e1, e2) ->
        let ccond = fresh "__cond" in
        expr cond >>= funn ccond (
          IfIsThenElse (
            Var ccond,
            TyName "truthy",
            expr e1,
            expr e2
          )
        )
    | Seq (e1, e2) -> expr e1 >>= (funn "_" (expr e2))
    | Return e -> expr e >>= funn "r" (return (Var "r"))
end

module Rbs = struct
end