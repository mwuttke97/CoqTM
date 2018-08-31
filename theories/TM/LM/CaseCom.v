(** * Constructors and Deconstructors for Tokens *)

Require Import ProgrammingTools.
Require Import TM.Code.CaseNat TM.Code.CaseSum TM.Code.CaseFin.
Require Import TM.LM.Semantics TM.LM.Alphabets.

Definition CaseCom : { M : mTM sigTok^+ 1 & states M -> option ATok } :=
  If (CaseSum _ _)
     (Return Nop None)
     (Relabel (ChangeAlphabet (CaseFin (FinType(EqType(ATok))) ) _) Some)
.
     

Definition CaseCom_Rel : pRel sigTok^+ (FinType (EqType (option ATok))) 1 :=
  fun tin '(yout, tout) =>
    forall t : Tok,
      tin[@Fin0] ≃ t ->
      match yout, t with
      | Some appAT, appT => isRight tout[@Fin0]
      | Some lamAT, lamT => isRight tout[@Fin0]
      | Some retAT, retT => isRight tout[@Fin0]
      | None, varT n => tout[@Fin0] ≃ n
      | _, _ => False
      end
.

Definition CaseCom_steps := 11.

Lemma CaseCom_Sem : CaseCom ⊨c(CaseCom_steps) CaseCom_Rel.
Proof.
  unfold CaseCom_steps. eapply RealiseIn_monotone.
  { unfold CaseCom. TM_Correct.
    - apply LiftAlphabet_RealiseIn. apply CaseFin_Sem.
  }
  { cbn. reflexivity. }
  {
    intros tin (yout, tout) H. intros t HEncT. TMSimp.
    unfold sigTok in *.
    destruct H; TMSimp.
    { (* "Then" branche *)
      specialize (H t HEncT).
      destruct t; auto.
    }
    { (* "Else" branche *)
      rename H into HCaseSum.
      simpl_tape in *; cbn in *.
      specialize (HCaseSum t HEncT).
      destruct t; cbn in *; eauto; modpon H1; subst; eauto.
    }
  }
Qed.


(** Constructors *)

(** Use [WriteValue] for [appT], [lamT], and [retT] *)

Definition Constr_ATok (t : ATok) : pTM sigTok^+ unit 1 := WriteValue (encode (ATok2Tok t)).
Definition Constr_ATok_Rel (t : ATok) : pRel sigTok^+ unit 1 :=
  Mk_R_p (ignoreParam (fun tin tout => isRight tin -> tout ≃ ATok2Tok t)).
Definition Constr_ATok_steps := 7.
Lemma Constr_ATok_Sem t : Constr_ATok t ⊨c(Constr_ATok_steps)Constr_ATok_Rel t.
Proof.
  unfold Constr_ATok_steps. eapply RealiseIn_monotone.
  - unfold Constr_ATok. apply WriteValue_Sem.
  - cbn. destruct t; cbn; reflexivity.
  - intros tin ((), tout) H. cbn in *. auto.
Qed.



Definition Constr_varT : pTM sigTok^+ unit 1 := Constr_inl _ _.
Definition Constr_varT_Rel : pRel sigTok^+ (FinType (EqType unit)) 1 :=
  Mk_R_p (ignoreParam (fun tin tout => forall x : nat, tin ≃ x -> tout ≃ varT x)).
Definition Constr_varT_steps := 3.
Lemma Constr_varT_Sem : Constr_varT ⊨c(Constr_varT_steps) Constr_varT_Rel.
Proof.
  unfold Constr_varT_steps. eapply RealiseIn_monotone.
  - unfold Constr_varT. apply Constr_inl_Sem.
  - reflexivity.
  - intros tin ((), tout) H. intros n HEncN. TMSimp. now apply tape_contains_ext with (1 := H n HEncN).
Qed.


Arguments CaseCom : simpl never.
Arguments Constr_ATok : simpl never.
Arguments Constr_varT : simpl never.