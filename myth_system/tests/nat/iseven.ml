type nat =
  | O
  | S of nat

type bool =
  | True
  | False

let div2 : nat -> bool |>
  { 0 => True
  | 1 => False
  | 2 => True
  | 3 => False
  } = ?
