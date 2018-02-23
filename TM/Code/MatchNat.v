Require Import TM.Code.CodeTM.
Require Import TM.Basic.Mono TM.Basic.Nop TM.Basic.Multi.
Require Import TM.Combinators.Combinators.
Require Import TM.LiftMN TM.LiftSigmaTau.
Require Import TM.Compound.TMTac.

(* Basic pattern matching *)
Section MatchNat.

  Definition MatchNat_Rel : Rel (tapes bool^+ 1) (bool * tapes bool^+ 1) :=
    Mk_R_p (if? (fun (tin tout : tape bool^+) =>
                   forall n : nat,
                     tin ≂ n ->
                     exists n' : nat, n = S n' /\ tout ≂ n')
              ! (fun (tin tout : tape bool^+) =>
                   forall n : nat,
                     tin ≂ n ->
                     n = O /\ tout ≂ O)).

  Definition MatchNat : { M : mTM bool^+ 1 & states M -> bool } :=
    MATCH (Read_char _)
          (fun o => match o with
                 | Some (inr true)  => Write (inl START) tt;; Move _ R true  (* S *)
                 | Some (inr false) => mono_Nop _ false (* O *)
                 | _ => mono_Nop _ true (* invalid input *)
                 end).

  Lemma MatchNat_Sem : MatchNat ⊨c(5) MatchNat_Rel.
  Proof.
    eapply RealiseIn_monotone.
    {
      unfold MatchNat. eapply Match_RealiseIn. cbn. eapply read_char_sem.
      instantiate (2 := fun o : option bool^+ =>
                          match o with Some (inr true) => _ | Some (inr false) => _ | _ => _ end).
      cbn. intros [ s | ]; cbn.
      - destruct s as [ start | s]; cbn.
        + eapply RealiseIn_monotone'. eapply mono_Nop_Sem. omega.
        + destruct s.
          * eapply Seq_RealiseIn; [eapply Write_Sem | eapply Move_Sem].
          * eapply mono_Nop_Sem.
      - eapply RealiseIn_monotone'. eapply mono_Nop_Sem. omega.
    }
    { cbn. omega. }
    {
      intros tin (yout&tout) H. cbn in yout.
      destruct H as (H1&(t&(H2&H3)&H4)); hnf in *. subst.
      destruct_tapes; cbn in *.
      destruct h; cbn in *; TMSimp; eauto.
      - destruct H as (?&?&?&?). cbn in *. destruct (map _) in H0; cbn in H0; congruence.
      - destruct H as (?&?&?&?). cbn in *. destruct (map _) in H0; cbn in H0; congruence.
      - destruct H as (?&?&?&?). cbn in *. destruct (map _) in H0; cbn in H0; congruence.
      - destruct e; swap 1 2; cbn in *; TMSimp.
        destruct b; TMSimp cbn in *.
        + destruct H1 as (?&?&?&?). cbn in *.
          destruct n; cbn in *; inv H1. eexists. split. eauto. destruct n; cbn; do 2 eexists; split; cbn; eauto.
        + destruct H as (?&?&?&?). cbn in *.
          destruct n; cbn in *; inv H0. eexists. split. eauto.
          hnf. do 2 eexists; split; cbn; eauto.
        + destruct H as (?&?&?&?). cbn in *. destruct n; cbn in *; inv H0.
    }
  Qed.

  (* Constructors *)
  Section NatConstructor.

    Definition S_Rel : Rel (tapes bool^+ 1) (unit * tapes bool^+ 1) :=
      Mk_R_p (ignoreParam (fun tin tout => forall n : nat, tin ≂ n -> tout ≂ S n)).

    Definition Constr_S : { M : mTM bool^+ 1 & states M -> unit } :=
      Move _ L tt;; WriteMove (Some (inr true), L) tt;; WriteMove (Some (inl START), R) tt.

    Lemma Constr_S_Sem : Constr_S ⊨c(5) S_Rel.
    Proof.
      eapply RealiseIn_monotone.
      {
        repeat eapply Seq_RealiseIn.
        - eapply Move_Sem.
        - eapply WriteMove_Sem.
        - eapply WriteMove_Sem.
      }
      { cbn. omega. }
      {
        intros tin (yout, tout). TMCrush.
        - destruct H0 as (r1&r2&He1&He2).
          destruct h0; cbn in *; try congruence.
          destruct (map _) in He2; cbn in *; congruence.
          simpl_tape in *.
          destruct l; cbn in *; try congruence. subst.
          hnf. do 2 eexists; split; cbn; eauto. f_equal. now rewrite <- He2.
        - destruct H0 as (r1&r2&He1&He2).
          destruct h0; cbn in *; try congruence.
          destruct (map _) in He2; cbn in *; congruence.
          simpl_tape in *.
          destruct l; cbn in *; try congruence. subst.
          hnf. do 2 eexists; split; cbn; eauto. f_equal. now rewrite <- He2.
          hnf. do 2 eexists; split; cbn; eauto. f_equal. now rewrite <- He2.
      }
    Qed.

    Definition O_Rel : Rel (tapes bool^+ 1) (unit * tapes bool^+ 1) :=
      Mk_R_p (ignoreParam (fun tin tout => forall n, tin ≂ n -> tout ≂ O)).

    Definition Constr_O : { M : mTM bool^+ 1 & states M -> unit } :=
      WriteMove (Some (inl STOP), L) tt;; WriteMove (Some (inr false), L) tt;; WriteMove (Some (inl START), R) tt.


    Lemma Constr_O_Sem : Constr_O ⊨c(5) O_Rel.
    Proof.
      eapply RealiseIn_monotone.
      {
        repeat eapply Seq_RealiseIn.
        - eapply WriteMove_Sem.
        - eapply WriteMove_Sem.
        - eapply WriteMove_Sem.
      }
      { cbn. omega. }
      {
        intros tin (yout, tout). TMSimp. simpl_tape.
        destruct H0 as (r1&r2&HE1&HE2). cbn in *.
        do 2 eexists; split; cbn; eauto.
      }
    Qed.

  End NatConstructor.

End MatchNat.