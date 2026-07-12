(* Represents variable names like x, hello123, ruby_is_a_gem, etc. *)
type var_name = string [@@deriving show]
(* Same *)
type fun_name = string [@@deriving show]
(* Represents constructor names starting with an uppercase letter
   e.g. MyClass, Value123, Parse_error *)
type class_name = string [@@deriving show]

type lit = 
  | LitTrue
  | LitFalse
  | LitSym of string
  | LitNum of int
[@@deriving show]

let display_lit : lit -> string =
  function
  | LitTrue -> "true"
  | LitFalse -> "false"
  | LitSym s -> s
  | LitNum i -> string_of_int i

module Ruby = struct
  type expr =
    | Lit of lit
    | LocalVar of var_name
    | InstVar of var_name
    | ClassVar of class_name
    | Self
    | Nil
    | Call of expr * fun_name * expr
    | LocalAssign of var_name * expr
    | InstAssign of var_name * expr
    | IfThenElse of expr * expr * expr
    | Seq of expr * expr
    | Return of expr
  [@@deriving show]

  type stmt = Stmt of class_name * class_name option * class_stmt list
  and class_stmt =
    | CStmtMeth of fun_name * var_name * expr
    | CStmtInit of var_name * expr
    | CStmtClassMeth of fun_name * var_name * expr
    | CStmtAttr of var_name
  [@@deriving show]

  type program = stmt list
  [@@deriving show]
end

module Rbs = struct
  type ty =
    | TySymbol
    | TyInteger
    | TySelf
    | TyNil
    | TyBot
    | TyLit of lit
    | TyClass of class_name
    | TyOr of ty * ty
    | TyAnd of ty * ty
    | TyMethAnd of ty * ty
    | TyFun of fun_ty
    | TyNot of ty
  and fun_ty = ty * ty
  [@@deriving show]

  type decl = Decl of class_name * class_name option * member list
  and member =
    | MemMeth of fun_name * ty 
    | MemInit of ty
    | MemClassMeth of fun_name * ty
    | MemAttr of var_name * ty
  [@@deriving show]

  type program = decl list
  [@@deriving show]
end

module MlSem = struct
  type expr =
    | Lit of lit
    | Var of var_name
    | Tuple of expr list
    | FieldAccess of expr * var_name
    | MatchWith of expr * (ty * expr) list
    | Fun of var_name * expr
    | RecordLit of expr option * (var_name * expr) list
    | IfIsThenElse of expr * ty * expr * expr
    | Assign of var_name * expr
    | Seq of expr * expr
    | LetIn of ty * expr * expr
    | LetMutIn of var_name * expr * expr
    | Cast of expr * ty
    | Constr of class_name * expr
    | App of expr * expr
    
  and ty =
    | TyVar of var_name
    | TyName of var_name
    | TyTuple of ty list
    | TyNot of ty
    | TyArrow of ty * ty
    | TyOr of ty * ty
    | TyAnd of ty * ty
    | TyRecord of ty option * (var_name * ty) list * record_tail
    | TyConstr of class_name * ty

  and record_tail =
    | NoTail
    | TailOpen
    | TailRow of row

  and row =
    | RowVar of var_name
    | RowOr of row * row
    | RowAnd of row * row
    | RowNot of row

  and top_level =
    | TLTy of (var_name * var_name list * ty) list
    | TLLet of var_name * expr
    | TLVal of var_name * ty

  [@@deriving show]
end