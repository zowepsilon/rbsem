open Ast
open Ast.MlSem

let funn arg body = Fun ([arg], body)
let vv e env = Constr ("V", Tuple [e; env])
let vvp e env = TyConstr ("V", TyTuple [e; env])
let rr e = Constr ("R", e)
let rrp e = TyConstr ("R", e)

let instance_var name = "attr_" ^ name
let class_var name = "class" ^ name
let class_ty name = "ty" ^ name
let class_ty_rec name = "ty" ^ name ^ "Rec"
let class_singleton_ty name = "tyClass" ^ name
let symbol_name name = "S_" ^ name
let attr_name name = "__attr_" ^ name

let name_subtyping_field = "__name"
let name_subtyping_symbol = "DummySymbol"
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
    vvp (TyName v) (TyName env2), App (App (f, Var v), Var env2);
    rrp (TyName "r"), rr (Var "r");
  ])

let ( >>= ) = bind

let extract (m : expr) : expr =
  funn "_" @@ MatchWith (App (m, RecordLit (None, [])), [
    vvp (TyName "v") (TyName "_"), Var "v";
    rrp (TyName "r"), Var "r";
  ])

let get (x : var_name) : expr =
  let env = fresh default_env_name in
  funn env (vv (FieldAccess (Var env, x)) (Var env))

let set (x : var_name) (vall: expr) : expr =
  let env = fresh default_env_name in
  funn env (vv vall (RecordLit (Some (Var env), [x, vall])))

module Rbs = struct
  let rec dom (t : Rbs.ty) : Rbs.ty =
    match t with
    | TyFun (u, _) -> TyTuple u
    | TyMethAnd (t1, t2) -> TyOr (dom t1, dom t2)
    | _ -> failwith ("method intersection of non-function type: " ^ Rbs.show_ty t)
  
  let cod (t : Rbs.ty) : Rbs.ty =
    match t with
    | TyFun (_, r) -> r
    | _ -> failwith ("method intersection of non-function type: " ^ Rbs.show_ty t)

  let rec ty (t : Rbs.ty) : ty =
    match t with
    | TySymbol -> TyName "enum"
    | TyInteger -> TyName "int"
    | TySelf -> TyVar "self"
    | TyNil -> TyTuple []
    | TyTuple elmts -> TyTuple (List.map ty elmts)
    | TyBot -> TyName "empty"
    | TyLit LitTrue -> TyName "true"
    | TyLit LitFalse -> TyName "false"
    | TyLit (LitNum i) -> TyName (string_of_int i)
    | TyLit (LitSym s) -> TyName (symbol_name s)
    | TyClass c -> TyName (class_ty c)
    | TyOr (t1, t2) -> TyOr (ty t1, ty t2)
    | TyAnd (t1, t2) -> TyAnd (ty t1, ty t2)
    | TyMethAnd (t1, t2) ->
        TyAnd (ty t1, TyArrow (TyAnd (ty (dom t2), TyNot (ty (dom t1))), ty (cod t2)))
    | TyFun (u, r) -> TyArrow (TyTuple (List.map ty u), ty r)
    | TyNot t -> TyNot (ty t)

  let rec make_constructor_ty (name : class_name) (t : Rbs.ty) : Rbs.ty =
    match t with
    | TyAnd (t1, t2) -> TyAnd (make_constructor_ty name t1, make_constructor_ty name t2)
    | TyMethAnd (t1, t2) -> TyMethAnd (make_constructor_ty name t1, make_constructor_ty name t2)
    | TyFun (t1, _) -> TyFun (t1, TyClass name)
    | _ -> failwith "initialize type is not an intersection of function types"

  let member_inst (m : Rbs.member) : (string * ty) option =
    match m with
    | MemMeth (f, t) -> Some (f, ty t)
    | MemAttr (x, t) -> Some (attr_name x, ty t)
    | _ -> None

  let member_class (name : class_name) (m : Rbs.member) : (string * ty) option =
    match m with
    | MemInit t -> Some ("new", ty (make_constructor_ty name t))
    | MemClassMeth (f, t) -> Some (f, ty t)
    | _ -> None

  let decl_inst (d : Rbs.decl) : top_level list =
    let Decl (name, parent, members) = d in
    let members = List.fold_left (fun acc m -> match member_inst m with
      | Some mem -> mem :: acc
      | None -> acc
    ) [] members in
    let members = (name_subtyping_field, TyNot (TyName "TODO_")) :: List.rev members in
    let class_ty_rec_name = class_ty_rec name in
    let class_ty_name = class_ty name in
    let recTy = TLTy [class_ty_rec_name, ["self"], TyRecord (
      Option.map (fun parent -> TyConstr (class_ty_rec parent, TyVar "self")) parent,
      members,
      TailOpen
    )] in
    let closedTy = TLTy [class_ty_name, [], TyConstr (class_ty_rec_name, TyName class_ty_name)] in
    [closedTy; recTy]

  let decl_class (d : Rbs.decl) : top_level =
    let Decl (name, parent, members) = d in
    let members = List.fold_left (fun acc m -> match member_class name m with
      | Some mem -> mem :: acc
      | None -> acc
    ) [] members in
    let members = (name_subtyping_field, TyNot (TyName "TODO_")) :: List.rev members in
    let classTy = TLTy [class_singleton_ty name, [], TyRecord (
      Option.map (fun parent -> TyName (class_singleton_ty parent)) parent,
      members,
      TailOpen
    )] in
    classTy

  let decl (d : Rbs.decl) : top_level list =
    decl_class d :: decl_inst d

  let program (p : Rbs.program) : top_level list =
    List.concat_map decl p |> List.rev
end

module Ruby = struct
  let rec expr (self_ty : ty) (e : Ruby.expr) : expr =
    match e with
    | Lit lit -> value (Lit lit)
    | LocalVar x -> get x
    | InstVar x -> value (FieldAccess (Var "self", instance_var x))
    | ClassVar c -> value (Var (class_var c))
    | Self -> value (Var "self")
    | Nil -> value (Tuple [])
    | Call (receiver, meth, args) ->
        let recv = fresh "__receiver" in
        let arg_name = fresh "__arg" in
        let call = App (FieldAccess (Var recv, meth), Var arg_name) in
        expr self_ty receiver >>= funn recv (expr self_ty (Tuple args) >>= funn arg_name (value call))
    | LocalAssign (x, e) ->
        expr self_ty e >>= funn "v" (set x (Var "v"))
    | InstAssign (x, e) ->
        let self_assign = Assign ("self", Cast (RecordLit (Some (Var "self"), [attr_name x, Var "v"]), self_ty)) in
        expr self_ty e >>= funn "v" (Seq (self_assign, value (Var "v")))
    | IfThenElse (cond, e1, e2) ->
        let ccond = fresh "__cond" in
        expr self_ty cond >>= funn ccond (
          IfIsThenElse (
            Var ccond,
            TyName "truthy",
            expr self_ty e1,
            expr self_ty e2
          )
        )
    | Seq (e1, e2) -> expr self_ty e1 >>= (funn "_" (expr self_ty e2))
    | Return e -> expr self_ty e >>= funn "r" (return (Var "r"))
    | Tuple elmts ->
        let v = fresh "v" in
        let vars = List.mapi (fun i _ -> (v ^ "_" ^ string_of_int i)) elmts in
        let res = value (Tuple (List.map (fun x -> Var x) vars)) in
        List.fold_left2 (fun tail var e -> expr self_ty e >>= funn var tail) res (List.rev vars) (List.rev elmts)

  let function_body_body (self_ty : ty) (body : Ruby.expr) : expr =
    App (Var "extract", expr self_ty body)

  let function_body (self_ty : ty) (args : string list) (body : Ruby.expr) : expr =
    Fun (args, function_body_body self_ty body)

  let cstmt_inst (self_ty : ty) (m : Ruby.class_stmt) : (string * expr) option =
    match m with
    | CStmtAttr x -> Some (attr_name x, Var "undefined")
    | CStmtMeth (f, args, body) -> Some (f, function_body self_ty args body)
    | _ -> None

  let cstmt_class
      (name : class_name)
      (parent : class_name option)
      (members : Ruby.class_stmt list)
      (m : Ruby.class_stmt) : (string * expr) option =
    match m with
    | CStmtClassMeth (f, args, body) ->
        Some (f, function_body (TyName (class_singleton_ty name)) args body)
    | CStmtInit (args, body) ->
        let self_ty = TyName (class_ty name) in
        let fields = List.fold_left (fun acc m ->
          match cstmt_inst self_ty m with
          | Some x -> x :: acc
          | None -> acc
        ) [] members in
        let fields = 
            (name_subtyping_field, Cast (Var name_subtyping_symbol, TyNot (TyName "TODO_")))
            :: List.rev fields in
        Some ("new", Fun (args, Cast(App (Var "rec", FunAnnot ("self", TyName (class_ty name),
          LetMutIn ("self", Var "self", Seq (
            Assign ("self", Cast(
              RecordLit (
                Option.map (fun parent -> Cast (Var "opaque", TyName (class_ty parent))) parent,
                fields
              ),
              self_ty
            )),
            Seq (
            function_body_body self_ty body,
            Cast (Var "self", self_ty)
            ))
          )
        )), self_ty)))
    | _ -> None

  let stmt (s : Ruby.stmt) : top_level =
    let Stmt (name, parent, members) = s in
    let fields = List.fold_left (fun acc m ->
      match cstmt_class name parent members m with
      | Some x -> x :: acc
      | None -> acc
    ) [] members in
    let fields =
        (name_subtyping_field, Cast (Var name_subtyping_symbol, TyNot (TyName "TODO_")))
        :: List.rev fields in
    TLLet (class_var name, Cast (App (Var "rec", FunAnnot ("self", TyName (class_singleton_ty name),
      LetMutIn ("self", Var "self", Cast (RecordLit (None, fields), TyName (class_singleton_ty name)))
    )), TyName (class_singleton_ty name)))

  let program (p : Ruby.program) : top_level list =
    List.map stmt p
end