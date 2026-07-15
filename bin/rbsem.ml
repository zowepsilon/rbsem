open Rbsem

let to_stdout = ref false
let output_file = ref ""
let arg_params = [
  ("-o", Arg.Set_string output_file, "Output file");
  ("--", Arg.Set to_stdout, "Output to stdout");
]

let ok = ref true
let exit () = if !ok then exit 0 else exit 255
let fail () = ok := false; exit ()

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

let parse_with (rule : 'a rule) (ignore_newlines: bool) (chan : in_channel) (filename : string) : 'a =
  let lexbuf = Lexing.from_channel chan in
  Lexing.set_filename lexbuf filename;
  Lexer.ignore_newlines := ignore_newlines;
  try rule Lexer.token lexbuf
  with Parser.Error ->
    printerr "Syntax error" (syntax_error_message lexbuf);
    fail ()

let run_file (root : string) : unit =
  let rb_file = root ^ ".rb" in
  let rbs_file = root ^ ".rbs" in
  let rb_chan = open_in rb_file in
  let rbs_chan = open_in rbs_file in
  let filename =
    if !output_file = ""
      then (root ^ ".ml")
      else !output_file
  in
  let out_chan =
    if !to_stdout
      then stdout
    else if !output_file = ""
      then open_out (root ^ ".ml")
    else
      open_out !output_file
  in
  let rb_program = parse_with Parser.rb_program false rb_chan rb_file in
  let rbs_program = parse_with Parser.rbs_program true rbs_chan rbs_file in
  let inheritance_registry = Translation.Rbs.build_inheritance_registry rbs_program in
  output_string out_chan Translation.prelude;
  rbs_program
    |> Translation.Rbs.program inheritance_registry
    |> List.concat_map Pretty.display_top_level
    |> Pretty.print_display out_chan;
  output_string out_chan "\n";
  rb_program
    |> Translation.Ruby.program inheritance_registry
    |> List.concat_map Pretty.display_top_level
    |> Pretty.print_display out_chan;
  close_out out_chan;
  if not !to_stdout then print_endline ("Wrote output to " ^ filename ^ ".");
  exit ()

let run () =
  let filename = ref "" in
  Arg.parse arg_params (fun s -> filename := s) "";
  let filename = !filename in
  if filename = "" then (printerr "no file provided" "please provide a file"; fail ());
  let root =
    if String.ends_with ~suffix:".rb" filename
    then String.sub filename 0 (String.length filename - 3)
    else if String.ends_with ~suffix:".rbs" filename
    then String.sub filename 0 (String.length filename - 4)
    else (printerr "wrong file type" "file must be in .rb or .rbs"; fail ())
  in
  run_file root

let () =
  run ()