open Rbsem

let arg_params = []

let ok = ref true
let exit () = if !ok then exit 0 else exit 255

type 'a rule = (Lexing.lexbuf -> Parser.token) -> Lexing.lexbuf -> 'a

let printerr err msg = Printf.printf "\x1b[31m%s:\x1b[0m %s\n" err msg

let syntax_error_message (lexbuf : Lexing.lexbuf) : string =
  let start = Lexing.lexeme_start_p lexbuf in
  let start_col = start.pos_cnum - start.pos_bol in
  if start.pos_fname = "" then
    "at line "
    ^ string_of_int start.pos_lnum
    ^ ", column " ^ string_of_int start_col ^ "."
  else
    "in file \"" ^ start.pos_fname ^ "\" at line "
    ^ string_of_int start.pos_lnum
    ^ ", column " ^ string_of_int start_col ^ "."

let parse_with (rule : 'a rule) (chan : in_channel) (filename : string) :
    'a option =
  let lexbuf = Lexing.from_channel chan in
  Lexing.set_filename lexbuf filename;
  try Some (rule Lexer.token lexbuf)
  with Parser.Error ->
    printerr "Syntax error" (syntax_error_message lexbuf);
    None

let run_file (filename : string) : unit =
  let chan = open_in filename in
  match parse_with Parser.rb_program chan filename with
  | None -> ok := false
  | Some program -> 
      print_endline (Ast.Ruby.show_program program);
      exit ()

let run () =
  let filename = ref "" in
  Arg.parse arg_params (fun s -> filename := s) "";
  if !filename = "" then printerr "no file provided" "please provide a file"
  else run_file !filename

let () =
  run ();
  exit ()
