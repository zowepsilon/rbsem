%{

open Ast

let rec or_to_meth_and ty =
  match ty with
  | Rbs.TyOr (t1, tail) -> Rbs.TyMethAnd (t1, or_to_meth_and tail)
  | _ -> ty

%}

%token KW_CLASS
%token KW_DEF
%token KW_END
%token KW_SELF
%token KW_NIL
%token KW_INITIALIZE
%token KW_ATTR
%token KW_TRUE
%token KW_FALSE
%token KW_IF KW_THEN KW_ELSE
%token KW_RETURN
%token KW_INTEGER
%token KW_SYMBOL
%token KW_TOP
%token KW_BOT
%token EOF
%token <string> CLASS_IDENT
%token <string> IDENT
%token <string> SYMBOL
%token <int> INT
%token NEWLINE
%token LPAREN RPAREN
%token LT
%token DOT
%token AT
%token EQ
%token AMP
%token BAR
%token TILDE
%token PERCENT
%token COLON
%token ARROW

%right KW_RETURN
%right EQ
%left DOT

%right PERCENT
%right BAR
%right AMP
%right ARROW
%right TILDE

%start <Ruby.program> rb_program
%start <Rbs.program> rbs_program


%%

(* Ruby *)
rb_program: p=newline_list(stmt, EOF) { p }

stmt:
  KW_CLASS name=CLASS_IDENT sup=option(LT sup=CLASS_IDENT { sup })
  class_stmts=newline_list(class_stmt, KW_END)
    { Ruby.Stmt (name, sup, class_stmts) }


class_stmt:
  | KW_DEF f=IDENT LPAREN x=IDENT RPAREN e=expr_group KW_END
      { Ruby.CStmtMeth (f, x, e) }
  | KW_DEF KW_SELF DOT f=IDENT LPAREN x=IDENT RPAREN e=expr_group KW_END
      { Ruby.CStmtClassMeth (f, x, e) }
  | KW_DEF KW_INITIALIZE LPAREN x=IDENT RPAREN e=expr_group KW_END
      { Ruby.CStmtInit (x, e) }
  | KW_ATTR x=IDENT
      { Ruby.CStmtAttr x }

expr_group:
  | NEWLINE*
      { Ruby.Nil }
  | NEWLINE* exprs=nonempty_expr_group
      { let (first, rest) = List.hd exprs, List.tl exprs in
        List.fold_left (fun acc e -> Ruby.Seq (acc, e)) first rest
      }

nonempty_expr_group:
  | e=expr NEWLINE* { [e] }
  | e=expr NEWLINE+ rest=nonempty_expr_group { e::rest }

expr:
  | LPAREN e=expr RPAREN { e }
  | l=lit { Ruby.Lit l }
  | x=IDENT { Ruby.LocalVar x }
  | AT x=IDENT { Ruby.InstVar x }
  | x=CLASS_IDENT { Ruby.ClassVar x }
  | KW_SELF { Ruby.Self }
  | KW_NIL { Ruby.Nil }
  | r=expr DOT f=IDENT LPAREN a=expr RPAREN { Ruby.Call (r, f, a) }
  | x=IDENT EQ e=expr { Ruby.LocalAssign (x, e) }
  | AT x=IDENT EQ e=expr { Ruby.InstAssign (x, e) }
  | KW_IF b=expr if_sep e1=expr_group KW_ELSE e2=expr_group KW_END { Ruby.IfThenElse (b, e1, e2) }
  | KW_RETURN e=expr { Ruby.Return e }

if_sep:
  | NEWLINE {}
  | KW_THEN {}

lit:
  | i=INT     { LitNum i }
  | KW_FALSE  { LitFalse }
  | KW_TRUE   { LitTrue }
  | s=SYMBOL  { LitSym s }

(* RBS *)
rbs_program: p=list(declaration) EOF { p }

declaration:
  KW_CLASS name=CLASS_IDENT sup=option(LT sup=CLASS_IDENT { sup })
  members=list(member) KW_END
    { Rbs.Decl (name, sup, members) } 

member:
  | KW_DEF f=IDENT COLON t=ty             { Rbs.MemMeth (f, or_to_meth_and t) }
  | KW_DEF KW_INITIALIZE COLON t=ty       { Rbs.MemInit (or_to_meth_and t) }
  | KW_DEF KW_SELF DOT f=IDENT COLON t=ty { Rbs.MemClassMeth (f, or_to_meth_and t) }
  | AT x=IDENT COLON t=ty                 { Rbs.MemAttr (x, t) }  

ty:
  | LPAREN t=ty RPAREN  { t }
  | KW_SYMBOL           { Rbs.TySymbol }
  | KW_INTEGER          { Rbs.TyInteger }
  | KW_SELF             { Rbs.TySelf }
  | KW_NIL              { Rbs.TyNil }
  | KW_TOP              { Rbs.TyNot Rbs.TyBot }
  | KW_BOT              { Rbs.TyBot }
  | l=lit               { Rbs.TyLit l }
  | c=CLASS_IDENT       { Rbs.TyClass c }
  | t1=ty BAR t2=ty     { Rbs.TyOr (t1, t2) }
  | t1=ty AMP t2=ty     { Rbs.TyAnd (t1, t2) }
  | t1=ty PERCENT t2=ty { Rbs.TyMethAnd (t1, t2) }
  | f=fun_ty            { f }
  | TILDE t=ty          { Rbs.TyNot t }

%inline fun_ty:
  LPAREN t=ty IDENT RPAREN ARROW u=ty { Rbs.TyFun (t, u) }

(* utils *)
newline_list(X, END):
  | NEWLINE* END { [] }
  | NEWLINE* l=nonempty_newline_list(X, END) { l }

nonempty_newline_list(X, END):
  | x=X NEWLINE* END { [x] }
  | x=X NEWLINE+ rest=nonempty_newline_list(X, END) { x::rest }

