type nat =
  | O
  | S of nat

type list =
  | Nil
  | Cons of nat * list

let take : nat -> list -> list |>
  { 0 => ( [] => []
         | [1] => []
         | [0;1] => []
         | [1;0;1] => [] )
  | 1 => ( []    => []
         | [1]   => [1]
         | [0;1] => [0]
         | [1;0;1] => [1] )
  | 2 => ( []    => []
         | [1]   => [1]
         | [0;1] => [0;1]
         | [1;0;1] => [1;0] )
  } = ?
