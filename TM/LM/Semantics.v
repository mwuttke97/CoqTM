(** * Semantics of the Heap Machine *)

Require Import TM.Prelim TM.Relations.
Require Import FunInd.


(** Types *)
Inductive Tok := varT (n :nat) | appT | lamT | retT.
Definition Pro := list Tok.
Definition HAd : Type := nat.
Definition HClos : Type := HAd * Pro.
Definition HEnt : Type := option (HClos * HAd).
Definition Heap : Type := list HEnt.

Section Semantics.

  Definition put H e : HAd * Heap := (|H|, H++[e]).

  Definition tailRecursion : HClos -> list HClos -> list HClos :=
    fun '(a, P) T =>
      match P with
      | [] => T
      | _ => (a, P) :: T
      end.


  Definition state : Type := list HClos * list HClos * Heap.

  Fixpoint jumpTarget (k:nat) (Q:Pro) (P:Pro) : option (Pro*Pro) :=
    match P with
    | retT :: P' => match k with
                   | 0 => Some (Q,P')
                   | S k' => jumpTarget k' (Q++[retT]) P'
                   end
    | lamT :: P' => jumpTarget (S k) (Q++[lamT]) P'
    | t :: P' => jumpTarget k (Q++[t]) P' (* either [varT n] or [appT] *)
    | [] => None
    end.

  Fixpoint lookup (H:Heap) (a:nat) (n:nat) : option HClos :=
    match nth_error H a with
    | Some (Some (g, b)) =>
      match n with
      | 0 => Some g
      | S n' => lookup H b n'
      end
    | _ => None
    end.

  Lemma lookup_eq H a n :
    lookup H a n =
    match nth_error H a with
    | Some (Some (g, b)) =>
      match n with
      | 0 => Some g
      | S n' => lookup H b n'
      end
    | _ => None
    end.
  Proof. destruct n; auto. Qed.

  
  Inductive step : state -> state -> Prop :=
  | step_pushVal P P' Q a T V H :
      jumpTarget O [] P = Some (Q, P') ->
      step ((a, (lamT :: P)) :: T, V, H) (tailRecursion (a, P') T, (a, Q) :: V, H)
  | step_beta a b g P Q H H' c T V :
      put H (Some (g, b)) = (c, H') ->
      step ((a, (appT :: P)) :: T, g :: (b, Q) :: V, H) ((c, Q) :: tailRecursion (a, P) T, V, H')
  | step_load P a x g T V H :
      lookup H a x = Some g ->
      step ((a, (varT x :: P)) :: T, V, H) (tailRecursion (a, P) T, g :: V, H)
  .

  Definition halt_state (s : state) : Prop :=
    forall s', ~ step s s'.


  Definition steps : state -> state -> Prop := star step.

  Inductive steps_k : state -> nat -> state -> Prop :=
  | steps_k_O s : steps_k s 0 s
  | steps_k_S s s' s'' k : step s s' -> steps_k s' k s'' -> steps_k s (S k) s''.

  Lemma steps_k_steps (s s' : state) (k : nat) :
    steps_k s k s' -> steps s s'.
  Proof. induction 1; econstructor; eauto. Qed.

  Lemma steps_steps_k (s s' : state) :
    steps s s' -> exists k, steps_k s k s'.
  Proof.
    intros Steps. induction Steps as [ | s s' s'' HStep_k Steps (k&IH)].
    - eexists. constructor 1.
    - eexists. econstructor 2; eauto.
  Qed.

  Definition halts (s : state) : Prop :=
    exists s', steps s s' /\ halt_state s'.

  Definition halts_k (s : state) (k : nat) : Prop :=
    exists s', steps_k s k s' /\ halt_state s'.

  Definition step_fun : state -> option state :=
    fun '(T, V, H) =>
      match T with
      | (a, (lamT :: P)) :: T =>
        match jumpTarget O [] P with
        | Some (Q, P') =>
          Some (tailRecursion (a, P') T, (a, Q) :: V, H)
        | _ => None
        end
      | (a, (appT :: P)) :: T =>
        match V with
        | g :: (b, Q) :: V =>
          let (c, H') := put H (Some (g, b)) in
          Some ((c, Q) :: tailRecursion (a, P) T, V, H')
        | _ => None
        end
      | (a, (varT x :: P)) :: T =>
        match lookup H a x with
        | Some g => Some (tailRecursion (a, P) T, g :: V, H)
        | _ => None
        end
      | _ => None
      end.

  Functional Scheme step_fun_ind := Induction for step_fun Sort Prop.

  Lemma step_step_fun : forall s s', step s s' -> step_fun s = Some s'.
  Proof.
    intros s s' HStep. induction HStep; cbn in *; auto.
    - now rewrite H0.
    - now inv H0.
    - now rewrite H0.
  Qed.

  Lemma step_fun_step : forall s s', step_fun s = Some s' -> step s s'.
  Proof.
    intros s. functional induction (step_fun s); intros s' HEq; cbn; try congruence.
    - inv HEq. now econstructor.
    - inv HEq. now econstructor.
    - inv HEq. now econstructor.
  Qed.

  Lemma step_iff : forall s s', step s s' <-> step_fun s = Some s'.
  Proof. split; auto using step_step_fun, step_fun_step. Qed.

  Lemma step_functional : functional step.
  Proof. hnf. intros x z1 z2 H1 % step_iff H2 % step_iff. congruence. Qed.

  
  Definition is_halt_state (s : state) : bool :=
    match step_fun s with
    | Some s' => false
    | None => true
    end.
  
  Lemma is_halt_state_halt (s : state) :
    is_halt_state s = true -> halt_state s.
  Proof.
    unfold is_halt_state, halt_state in *.
    intros H.
    destruct (step_fun s) eqn:EStep; inv H.
    intros s' H % step_iff. congruence.
  Qed.

  Lemma halt_state_is_halt_state (s : state) :
    halt_state s -> is_halt_state s = true.
  Proof.
    unfold is_halt_state, halt_state in *.
    intros H.
    destruct (step_fun s) eqn:EStep; auto.
    apply step_iff in EStep. specialize (H s0). tauto.
  Qed.

  Lemma is_halt_state_correct (s : state) :
    is_halt_state s = true <-> halt_state s.
  Proof. intros. split; auto using is_halt_state_halt, halt_state_is_halt_state. Qed.

  Lemma step_is_halt_state (s s' : state) :
    step s s' -> is_halt_state s = false.
  Proof.
    intros H. destruct (is_halt_state) eqn:EHaltState; auto. exfalso.
    apply is_halt_state_correct in EHaltState. eapply EHaltState; eauto.
  Qed.

  Global Instance halt_state_dec : forall s, dec (halt_state s).
  Proof. intros s. eapply dec_transfer. apply is_halt_state_correct. auto. Defined.

  Lemma halt_state_steps s s' :
    halt_state s -> steps s s' -> s' = s.
  Proof.
    intros HHalt HSteps. hnf in HHalt.
    destruct HSteps; auto. now specialize (HHalt _ H).
  Qed.

  Lemma halt_state_steps_k s s' k :
    halt_state s -> steps_k s k s' -> s' = s /\ k = 0.
  Proof.
    intros HHalt HSteps. hnf in HHalt.
    destruct HSteps; auto. now specialize (HHalt _ H).
  Qed.
 
End Semantics.