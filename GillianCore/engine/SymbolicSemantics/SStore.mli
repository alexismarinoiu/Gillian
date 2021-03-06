(*********************************
 * Interface for Symbolic stores *
**********************************)

type vt = SVal.M.t

type t

val copy : t -> t

val domain : t -> Containers.SS.t

val get : t -> Var.t -> Expr.t option

val get_unsafe : t -> Var.t -> Expr.t

val init : (Var.t * Expr.t) list -> t

val mem : t -> Var.t -> bool

val partition : t -> (Expr.t -> bool) -> Var.Set.t * Var.Set.t

val projection : t -> Var.t list -> t

val put : t -> Var.t -> Expr.t -> unit

val remove : t -> Var.t -> unit

val pp : Format.formatter -> t -> unit

val iter : t -> (Var.t -> Expr.t -> unit) -> unit

val fold : t -> (Var.t -> Expr.t -> 'a -> 'a) -> 'a -> 'a

val filter : t -> (Var.t -> Expr.t -> Expr.t option) -> unit

val vars : t -> Var.Set.t

val lvars : t -> Var.Set.t

val clocs : t -> Var.Set.t

val alocs : t -> Var.Set.t

val assertions : t -> Formula.t list

val substitution_in_place : SVal.SSubst.t -> t -> unit

val is_well_formed : t -> bool

val bindings : t -> (Var.t * vt) list

val to_ssubst : t -> SVal.SSubst.t

val symbolics : t -> Var.Set.t
