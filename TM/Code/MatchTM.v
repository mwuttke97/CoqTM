Require Import TM.Code.CodeTM.

Require Import TM.Basic.Mono TM.Basic.Nop TM.Basic.Multi.
Require Import TM.Combinators.Combinators.
Require Import TM.LiftMN.

Require Import TM.Compound.TMTac.
Require Import TM.Compound.CopySymbols TM.Compound.MoveToSymbol.


Check ltac:(idtac "Warning: This file could take LONG!"; apply 42).


(* Basic pattern matching *)
Section MatchSum.
  Variable X Y : Type.
  Variable (sigX sigY : finType).
  Hypothesis (codX : codeable sigX X) (codY : codeable sigY Y).

  Definition MatchSum_Rel : Rel (tapes (sigX+sigY+bool)^+ 1) (bool * tapes (sigX+sigY+bool)^+ 1) :=
    Mk_R_p (if? (fun (tin tout : tape (sigX+sigY+bool)^+) =>
                   forall v : X + Y,
                     tape_encodes (Encode_Sum codX codY) tin v ->
                     exists x : X, v = inl x /\
                              tape_encodes (Encode_Map codX (@retract_l_l sigX sigY)) tout x)
              ! (fun (tin tout : tape (sigX+sigY+bool)^+) =>
                   forall v : X + Y,
                     tape_encodes (Encode_Sum codX codY) tin v ->
                     exists y : Y, v = inr y /\
                              tape_encodes (Encode_Map codY (@retract_l_r sigX sigY)) tout y)).

  Definition MatchSum : { M : mTM (sigX+sigY+bool)^+ 1 & states M -> bool } :=
    MATCH (Read_char _)
          (fun o => match o with
                 | Some (inl (inr true))  => Write (inr START) tt;; Move _ R true  (* inl *)
                 | Some (inl (inr false)) => Write (inr START) tt;; Move _ R false (* inr *)
                 | _ => mono_Nop _ true (* invalid input *)
                 end).

  Lemma MatchSum_Sem : MatchSum ⊨c(5) MatchSum_Rel.
  Proof.
    eapply RealiseIn_monotone.
    {
      unfold MatchSum. eapply Match_RealiseIn. cbn. eapply read_char_sem.
      instantiate (2 := fun o : option (sigX+sigY+bool)^+ =>
                          match o with Some (inl (inr true)) => _ | Some (inl (inr false)) => _ | _ => _ end).
      cbn. intros [ s | ]; cbn.
      - destruct s as [ s | start]; cbn.
        + destruct s as [xy | cons]; cbn.
          * eapply RealiseIn_monotone'. eapply mono_Nop_Sem. omega.
          * destruct cons; (eapply Seq_RealiseIn; [eapply Write_Sem | eapply Move_Sem]).
        + eapply RealiseIn_monotone'. eapply mono_Nop_Sem. omega.
      - eapply RealiseIn_monotone'. eapply mono_Nop_Sem. omega.
    }
    {
      cbn. omega.
    }
    {
      intros tin (yout&tout) H. destruct H as (H1&(t&(H2&H3)&H4)); hnf in *. subst.
      destruct_tapes; cbn in *.
      destruct h; cbn in *; TMSimp; eauto. destruct (map _) in H0; cbn in H0; congruence.
      destruct e; cbn in *; TMSimp.
      - destruct s; cbn in *; TMSimp.
        + destruct v; cbn in *; destruct (map _) in H0; cbn in *; congruence.
        + destruct b; cbn in *; TMSimp cbn in *; unfold encode_sum in *.
          * destruct v; TMSimp cbn in *. eexists; split; eauto.
            hnf. destruct (encode x1) eqn:E; cbn; do 2 eexists; split; hnf; cbn; eauto. all: rewrite E; cbn; eauto.
          * destruct v; TMSimp cbn in *. eexists; split; eauto.
            hnf. destruct (encode y) eqn:E; cbn; do 2 eexists; split; hnf; cbn; eauto. all: rewrite E; cbn; eauto.
      - destruct v; cbn in *.
        + destruct (map _) in H0; cbn in H0; inv H0.
        + destruct (map _) in H0; cbn in H0; inv H0.
    }
  Qed.

  (* Constructors *)
  Section SumConstr.

    Definition ConstrSum_Rel (is_left:bool) : Rel (tapes (sigX+sigY+bool)^+ 1) (unit * tapes (sigX+sigY+bool)^+ 1) :=
      Mk_R_p (
          ignoreParam
            (fun tin tout =>
               if is_left
               then forall x : X, tape_encodes (Encode_Map codX (@retract_l_l sigX sigY)) tin x ->
                             tape_encodes (Encode_Sum codX codY) tout (inl x)
               else forall y : Y, tape_encodes (Encode_Map codY (@retract_l_r sigX sigY)) tin y ->
                             tape_encodes (Encode_Sum codX codY) tout (inr y))).

    Definition ConstrSum (is_left:bool) : { M : mTM (sigX+sigY+bool)^+ 1 & states M -> unit } :=
      Move _ L tt;; Write (inl (inr is_left)) tt;; Move _ L tt;; Write (inr START) tt;; Move _ R tt.

    Lemma ConstrSum_Sem (is_left:bool) : (ConstrSum is_left) ⊨c(9) (ConstrSum_Rel is_left).
    Proof.
      eapply RealiseIn_monotone.
      {
        eapply Seq_RealiseIn. eapply Move_Sem. eapply Seq_RealiseIn.
        eapply Write_Sem. eapply Seq_RealiseIn. eapply Move_Sem.
        eapply Seq_RealiseIn. eapply Write_Sem. eapply Move_Sem.
      }
      {
        cbn. omega.
      }
      {
        TMSimp ( cbn [Vector.nth] in * ). destruct is_left; cbn in *; subst; TMSimp.
        {
          destruct h; cbn in *; TMSimp; cbn in *.
          - destruct (encode _) in H0; cbn in *; congruence.
          - destruct (encode x) as [ | eX eXs] eqn:E;
              cbn in *; inv H0; cbv [tape_encodes_r]; cbn; rewrite E; cbn;
                (destruct x0; cbn; eauto).
        }
        {
          destruct h; cbn in *; TMSimp; cbn in *.
          - destruct (encode _) in H0; cbn in *; congruence.
          - destruct (encode y) as [ | eX eXs] eqn:E;
              cbn in *; inv H0; cbv [tape_encodes_r]; cbn; rewrite E; cbn;
                (destruct x; cbn; eauto).
        }
      }
    Qed.
                
      
  End SumConstr.

End MatchSum.


Section Copy.

  Section Test.

    Let inputX := encode (4, 3).
    Compute inputX.

    Let t : tape (Bool_Fin + Bool_Fin)^+ :=
      midtape [inr START] (inl (inl true))
              (map inl [inl true; inl true; inl true; inl false; 
                          inr true; inr true; inr true; inr false] ++ [inr STOP; inl (inl true)]).

    Compute tape_local t.
    Let stop_X :=
      fun (x : (Bool_Fin+Bool_Fin)^+) =>
        match x with
        | (inl (inl _)) => false
        | _ => true (* Stop at symbol from Y or halt/stop symbol *)
        end.

    (* CopySymbols_Fun is not computable!  Use the equational rewriting to "execute"
     * (CopSymbols_Fun can be made computable by changing the termination proof to Qed.)
     *)
    Goal True.
      Ltac re x := assert (x = x) by reflexivity.
      re (tape_local (fst (CopySymbols_Fun stop_X id (t, rightof (inr START) [])))).
      re (snd (CopySymbols_Fun stop_X id (t, rightof (inr START) []))).
      re ((left (snd (CopySymbols_Fun stop_X id (t, rightof (inr START) []))))).
      subst t; repeat ( rewrite CopySymbols_Fun_equation in * || cbn in * ); cbv [id] in *.
    Abort.
    
  End Test.
  
  (* Require Import FunInd. *)

  Variable sig : finType.
  Variable stop : sig -> bool.

  Lemma CopySymbols_pair_first tltr str1 x str2 tl' tr':
    (forall x, List.In x str1 -> stop x = false) ->
    (stop x = true) ->
    tape_local (fst tltr) = str1 ++ [x] ++ str2 ->
    (tl', tr') = CopySymbols_Fun stop id tltr ->
    tape_local tl' = x :: str2.
  Proof.
    intros H H0. destruct tltr as [tl tr]. intros H1 E0.
    destruct tl as [ | r rs | l ls | ls m rs]; cbn in *.
    1-3: rewrite CopySymbols_Fun_equation in E0; inv H1; exfalso; destruct str1; cbn in *; congruence.
    revert rs tr ls H ls m H1 tl' tr' E0. revert str1; intros str1.
    induction str1 as [ | s' str1' IHstr1]; (* cbn in *; *) intros.
    - cbn in *. inv H1. rewrite CopySymbols_Fun_equation in E0. rewrite H0 in E0. inv E0. cbn. auto.
    - rewrite CopySymbols_Fun_equation in E0. destruct (stop m) eqn:E1.
      + inv E0. cbn in *. inv H1. enough (stop s' = false)  by congruence; eauto.
      + cbn in H1. inv H1. cbn in *. destruct str1'; cbn in *; eapply IHstr1; eauto.
  Qed.

  Lemma CopySymbols_pair_second tltr str1 x str2 tl' tr':
    (forall x, List.In x str1 -> stop x = false) ->
    (stop x = true) ->
    tape_local (fst tltr) = str1 ++ [x] ++ str2 ->
    (tl', tr') = CopySymbols_Fun stop id tltr ->
    left tr' = rev str1 ++ left (snd tltr).
  Proof.
    intros H H0. destruct tltr as [tl tr]. intros H1 E0.
    destruct tl as [ | r rs | l ls | ls m rs]; cbn in *.
    1-3: rewrite CopySymbols_Fun_equation in E0; inv H1; exfalso; destruct str1; cbn in *; congruence.
    revert rs tr ls H ls m H1 tl' tr' E0. revert str1; intros str1.
    induction str1 as [ | s' str1' IHstr1]; (* cbn in *; *) intros.
    - cbn in *. inv H1. rewrite CopySymbols_Fun_equation in E0. rewrite H0 in E0. inv E0. cbn. auto.
    - rewrite CopySymbols_Fun_equation in E0. destruct (stop m) eqn:E1.
      + inv E0. cbn in *. inv H1. enough (stop s' = false)  by congruence; eauto.
      + cbn in H1. inv H1. cbn in *.
        simpl_list; cbn.
        destruct str1'; cbn in *.
        * clear H. erewrite IHstr1; eauto. destruct tr; cbn; eauto. destruct l0; cbn; auto.
        * simpl_list; cbn.
          erewrite IHstr1; eauto. destruct tr; simpl_list; cbn; eauto. destruct l0; cbn; auto.
  Qed.


  (*
  Lemma MoveToSymbol_right t str1 str2 x :
    (forall x, List.In x str1 -> stop x = false) ->
    (exists s, current t = Some s) ->
    (stop x = true) ->
    right t = str1 ++ x :: str2 ->
    right (MoveToSymbol_Fun stop t) = str2.
  Proof.
    intros H H0 H1. destruct t as [ | r rs | l ls | ls m rs]; cbn in *.
    1,3: rewrite MoveToSymbol_Fun_equation; cbn; destruct str1; cbn in *; try congruence.
    1: destruct H0; congruence.
    1: clear H0.
    revert rs m ls ls H1. induction str1 as [ | s' str1' IHstr1]; cbn in *; intros.
    - rewrite MoveToSymbol_Fun_equation. cbn. destruct (stop m) eqn:E1.
      + cbn.

    
    revert str1 str2 m ls H H1. induction rs as [ | r rs' IHl]; cbn in *; intros.
    - destruct str1; cbn in *; congruence.
    - rewrite MoveToSymbol_Fun_equation; cbn.
      destruct (stop m) eqn:E1; cbn in *.
      + destruct str1; cbn in *. inv H1.
   *)
    
    
  
End Copy.



Section Projection.

  Variable X Y : Type.
  Variable (sigX sigY : finType).
  Hypothesis (codX : codeable sigX X) (codY : codeable sigY Y).


  Definition stop_X :=
    fun (x : (sigX+sigY)^+) =>
      match x with
      | (inl (inl _)) => false
      | _ => true (* Stop at symbol from Y or halt/stop symbol *)
      end.

  Definition stop_Y :=
    fun (x : (sigX+sigY)^+) =>
      match x with
        inl (inr _) => false
      | _ => true (* Stop at symbol from X or halt/stop symbol *)
      end.


  Definition Proj_Rel : Rel (tapes (sigX+sigY)^+ 2) (unit * tapes (sigX+sigY)^+ 2) :=
    ignoreParam (
        fun (tin tout : tapes (sigX+sigY)^+ 2) =>
          forall (xy : X * Y),
            tape_encodes (Encode_Pair' codX codY) tin[@Fin.F1] xy ->
            tape_encodes (Encode_Map codY (@retract_inr sigX sigY)) tout[@Fin.F1] (snd xy) /\
            tape_encodes (Encode_Map codX (@retract_inl sigX sigY)) tout[@Fin.FS Fin.F1] (fst xy)
      ).


  Definition Proj : { M : mTM (sigX+sigY)^+ 2 & states M -> unit } :=
    Inject (WriteMove (Some (inr START), R) tt) [|Fin.FS Fin.F1|];;
    CopySymbols stop_X id;;
    Inject (
      (Move _ L tt);;
      WriteMove (Some (inr START), R) tt
    ) [|Fin.F1|];;
    Inject (
      WriteMove (Some (inr STOP), L) tt;;
      MoveToSymbol_L stop_Y;;
      Move _ R tt
    ) [|Fin.FS Fin.F1|].

  (* Θ (18 + (4+?)*(?+1)*|enocode (fst x)|) *)


  Local Lemma CopySymbols_pair_first' (inputX : list sigX) (inputY : list sigY) tltr tl' tr' rs' :
    tape_local (fst tltr) = map inl (map inl inputX ++ map inr inputY) ++ (inr STOP :: rs') ->
    (tl', tr') = CopySymbols_Fun stop_X id tltr ->
    tape_local (tl') = map inl (map inr inputY) ++ (inr STOP :: rs').
  Proof.
    intros. destruct inputY as [ | csy inputY'] eqn:E1; cbn in *.
    - eapply CopySymbols_pair_first; cbn; eauto.
      + rewrite app_nil_r. intuition. eapply in_map_iff in H1 as (?&<-& (?&<-&?)%in_map_iff). trivial.
      + trivial.
    - eapply CopySymbols_pair_first with (str1 := map inl (map inl inputX)); cbn; eauto.
      + intros x. rewrite !List.map_map. intros (?&<-&?) % in_map_iff. cbn. trivial.
      + simpl_list. intuition.
      + now rewrite map_app, <- app_assoc in H.
  Qed.

  Local Lemma CopySymbols_pair_first'' (inputX : list sigX) (inputY : list sigY) ls m rs tr tl' tr' rs' :
    m :: rs = map inl (map inl inputX ++ map inr inputY) ++ inr STOP :: rs' ->
    (tl', tr') = CopySymbols_Fun stop_X id (midtape ls m rs, tr) ->
    tape_local tl' = map inl (map inr inputY) ++ inr STOP :: rs'.
  Proof.
    intros H1 H2. apply (CopySymbols_pair_first' (tltr := (midtape ls m rs, tr)) ltac:(cbn; eapply H1) H2).
  Qed.

  Local Lemma CopySymbols_pair_second' (inputX : list sigX) (inputY : list sigY) tltr tl' tr' rs' :
    tape_local (fst tltr) = map inl (map inl inputX ++ map inr inputY) ++ (inr STOP :: rs') ->
    (tl', tr') = CopySymbols_Fun stop_X id tltr ->
    left tr' = map inl (map inl (rev inputX)) ++ left (snd tltr).
  Proof.
    intros. rewrite !map_rev. destruct inputY as [ | csy inputY'] eqn:E1; cbn in *.
    - rewrite app_nil_r in H.
      eapply CopySymbols_pair_second; cbn; eauto.
      + intros ? (? & <- & (? & <- & ?) % in_map_iff) % in_map_iff. cbn. trivial.
      + cbn. trivial.
    - eapply CopySymbols_pair_second with (str1 := map inl (map inl inputX)); cbn; eauto; swap 2 3.
      + intros x. rewrite !List.map_map. intros (?&<-&?) % in_map_iff. cbn. trivial.
      + rewrite map_app, <- app_assoc in H. eapply H.
      + trivial.
  Qed.
  
  Local Lemma CopySymbols_pair_second'' (inputX : list sigX) (inputY : list sigY) ls m rs tr tl' tr' rs' :
    m :: rs = map inl (map inl inputX ++ map inr inputY) ++ inr STOP :: rs' ->
    (tl', tr') = CopySymbols_Fun stop_X id (midtape ls m rs, tr) ->
    left tr' = map inl (map inl (rev inputX)) ++ left tr.
  Proof.
    intros H1 H2. apply (CopySymbols_pair_second' (tltr := (midtape ls m rs, tr)) ltac:(cbn; eapply H1) H2).
  Qed.

  Lemma Proj_WRealise : Proj ⊫ Proj_Rel.
  Proof.
    eapply WRealise_monotone.
    {
      unfold Proj. do 3 try eapply Seq_WRealise.
      all: try (eapply Inject_WRealise; [vector_dupfree| ]).
      3-4: repeat eapply Seq_WRealise.
      all: try (eapply Realise_WRealise, RealiseIn_Realise;
                first [ eapply Move_Sem | eapply WriteMove_Sem | eapply Write_Sem ]).
      - eapply CopySymbols_WRealise.
      - eapply MoveToSymbol_L_WRealise.
    }
    {
      hnf. intros. hnf. destruct y. intros (inputX, inputY).
      TMSimp repeat progress simpl_not_in || cbn [Vector.nth] in *.
      destruct h3; cbn in *; inv H0; [do 2 destruct (encode _); cbn in H3; congruence | ]. clear H1.
      (*
      erewrite List.map_app, !List.map_map, <- app_assoc in H3; cbn in H3.
       *)
      split.
      - pose proof CopySymbols_pair_first'' H3 H as L1.
        destruct h1; cbn in *; try (destruct (encode inputY); cbn in L1; congruence).
        destruct l; cbn in *.
        + hnf. do 2 eexists. split; cbn; eauto.
        + hnf. do 2 eexists. split; cbn; eauto.
      - pose proof CopySymbols_pair_second'' H3 H as L1. rewrite !map_rev in L1.
        Set Printing Implicit. cbv [finType_CS] in *. Unset Printing Implicit.
        rewrite L1 in *.
        hnf. do 2 eexists. split; cbn.
        + 
  Admitted.

End Projection.




(* TODO: Match operator for functions *)
(*

Section MatchSum_Fun.

  Variable n : nat.
  Variable k : nat.

  Variable (sigX sigY : finType).
  Variable Z : Type.
  Variable tpZ : Fin.t n.
  Hypothesis codZ : codeable (sigX+sigY+bool)^+ Z.
  Variable parF : param_genT (sigX+sigY+bool)^+ n (S k).
  Variable f : param_genF Z parF.

  Let f_param1 := Vector.hd parF.
  Let f_param1T := projT1 (fst f_param1).
  Let f_param1Enc := projT2 (fst f_param1).
  Let f_param1Tape := snd f_param1.

  Variable X : Type.
  Variable codX

  Variable para 


End MatchSum_Fun.


    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    

    


Section MatchTM.

  Variable sig : finType.
  Variable n : nat.
  Variable (F1 : finType).
  Variable (def : F1).
  Variable (pM : sig -> { M1 : mTM sig^+ n & states M1 -> F1}).

  Variable k : nat.
  Variable resType : Type.
  Variable resTape : Fin.t n.
  Hypothesis codRes : codeable sig resType.
  Variable params : param_genT sig n (S k).
  Variable f : param_genF resType params.

  Let param1 := Vector.hd params.
  Let param1T := projT1 (fst param1).
  Let param1Enc := projT2 (fst param1).
  Let param1Tape := snd param1.

  Definition matchTM : { M : mTM sig^+ n & states M -> F1}:=
    MATCH (Read_char_at (sig^+) param1Tape)
          (fun o : option (sig^+) =>
             match o with
             | Some (inl s) =>
               (* TODO: write True on param1T, move param1T to R, call pM s *)
               pM s
             | _ => Nop n _ def
             end).


  Section MatchOption.

    Variable cont_None : 
    
  End MatchOption.

End MatchTM.

*)