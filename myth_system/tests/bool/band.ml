type bool =
  | True
  | False

let band : bool -> bool -> bool |>
  { True => True => True
  ; True => False => False
  ; False => True => False
  ; False => False => False } = ?
