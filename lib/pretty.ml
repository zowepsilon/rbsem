open Ast

let prec_expr: MlSem.expr -> int =
  function
  | Lit _
  | Var _
  | Tuple _
  | RecordLit _     -> 0
  | Constr _        -> 1
  | FieldAccess _   -> 2
  | App _           -> 3
  | Cast _          -> 4
  | Assign _        -> 5
  | IfIsThenElse _  -> 6
  | LetIn _
  | LetMutIn _      -> 7
  | MatchWith _     -> 8
  | Seq _           -> 9
  | Fun _           -> 10

let prec_ty: MlSem.ty -> int =
  function
  | TyBind _
  | TyVar _
  | TyName _
  | TySymbol _
  | TyEnum
  | TyInt
  | TyEmpty
  | TyRecord _
  | TyTuple _   -> 0
  | TyConstr _  -> 1
  | TyNot _     -> 2
  | TyAnd _     -> 3
  | TyOr _      -> 4
  | TyArrow _   -> 5

let prec_row: MlSem.row -> int =
  function
  | RowVar _ -> 0
  | RowNot _ -> 1
  | RowAnd _ -> 2
  | RowOr  _ -> 3

(* map_without_last f [a; b; c] = [f a; f b; c] *)
let rec map_without_last (f : 'a -> 'a) (xs : 'a list) : 'a list =
  match xs with
  | [] | [_] -> xs
  | hd :: tl -> f hd :: map_without_last f tl

let max_line_width = 100
let indent_size = 2

let append_prefix (prefix : string) (display : (int * string) list) : (int * string) list =
  match display with
  | [] -> assert false
  | (i, line) :: tail -> (i, prefix ^ line) :: tail

let append_suffix (suffix : string) (display : (int * string) list) : (int * string) list =
  match List.rev display with
  | [] -> assert false
  | (i, line) :: head -> (i, line ^ suffix) :: head |> List.rev

let len_of_display (len : int) (elmt : (int * string) list) : int =
  match elmt with
  | [_, line] -> len + String.length line
  | _ -> len + max_line_width

let incr_indent (indent, line) = indent+1, line

let rec display_expr (e: MlSem.expr) : (int * string) list =
  match e with
  | Lit l -> [0, display_lit l]
  | Var x -> [0, x]
  | Tuple elmts ->
      let elmts = List.map display_expr elmts in
      let elmts = map_without_last (append_suffix ", ") elmts in
      let len = List.fold_left len_of_display 0 elmts in
      let elmts = List.flatten elmts in
      if len+2 <= max_line_width
        then [0, "(" ^ String.concat "" (List.map snd elmts) ^ ")"]
        else
          let elmts = List.map incr_indent elmts in 
          [0, "("] @ elmts @ [0, ")"]
  | FieldAccess (reciever, field) ->
      paren_expr e reciever |> append_suffix ("." ^ field)
  | MatchWith (scrutinee, branches) ->
      let scrutinee = paren_if_seq_expr scrutinee
      in
      let branches = branches |> List.map @@ fun (pat, branch) ->
        display_ty pat |> append_prefix "| " |> append_suffix " -> ",
        display_expr branch
      in
      let scrutinee = 
        if len_of_display 0 scrutinee + 11 <= max_line_width
          then [0, "match " ^ (List.hd scrutinee |> snd) ^ " with"]
        else [0, "match"] @ List.map incr_indent scrutinee @ [0, "with"]
      in
      let branches = branches |> List.map @@ fun (pat, branch) ->
        let len_pat = len_of_display 0 pat in
        let len_branch = len_of_display 0 branch in
        if len_pat + len_branch <= max_line_width then (
          let pat = List.hd pat |> snd in
          let branch = List.hd branch |> snd in
          [0, pat ^ branch]
        ) else
          pat @ List.map (Fun.compose incr_indent incr_indent) branch
      in
      let branches = List.flatten branches in
      scrutinee @ branches @ [0, "end"]
  | Fun (x, e) ->
      let e = display_expr e in
      let prefix = "fun " ^ x ^ " -> " in
      if len_of_display 0 e + String.length prefix <= max_line_width then (
        let e = List.hd e |> snd in
        [0, prefix ^ e]
      ) else
        [0, prefix] @ List.map incr_indent e
  | RecordLit (None, []) -> [0, "{}"]
  | RecordLit (Some old, []) -> paren_if_seq_expr old |> append_prefix "{ " |> append_suffix " with }"
  | RecordLit (old, fields) ->
      let old =
        match old with
        | None -> [0, "{ "]
        | Some old -> paren_if_seq_expr old |> append_prefix "{ " |> append_suffix " with "
      in
      let fields = fields |> List.map @@ fun (name, value) ->
        (name ^ " = "), (paren_if_seq_expr value)
      in
      let fields = fields |> map_without_last @@ fun (name, value) ->
        name, append_suffix "; " value
      in
      let fields = fields |> List.map @@ fun (name, value) ->
        let len_name = String.length name in
        let len_value = len_of_display 0 value in
        if len_name+len_value <= max_line_width then (
          let value = List.hd value |> snd in
          [0, name ^ value]
        ) else (
          [0, name] @ List.map incr_indent value
        )
      in
      let fields = List.flatten fields in
      let len_old = len_of_display 0 old in
      let len_fields = len_of_display 0 fields in
      if len_old+len_fields+2 <= max_line_width then (
        let old = List.hd old |> snd in
        [0, old ^ String.concat "" (List.map snd fields) ^ " }"]
      ) else
          let elmts = List.map incr_indent fields in 
          old @ elmts @ [0, "}"]
  | IfIsThenElse (cond, test_ty, branch1, branch2) ->
      let cond = paren_expr e cond in
      let test_ty = display_ty test_ty in
      let branch1 = paren_expr e branch1 in
      let branch2 = paren_expr e branch2 in

      let len_cond = len_of_display 0 cond in
      let len_test_ty = len_of_display 0 test_ty in
      
      let cond =
        if len_cond + len_test_ty + 7 <= max_line_width then (
          let cond = List.hd cond |> snd in
          let test_ty = List.hd test_ty |> snd in
          [0, "if " ^ cond ^ " is " ^ test_ty]
        ) else (
          let test_ty = test_ty |> append_prefix "is " in
          [0, "if"]
            @ List.map incr_indent cond
            @ List.map incr_indent test_ty
        )
      in
      let branch1 =
        if len_of_display 0 branch1 + 5 <= max_line_width then (
          let branch1 = List.hd branch1 |> snd in
          [1, "then " ^ branch1]
        ) else [1, "then"] @ List.map (Fun.compose incr_indent incr_indent) branch1
      in
      let branch2 =
        if len_of_display 0 branch2 + 5 <= max_line_width then (
          let branch2 = List.hd branch2 |> snd in
          [1, "else " ^ branch2]
        ) else [1, "else"] @ List.map (Fun.compose incr_indent incr_indent) branch2
      in
      cond @ branch1 @ branch2
  | Assign (x, value) ->
      let x = x ^ " = " in
      let value = paren_expr e value in
      if String.length x + len_of_display 0 value <= max_line_width then
        let value = List.hd value |> snd in
        [0, x ^ value]
      else
        [0, x] @ List.map incr_indent value
  | Seq (e1, e2) ->
      let e1 =
        match e1 with
        | IfIsThenElse _ ->
            display_expr e1 |> append_prefix "(" |> append_suffix ")" 
        | _ when prec_expr e1 > prec_expr e ->
            display_expr e1 |> append_prefix "(" |> append_suffix ")"
        | _ -> display_expr e1
      in
      let e2 =
        match e2 with
        | IfIsThenElse _ ->
            display_expr e2 |> append_prefix "(" |> append_suffix ")"
        | _ when prec_expr e2 > prec_expr e ->
            display_expr e2 |> append_prefix "(" |> append_suffix ")"
        | _ -> display_expr e2
      in
      (append_suffix ";" e1) @ e2 

and display_ty (t : MlSem.ty) : (int * string) list =
  match t with
  | TyBind x -> [0, x]
  | TyVar a -> [0, "'" ^ a]
  | TyName x -> [0, x]
  | TySymbol s -> [0, s]
  | TyEnum -> [0, "enum"]
  | TyInt -> [0, "int"]
  | TyEmpty -> [0, "empty"]
  | TyNot TyEmpty -> [0, "any"]
  | TyTuple _ -> assert false
  | TyNot t' ->
      if prec_ty t' > prec_ty t
        then display_ty t' |> append_prefix "~(" |> append_suffix ")"
        else display_ty t' |> append_prefix "~"
  | TyArrow _ -> assert false
  | TyOr _ -> assert false
  | TyAnd _ -> assert false
  | TyRecord _ -> assert false
  | TyConstr (constr, t) ->
      display_ty t |> append_prefix (constr ^ "(") |> append_suffix ")"

and paren_expr (main_expr : MlSem.expr) (sub_expr : MlSem.expr) : (int * string) list =
  if prec_expr sub_expr <= prec_expr main_expr
  then display_expr sub_expr
  else
    let sub_display = display_expr sub_expr in
    if List.length sub_display = 1
      then sub_display |> append_prefix "(" |> append_suffix ")"
      else [0, "("] @ List.map incr_indent sub_display @ [0, ")"]

and paren_if_seq_expr (sub_expr : MlSem.expr) : (int * string) list =
  let is_seq =
    match sub_expr with
    | Seq _
    | Fun _ -> true
    | _ -> false
  in
  if not is_seq
  then display_expr sub_expr
  else
    let sub_display = display_expr sub_expr in
    if List.length sub_display = 1
      then sub_display |> append_prefix "(" |> append_suffix ")"
      else [0, "("] @ List.map incr_indent sub_display @ [0, ")"]

let rec print_display : (int * string) list -> unit =
  function
  | [] -> ()
  | (indent, line) :: rest ->
      String.make (indent_size * indent) ' ' |> print_string;
      print_endline line;
      print_display rest


let test1 () =
  let open MlSem in
  let body1 = Tuple [Var "x"; Var "yyyyyyyyyyyyyyyy"; Var "z"] in
  let body2 = Tuple [Var "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; Var "yyyyyyyyyyyyyyyy"; Var "z"] in
  let expr = MatchWith (Var "hihi", [
    TyNot (TyConstr ("C", TyBind "x")), body1;
    TyNot (TyConstr ("C", TyBind "x")), body2;
  ]) in
  let expr = Fun ("hihi", expr) in
  display_expr expr |> print_display

let test2 () =
  let open MlSem in
  let body2 = Tuple [Var "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; Var "yyyyyyyyyyyyyyyy"; Var "z"] in
  let expr = RecordLit (Some body2, [
    "x", Lit LitTrue;
    "y", Lit LitFalse;
  ]) in
  display_expr expr |> print_display

let test3 () =
  let open MlSem in
  let expr = IfIsThenElse (Var "xxkisqojdiqjsidojqsidjoisqjdiqsjodjqsoidxxkisqojdiqjsidojqsidjoisqjdiqsjodjqsoidxxkisqojdiqjsidojqsidjoisqjdiqsjodjqsoid", TyVar "a", Var "y", Var "z") in
  display_expr expr |> print_display

let test4 () =
  let open MlSem in
  let s1 = Assign ("x", Seq (Var "y", Var "g")) in
  let s2 = Assign ("z", Var "w") in
  let s3 = IfIsThenElse (Var "x", TyVar "a", Seq (Var "y", Var "r"), Var "z") in

  let s4 = Assign ("a", Var "v") in
  let expr = Seq (Seq (s1, s2), Seq (s3, s4)) in
  display_expr expr |> print_display