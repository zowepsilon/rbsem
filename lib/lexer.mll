{
open Parser

(* shamelessly borrowed from the OCaml compiler *)
(* https://github.com/ocaml/ocaml/blob/5bd95845db7eb2e9d091444e63e55eefa7669099/parsing/lexer.mll#L344 *)
let update_loc lexbuf ~lines ~chars =
  let open Lexing in
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <- { pos with
    pos_lnum = pos.pos_lnum + lines;
    pos_bol = pos.pos_cnum - chars;
  }
}

let start_digit = ['0'-'9']
let inner_digit = ['0'-'9' '_']
let int = start_digit inner_digit*
let float = '-'? start_digit inner_digit* '.' inner_digit* (['e' 'E'] ['+' '-']? start_digit inner_digit*)?

let ident = ['a'-'z' '_'] ['a'-'z' 'A'-'Z' '_' '0'-'9' '\'']*
let constr = ['A'-'Z'] ['a'-'z' 'A'-'Z' '_' '0'-'9' '\'' ]*


rule token = parse
  | [' ' '\t']        { token lexbuf }
  | '\n'+ as n        { update_loc lexbuf ~lines:(String.length n) ~chars:0; NEWLINE }
  | '('               { LPAREN }
  | ')'               { RPAREN }
  | '='               { EQ }
  | '<'               { LT }
  | '.'               { DOT }
  | '@'               { AT }
  | '|'               { BAR }
  | '&'               { AMP }
  | '~'               { TILDE }
  | '%'               { PERCENT }
  | ':'               { COLON }
  | "->"              { ARROW }
(*| ';'               { SEQ }*)
(*| ','               { COMMA }*)
(*| '"'               { string "" lexbuf }*)
  | '#'               { comment lexbuf; token lexbuf }
  | "class"           { KW_CLASS }
  | "def"             { KW_DEF }
  | "end"             { KW_END }
  | "self"            { KW_SELF }
  | "nil"             { KW_NIL }
  | "initialize"      { KW_INITIALIZE }
  | "attr"            { KW_ATTR }
  | "true"            { KW_TRUE }
  | "false"           { KW_FALSE }
  | "if"              { KW_IF }
  | "then"            { KW_THEN }
  | "else"            { KW_ELSE }
  | "return"          { KW_RETURN }
  | "Integer"         { KW_INTEGER }
  | "Symbol"          { KW_SYMBOL }
  | "bot"             { KW_BOT }
  | ':' (ident as s)  { SYMBOL s }
  | ident as i        { IDENT i }
  | constr as i       { CLASS_IDENT i }
  | int as i          { INT (int_of_string i) }
  | eof               { EOF }

and comment = parse
  | "\n" { () }
  | eof { () }
  | _ { comment lexbuf }

(*
and string contents = parse
  | '"' { STRING contents }
  | [^ '"']+ as str { string (contents ^ str) lexbuf }
  | eof { failwith "string literal is never closed" }
*)