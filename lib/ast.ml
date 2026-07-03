type var_name = string [@@deriving show]
type fun_name = string [@@deriving show]
type class_name = string [@@deriving show]

type lit = 
  | LitTrue
  | LitFalse
  | LitSym of string
  | LitNum of int
[@@deriving show]

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
    | TyOr of ty * ty
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