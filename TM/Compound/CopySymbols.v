Require Import TM.Prelim.
Require Import TM.Basic.Mono TM.Basic.Multi.
Require Import TM.Combinators.Combinators.
Require Import TM.Mirror.
Require Import TM.Compound.TMTac.
Require Import TM.LiftMN.

Require Import FunInd.
Require Import Recdef.


(* This two-tape Turing machine copies the symbols from tape 0 to tape 1, until it reads a symbol x on tape 0 such that f(x)=true. *)
(* This machine is similar to MoveToSymbol, with the only difference, that it copies the read symbols to another tape. *)


Section CopySymbols.
  
  Variable sig : finType.
  Variable f : sig -> bool.

  Definition M1 : { M : mTM sig 2 & states M -> bool * bool} :=
    MATCH (ReadChar_multi _ Fin.F1)
          (fun b : option sig =>
             match b with
             | Some x =>
               (* First write the read symbol to tape 1 *)
               if f x
               then (* found the symbol: write it to tape 1; break and return true *)
                 Inject (Write x (false, true)) [|Fin.FS Fin.F1|]
               else (* wrong symbol: write it to tape 1 and move both tapes right and continue *)
                 Inject (Write x tt) [|Fin.FS Fin.F1|];;
                 MovePar _ R R (true, false)
             | _ => Nop _ _ (false, false) (* there is no such symbol, break and return false *)
             end).

  Definition M1_Fun : tape sig * tape sig -> tape sig * tape sig :=
    fun '(t1, t2) =>
      match t1, t2 with
      | midtape ls x rs as t1, t2 =>
        if (f x)
        then (t1, tape_write t2 (Some x))
        else (tape_move_right t1, tape_move_mono t2 (Some x, R))
      | t1, t2 => (t1, t2)
      end.

(*
End CopySymbols.
Section Test.
  Let f := fun x => Dec (x = L) : bool.
  Compute it (M1_Fun f) 0 (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 1 (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 2 (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 3 (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 4 (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 5 (midtape [L; N; R] N [R; N; L; N], niltape _).

  (* Actually simulating the machine... :-) *)
  Let M' := projT1 (M1 f).
  Compute map_opt (@ctapes _ _ _) (loopM (M := M') 7 (initc M' [|midtape [L; N; R] N [R; N; L; N]; niltape _|])).
  Compute map_opt (@ctapes _ _ _) (loopM (M := M') 7 (initc M' [|midtape [N; L; N; R] R [N; L; N]; rightof N []|])).
  Compute map_opt (@ctapes _ _ _) (loopM (M := M') 7 (initc M' [|midtape [R; N; L; N; R] N [L; N]; rightof R [N]|])).
  Compute map_opt (@ctapes _ _ _) (loopM (M := M') 7 (initc M' [|midtape [N; R; N; L; N; R] L [N]; rightof N [R; N]|])).
  Compute map_opt (@ctapes _ _ _) (loopM (M := M') 7 (initc M' [|midtape [N; R; N; L; N; R] L [N]; midtape [N; R; N] L []|])).

End Test.
*)

  Definition M1_Rel : Rel (tapes sig 2) (bool * bool * tapes sig 2) :=
    (fun tin '(yout, tout) =>
       (tout[@Fin.F1], tout[@Fin.FS Fin.F1]) = M1_Fun (tin[@Fin.F1], tin[@Fin.FS Fin.F1]) /\
       (
         (yout = (false, true)  /\ exists s, current tin[@Fin.F1] = Some s /\ f s = true ) \/
         (yout = (true, false)  /\ exists s, current tin[@Fin.F1] = Some s /\ f s = false) \/
         (yout = (false, false) /\ current tin[@Fin.F1] = None)
       )
    ).

  Lemma M1_Rel_functional : functional M1_Rel.
  Proof. hnf. unfold M1_Rel, M1_Fun. TMCrush (cbn [Vector.nth] in *); TMSolve 1. Qed.

  Lemma M1_RealiseIn :
    M1 ⊨c(7) M1_Rel.
  Proof.
    eapply RealiseIn_monotone.
    {
      unfold M1. eapply Match_RealiseIn. cbn. eapply Inject_RealisesIn; [vector_dupfree| eapply read_char_sem].
      instantiate (2 := fun o : option sig => match o with Some x => if f x then _ else _ | None => _ end).
      intros [ | ]; cbn.
      - destruct (f e); swap 1 2.
        + eapply Seq_RealiseIn. eapply Inject_RealisesIn; [vector_dupfree | eapply Write_Sem]. eapply MovePar_Sem.
        + cbn. eapply Inject_RealisesIn; [vector_dupfree | eapply Write_Sem].
      - cbn. eapply RealiseIn_monotone'. eapply Nop_total. omega.
    }
    {
      (cbn; omega).
    }
    {
      TMCrush repeat simpl_not_in; TMSolve 1.
      all: cbn in *; try congruence; eauto; subst.
      all: TMCrush idtac; TMSolve 6.
    }
  Qed.

  (*
   * The main loop of the machine.
   * Execute M1 in a loop until M1 returned [ None ] or [ Some true ]
   *)
  Definition CopySymbols : { M : mTM sig 2 & states M -> bool } := WHILE M1.
      
  Definition rlength (t : tape sig) :=
    match t with
    | niltape _ => 0
    | rightof _ _ => 0
    | midtape ls m rs => 1 + length rs
    | leftof r rs => 2 + length rs
    end.

  Definition rlength' (tin : tape sig * tape sig) : nat := rlength (fst tin).

  (* Function of M2 *)
  Function CopySymbols_Fun (tin : tape sig * tape sig) { measure rlength' tin } : tape sig * tape sig :=
    match tin with
      (midtape ls m rs as t1, t2) =>
      if f m
      then (t1, tape_write t2 (Some m))
      else CopySymbols_Fun (M1_Fun (t1, t2))
    |  (t1, t2) => (t1, t2)
    end.
  Proof.
    all: (intros; try now (cbn; omega)). destruct rs; cbn. rewrite teq1. cbn. omega. rewrite teq1. cbn. omega.
  Defined.

(* (* Test *)
End CopySymbols.
Section Test.
  Let f := fun x => Dec (x = L) : bool.
  Compute CopySymbols_Fun f (midtape [L; N; R] N [R; N; L; N], niltape _).
  Compute it (M1_Fun f) 4 (midtape [L; N; R] N [R; N; L; N], niltape _).
End Test.
*)

  (*
  Lemma M1_Fun_M2_None t :
    current t = None ->
    MoveToSymbol_Fun t = M1_Fun t.
  Proof.
    intros H1. destruct t; cbn in *; inv H1; rewrite MoveToSymbol_Fun_equation; auto.
  Qed.

  Lemma M1_None t :
    current t = None ->
    M1_Fun t = t.
  Proof.
    intros H1. unfold M1_Fun. destruct t; cbn in *; inv H1; auto.
  Qed.

  Lemma M1_true t x :
    current t = Some x ->
    f x = true ->
    M1_Fun t = t.
  Proof.
    intros H1 H2. unfold M1_Fun. destruct t; cbn in *; inv H1. rewrite H2. auto.
  Qed.
  
  Lemma M1_Fun_M2_true t x :
    current t = Some x ->
    f x = true ->
    MoveToSymbol_Fun t = M1_Fun t.
  Proof.
    intros H1 H2. destruct t; cbn in *; inv H1. rewrite MoveToSymbol_Fun_equation, H2. auto.
  Qed.

  Lemma MoveToSymbol_M1_false t x :
    current t = Some x ->
    f x = false ->
    MoveToSymbol_Fun (M1_Fun t) = MoveToSymbol_Fun t.
  Proof.
    intros H1 H2. functional induction MoveToSymbol_Fun t; cbn.
    - rewrite e0. rewrite MoveToSymbol_Fun_equation. rewrite e0. reflexivity.
    - rewrite e0. destruct rs; auto.
    - destruct _x; rewrite MoveToSymbol_Fun_equation; cbn; auto.
  Qed.

*)
  
  Definition CopySymbols_Rel : Rel (tapes sig 2) (bool * tapes sig 2) :=
    ignoreParam (fun tin tout => ((tout[@Fin.F1], tout[@Fin.FS Fin.F1]) = M1_Fun (tin[@Fin.F1], tin[@Fin.FS Fin.F1]))).

  Lemma CopySymbols_WRealise :
    CopySymbols ⊫ CopySymbols_Rel.
  Proof.
    eapply WRealise_monotone.
    {
      unfold CopySymbols. eapply While_WRealise. eapply Realise_WRealise, RealiseIn_Realise. eapply M1_RealiseIn.
    }
    {
      hnf. intros tin (y1&tout) H. hnf in *. destruct H as (t1&H&H2). hnf in *.
      induction H as [x | x y z IH1 _ IH2].
      {
        TMCrush idtac; TMSolve 6.
        all: repeat inv_pair; cbn in *; eauto.
      }
      {
        TMSimp. cbn in *. TMSimp.
        destruct H0 as [ [ H0 H0' ] | [ [H0 H0'] | [H0 H0']]]; inv H0;
          destruct H2 as [ [ H2 H2' ] | [ [H2 H2'] | [H2 H2']]]; inv H2;
            try destruct H0' as (s&H0'&H0''); destruct H2' as (s'&H2'&H2'').
        all: destruct h, h3; cbn in *; inv H0'; inv H2'.
        all: repeat match goal with [ H : context [if f ?s then _ else _] |- _] =>
                                    let E := fresh "E" in destruct (f s) eqn:E end.
        all: try destruct (f _) eqn:E1; try destruct (f _) eqn:E2; cbn in *.
        all: repeat inv_pair; cbn in *.
        all: spec_assert IH2; [ now (repeat split; eauto 6) | auto].
        all: try destruct l2 in *; cbn in *; try congruence.
        all: repeat match goal with [ E: f _ = _ |- _] => rewrite E in * end.
        all: repeat match goal with [ H : context [if f ?s then _ else _] |- _] =>
                                    let E := fresh "E" in destruct (f s) eqn:E end.
        all: try now (injection IH2 as IH2 IH2'; congruence).
        all: admit.
      }
    }
  Admitted.


  (*
  Lemma MoveToSymbol_Fun_tapesToList t : tapeToList (MoveToSymbol_Fun t) = tapeToList t .
  Proof.
    functional induction MoveToSymbol_Fun t; auto; simpl_tape in *; cbn in *; congruence.
  Qed.
  Hint Rewrite MoveToSymbol_Fun_tapesToList : tape.

  Lemma tape_move_niltape (t : tape sig) (D : move) : tape_move t D = niltape _ -> t = niltape _.
  Proof. destruct t, D; cbn; intros; try congruence. destruct l; congruence. destruct l0; congruence. Qed.

  Lemma MoveToSymbol_Fun_niltape t : MoveToSymbol_Fun t = niltape _ -> t = niltape _.
  Proof.
    intros H. remember (niltape sig) as N. functional induction MoveToSymbol_Fun t; subst; try congruence.
    - specialize (IHt0 H). destruct rs; cbn in *; congruence.
    (* - specialize (IHt0 H). destruct rs; cbn in *; congruence. *)
  Qed.
*)


  (** Termination *)

  Function CopySymbols_TermTime (t : tape sig) { measure rlength t } : nat :=
    match t with
    | midtape ls m rs => if f m then 8 else 8 + CopySymbols_TermTime (tape_move_right t)
    | _ => 8
    end.
  Proof.
    all: (intros; try now (cbn; omega)). destruct rs; cbn; omega.
  Qed.


  Lemma CopySymbols_terminates :
    projT1 CopySymbols ↓ (fun tin k => k = CopySymbols_TermTime (tin[@Fin.F1])).
  Proof.
    eapply While_terminatesIn.
    1-2: eapply Realise_total; eapply M1_RealiseIn.
    {
      eapply functional_functionalOn. apply M1_Rel_functional.
    }
    {
      intros tin k ->. destruct_tapes. cbn.
      destruct h eqn:E; cbn.
      - rewrite CopySymbols_TermTime_equation. exists [|h;h0|], false. cbn. do 2 eexists; repeat split; eauto 6; congruence.
      - rewrite CopySymbols_TermTime_equation. exists [|h;h0|], false. cbn. do 2 eexists; repeat split; eauto 6; congruence.
      - rewrite CopySymbols_TermTime_equation. exists [|h;h0|], false. cbn. do 2 eexists; repeat split; eauto 6; congruence.
      - destruct (f e) eqn:E2; cbn.
        + rewrite CopySymbols_TermTime_equation. exists [|h; tape_write h0 (Some e)|], false. cbn. rewrite E2.
          do 2 eexists; repeat split; eauto 6; congruence.
        + rewrite CopySymbols_TermTime_equation. exists [|tape_move_right h; tape_move_mono h0 (Some e, R)|], true. cbn. rewrite E2.
          destruct l0; rewrite E; cbn in *; do 2 eexists; repeat split; eauto 7.
    }
  Qed.
  
    
  (** Move to left *)

  Definition CopySymbols_L := Mirror CopySymbols.

  
End CopySymbols.