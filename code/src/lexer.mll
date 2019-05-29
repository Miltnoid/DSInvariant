{
open Lexing
open Parser
open MyStdlib

exception Lexer_error of string

let reserved_words : (string * Parser.token) list =
  [ ("fun", FUN)
  ; ("match", MATCH)
  ; ("with", WITH)
  ; ("type", TYPE)
  ; ("of", OF)
  ; ("let", LET)
  (*; ("in", IN)*)
  (*; ("rec", REC)*)
  ; ("unit", UNIT)
  ; ("maintains", MAINTAINS)
  ; ("struct", STRUCT)
  ; ("sig", SIG)
  ; ("end", END)
  ; ("forall", FORALL)
  ; ("val", VAL)
  ; ("binding", BINDING)
  ; ("mu", MU)
  ; ("fix", FIX)
  ; ("accumulating", ACCUMULATING)
  ]

let symbols : (string * Parser.token) list =
  [ ("=", EQ)
    (*("?", HOLE)*)
    (*; ("|>", IMPLIES)*)
  ; ("->", ARR)
  (*; ("=>", FATARR)*)
  ; (".", DOT)
  ; (",", COMMA)
  ; (":", COLON)
  ; (";", SEMI)
  ; ("*", STAR)
  ; ("|", PIPE)
  ; ("(", LPAREN)
  ; (")", RPAREN)
  (*; ("{", LBRACE)
    ; ("}", RBRACE)*)
  (*; ("[", LBRACKET)
    ; ("]", RBRACKET)
    ; ("_", UNDERSCORE)*)
  ]

let create_token lexbuf =
  let str = lexeme lexbuf in
  match List.Assoc.find ~equal:String.equal reserved_words str with
  | None   -> LID str
  | Some t -> t

let create_symbol lexbuf =
  let str = lexeme lexbuf in
  match List.Assoc.find ~equal:String.equal symbols str with
  | None   -> raise @@ Lexer_error ("Unexpected token: " ^ str)
  | Some t -> t

(*let create_proj lexbuf =
  let str = lexeme lexbuf in
  let len = String.length str in
  PROJ (int_of_string (String.sub str ~pos:1 ~len:(len - 1)))*)
}

let newline    = '\n' | ('\r' '\n') | '\r'
let whitespace = ['\t' ' ']
let lowercase  = ['a'-'z']
let uppercase  = ['A'-'Z']
let character  = uppercase | lowercase
let digit      = ['0'-'9']

rule token = parse
  | eof   { EOF }
  | digit { INT (int_of_string (lexeme lexbuf)) }
  (*| "#" digit+ { create_proj lexbuf } *)
  | "(*" {comments 0 lexbuf}
  | whitespace+ | newline+    { token lexbuf }
  | lowercase (digit | character | '_')* { create_token lexbuf }
  | uppercase (digit | character | '_')* { UID (lexeme lexbuf) }
  | '?' | "|>" | '=' | "->" | "=>" | '*' | ',' | ':' | ';' | '|' | '(' | ')'
  | '{' | '}' | '[' | ']' | '_' | '.'
    { create_symbol lexbuf }
  | _ as c { raise @@ Lexer_error ("Unexpected character: " ^ Char.escaped c) }

and comments level = parse
  | "*)" { if level = 0 then token lexbuf
	   else comments (level-1) lexbuf }
  | "(*" { comments (level+1) lexbuf}
  | [^ '\n'] { comments level lexbuf }
  | "\n" { comments level lexbuf }
  | eof	 { failwith "Comments are not closed" }
