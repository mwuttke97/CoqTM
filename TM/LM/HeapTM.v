Require Import TM.Code.CodeTM TM.Code.Copy.
Require Import TM.Code.MatchNat TM.Code.MatchSum TM.Code.MatchFin TM.Code.MatchPair TM.Code.WriteValue.
Require Import TM.Code.ChangeAlphabet TM.LiftMN TM.LiftSigmaTau.
Require Import TM.Basic.Mono.
Require Import TM.Code.ListTM. (* [Nth] *)

Require Import TM.LM.Definitions TM.LM.TokTM.



(** * Heap Machine *)


(** ** Alphabets *)

(* See [TokTM] *)
Arguments sigTok : simpl never.

Definition sigHAd := FinType (EqType sigNat).
Arguments sigHAd : simpl never.

Definition sigPro := FinType (EqType (sigList sigTok)).
Arguments sigPro : simpl never.
Instance Encode_Prog : codable sigPro Pro := _.

Definition sigHClos := FinType (EqType (sigPair sigPro sigHAd)).
Arguments sigHClos : simpl never.
Instance Encode_HClos : codable sigHClos HClos := _.

Definition sigHEnt' := FinType (EqType (sigPair sigHClos sigHAd)).
Arguments sigHEnt' : simpl never.
Instance Encode_HEnt' : codable sigHEnt' (HClos*HAd) := _.

Definition sigHEnt := FinType (EqType (sigOption sigHEnt')).
Arguments sigHEnt : simpl never.
Instance Encode_HEnt : codable sigHEnt HEnt := _.

Definition sigHeap := FinType (EqType (sigList sigHEnt)).
Arguments sigHeap : simpl never.
Instance Encode_Heap : codable sigHeap Heap := _.



(** ** Lookup *)

Fixpoint lookup (H:Heap) a n {struct n} : option (HClos) :=
  match n with
  | O =>
    match nth_error H a with
    | Some (Some (g, b)) => Some g
    | _ => None
    end
  | S n' =>
    match nth_error H a with
    | Some (Some (g, b)) => lookup H b n'
    | _ => None
    end
  end.

(*
There is no need to save [n], however [a] and [H] must be saved.
[H] and [a] are the parameters of [Nth], so they are already saved by [Nth].
However, in the [S n'] case, we overwrite [a] with [b], so we have to save [a] again.
(Actually, the first copy of [a] by [Nth] is superfluent, because we don't need a again during the loop.)
Because [Nth] has two internal tapes, and we need one addition tape to save [a], [Lookup] has 7 tapes in total:

t0: H
t1: a
t2: n
t3: out
t4-t5: internal tapes for [Nth]
t6: internal tape for storing the result of [Nth] in the case [n=0].
t7: saves [a]

We neeed the alphabets [sigHeap], [sigNat], and [sigOption sigHEnt] for [Nth].
The output of the machine is encoded with [sigOption sigHClos].
*)


Definition sigLookup : finType := FinType (EqType ((sigHeap + sigNat + sigOption sigHEnt) + sigOption sigHClos)).
Arguments sigLookup : simpl never.

Check Retract_sigList_X.

Check _ : Retract sigNat sigLookup.


Check _ : codable sigLookup Heap.


Check _ : Retract sigNat sigLookup.



(** There are fou ways to encode [nat] on [sigLookup]:
- as a variable on [sigHeap].
- directly on the [sigNat], i.e. as parameter for [Nth]
- on the alphabet [sigOption sigHEnt], i.e. as an address inside the optional output of [Nth]
- on the alphabet [sigOption sigHClos], i.e. as the address of the optional output closure

We assume, that [n] is encoded in the first way, i.e. as variable. However, for simplicity, [a] should be encoded as a parameter for [Nth]. *)

Definition retr_nat_heap : Retract sigNat sigHeap := Retract_sigList_X _.
Definition retr_nat_lookup_var : Retract sigNat sigLookup := Retract_inl (sigOption sigHClos) (Retract_inl (sigOption sigHEnt) (Retract_inl sigNat retr_nat_heap)).
Definition retr_nat_lookup_nth : Retract sigNat sigLookup := Retract_inl (sigOption sigHClos) (Retract_inl (sigOption sigHEnt) (Retract_inr sigHeap (Retract_id sigNat))).
Definition retr_nat_optEnt : Retract sigNat (sigOption sigHEnt) := Retract_sigOption_X _.
Definition retr_nat_lookup_optEnt : Retract sigNat sigLookup := Retract_inl (sigOption sigHClos) (Retract_inr _ retr_nat_optEnt).
Definition retr_nat_optClos : Retract sigNat (sigOption sigHClos) := Retract_sigOption_X _.
Definition retr_nat_lookup_out : Retract sigNat sigLookup := Retract_inr _ retr_nat_optClos.

(*
Lookup_Step:

if n = S n' {
  buff = Nth H a
  if buff = Some (Some (g, b)) {
    buff = snd buff
    Translate buff from [retr_nat_lookup_optEnt] to [ret_nat_lookup_nth].
    Reset a; a <- buff
    Reset buff (* [MatchOption] currently resets the tape if the input was [None]. This could be considered a bug of [MatchOption], but it actually makes things more convenient. *)
    continue
  } else {
    Reset buff
    return
  }
} else if n = O {
  buff = Nth H a
  if buff = Some (Some (g, b)) {
    (out, buff) = buff
    out = Some out
    return
  } else {
    Reset buff
    return
  }
}

t0: H
t1: a (copy)
t2: n
t3: out
t4-t5: internal tapes for [Nth]
t6: internal tape for storing the result of [Nth]
*)

Definition Lookup_Step : { M : mTM sigLookup^+ 7 & states M -> bool*unit } :=
  If (Inject (ChangeAlphabet MatchNat retr_nat_lookup_var) [|Fin2|])
     (* [n = S n'] *)
     (Inject (ChangeAlphabet (Nth sigHEnt) _) [|Fin0; Fin1; Fin6; Fin4; Fin5|];;
      If (Inject (ChangeAlphabet (MatchOption sigHEnt) _) [|Fin6|])
         (If (Inject (ChangeAlphabet (MatchOption sigHEnt') _) [|Fin6|])
             (Return
                (Inject (ChangeAlphabet (Snd sigHClos sigHAd) _) [|Fin6|];;
                 Inject (Translate retr_nat_lookup_optEnt retr_nat_lookup_nth) [|Fin6|];;
                 Inject (ChangeAlphabet (Reset sigHAd) retr_nat_lookup_nth) [|Fin1|];;
                 Inject (ChangeAlphabet (CopyValue sigHAd) retr_nat_lookup_nth) [|Fin6; Fin1|];;
                 Inject (ChangeAlphabet (Reset sigHAd) retr_nat_lookup_nth) [|Fin6|])
                (true, tt))
             (Return (Inject (ChangeAlphabet (Constr_None sigHClos) _) [|Fin3|]) (false, tt)))
         (Return (Inject (ChangeAlphabet (Constr_None sigHClos) _) [|Fin3|]) (false, tt)))
     (* [n = O] *)
     (Return
        (Inject (ChangeAlphabet (Nth sigHEnt) _) [|Fin0; Fin1; Fin6; Fin4; Fin5|];;
         If (Inject (ChangeAlphabet (MatchOption sigHEnt) _) [|Fin6|])
            (If (Inject (ChangeAlphabet (MatchOption sigHEnt') _) [|Fin6|])
                (Inject (ChangeAlphabet (MatchPair sigHClos sigHAd) _) [|Fin6; Fin3|];;
                 Inject (ChangeAlphabet (Constr_Some sigHClos) _) [|Fin3|])
                (Inject (ChangeAlphabet (Constr_None sigHClos) _) [|Fin3|]))
            (Inject (ChangeAlphabet (Constr_None sigHClos) _) [|Fin3|]))
        (false, tt))
.



Definition Lookup_Step_Rel : Rel (tapes sigLookup^+ 7) (bool*unit * tapes sigLookup^+ 7) :=
  fun tin '(yout, tout) =>
    forall (H: Heap) (a n: nat),
      tin[@Fin0] ≃ H ->
      tin[@Fin1] ≃(Encode_map Encode_nat retr_nat_lookup_nth) a ->
      tin[@Fin2] ≃(Encode_map Encode_nat retr_nat_lookup_var) n ->
      isRight tin[@Fin3] -> isRight tin[@Fin4] -> isRight tin[@Fin5] -> isRight tin[@Fin6] ->
      tout[@Fin0] ≃(Encode_map _ (Retract_inl _ _)) H /\
      match n with
      | O =>
        tout[@Fin1] ≃(Encode_map Encode_nat retr_nat_lookup_nth) a /\
        tout[@Fin2] ≃(Encode_map Encode_nat retr_nat_lookup_var) 0 /\
        tout[@Fin3] ≃
            match nth_error H a with
            | Some (Some (g, b)) => Some g
            | _ => None
            end /\
        yout = (false, tt)
      | S n' =>
        match nth_error H a with
        | Some (Some (g, b)) =>
          tout[@Fin1] ≃(Encode_map Encode_nat retr_nat_lookup_nth) b /\
          isRight tout[@Fin3] /\
          yout = (true, tt)
        | _ =>
          tout[@Fin1] ≃(Encode_map Encode_nat retr_nat_lookup_nth) a /\
          tout[@Fin3] ≃ @None HClos /\
          yout = (false, tt)
        end /\
        tout[@Fin2] ≃(Encode_map Encode_nat retr_nat_lookup_var) n'
      end /\
      isRight tout[@Fin4] /\ isRight tout[@Fin5] /\ isRight tout[@Fin6]
.


Ltac clear_tape_eqs :=
  repeat match goal with
         | [ H: ?t'[@ ?x] = ?t[@ ?x] |- _ ] => clear H
         end.

Lemma Lookup_Step_Realise : Lookup_Step ⊨ Lookup_Step_Rel.
Proof.
  eapply Realise_monotone.
  { unfold Lookup_Step. repeat TM_Correct.
    (* branche [n = S n' ] *)
    - apply Lift_Realise. eapply RealiseIn_Realise. apply MatchNat_Sem.
    - apply (ChangeAlphabet_Computes2 (Nth_Computes (cX := Encode_HEnt))).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply MatchOption_Sem with (X := HEnt).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply MatchOption_Sem with (X := (HClos * HAd) % type).
    - apply Lift_Realise. apply Snd_Realise with (X := HClos) (Y := HAd).
    - apply Translate_Realise with (X := nat).
    - apply Lift_Realise. apply Reset_Realise with (X := nat).
    - apply Lift_Realise. apply CopyValue_Realise with (X := nat).
    - apply Lift_Realise. apply Reset_Realise with (X := nat).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply Constr_None_Sem with (X := HClos).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply Constr_None_Sem with (X := HClos).
    (* branche [n = O] *)
    - apply (ChangeAlphabet_Computes2 (Nth_Computes (cX := Encode_HEnt))).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply MatchOption_Sem with (X := HEnt).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply MatchOption_Sem with (X := (HClos * HAd) % type).
    - apply Lift_Realise. apply MatchPair_Realise with (X := HClos) (Y := HAd).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply Constr_Some_Sem with (X := HClos).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply Constr_None_Sem with (X := HClos).
    - apply Lift_Realise. eapply RealiseIn_Realise. apply Constr_None_Sem with (X := HClos).
  }
  {
    intros tin ((yout&()), tout) H.
    intros heap a n HEncH HEncA HEncN HRight3 HRight4 HRight5 HRight6.
    TMSimp; clear_trivial_eqs (*; clear_tape_eqs *).
    destruct H; TMSimp; clear_trivial_eqs. (* This takes ***LONG*** *)
    { (* Then branche of [MatchNat]: [n = S n'] *)
      unfold tape_contains in *.
      specialize (H n). spec_assert H by now apply contains_translate_tau1.
      
      destruct n; cbn in *; destruct H as (H&H'); inv H'.
      rename H0 into HCompNth.
      specialize (HCompNth heap a). spec_assert HCompNth.
      { apply (tape_contains_ext HEncH). cbn. now rewrite List.map_map. }
      spec_assert HCompNth.
      { apply (tape_contains_ext HEncA). cbn. now rewrite List.map_map. }
      spec_assert HCompNth by auto. spec_assert HCompNth by intros i; destruct_fin i; cbn; auto.
      destruct HCompNth as (HCompNth & HCompNth2 & HCompNth3 & HCompNth4); cbn in *.
      specialize (HCompNth4 Fin1) as HCompNth5; specialize (HCompNth4 Fin0).
      
      destruct H1; TMSimp; clear_trivial_eqs (*; clear_tape_eqs *).
      { (* Then branche of first [MatchOption] *)
        rename H0 into HMatchOpt1.
        specialize (HMatchOpt1 (nth_error heap a)). spec_assert HMatchOpt1.
        { apply contains_translate_tau1. apply (tape_contains_ext HCompNth3). cbn. rewrite !List.map_map. apply map_ext. auto. }
        destruct (nth_error heap a) as [ hEnt | ] eqn:ENth; cbn in *; destruct HMatchOpt1 as (HMatchOpt1&HMatchOpt1'); inv HMatchOpt1'; apply contains_translate_tau2 in HMatchOpt1.

        destruct H1; TMSimp; clear_trivial_eqs (*; clear_tape_eqs *).
        { (* Then branche of second [MatchOption] *)
          rename H0 into HMatchOpt2; rename H2 into HMatchPair; rename H3 into HTranslate; rename H4 into HReset1; rename H5 into HCopy; rename H6 into HReset2.
          specialize (HMatchOpt2 hEnt); spec_assert HMatchOpt2.
          { apply contains_translate_tau1. apply (tape_contains_ext HMatchOpt1). cbn. now rewrite !List.map_map. }
          destruct hEnt as [ (g, b) | ]; cbn in *; destruct HMatchOpt2 as (HMatchOpt2,HMatchOpt2'); inv HMatchOpt2'; apply contains_translate_tau2 in HMatchOpt2.

          specialize (HMatchPair (g, b)); spec_assert HMatchPair as HMatchPair % contains_translate_tau2; cbn in *.
          { apply contains_translate_tau1. apply (tape_contains_ext (HMatchOpt2)). cbn. now rewrite List.map_map. }

          specialize (HTranslate b). spec_assert HTranslate.
          { apply (tape_contains_ext HMatchPair). cbn. now rewrite List.map_map. }

          specialize (HReset1 a). spec_assert HReset1.
          { apply contains_translate_tau1. apply (tape_contains_ext HCompNth2). cbn. now rewrite List.map_map. }

          specialize (HCopy b). spec_assert HCopy by now apply contains_translate_tau1.
          spec_assert HCopy as (HCopy % contains_translate_tau2 & HCopy' % contains_translate_tau2) by assumption.

          specialize (HReset2 b). spec_assert HReset2 by now apply contains_translate_tau1.

          repeat split; auto.
          - apply (tape_contains_ext HCompNth). cbn. now rewrite List.map_map.
          - now apply contains_translate_tau2 in H.
          - now apply surjectTape_isRight' in HReset2.
        }

        { (* Else branche of second [MatchOption] *)
          rename H0 into HMatchOpt2.
          specialize (HMatchOpt2 hEnt); spec_assert HMatchOpt2.
          { apply contains_translate_tau1. apply (tape_contains_ext HMatchOpt1). cbn. now rewrite !List.map_map. }
          destruct hEnt as [ (g, b) | ]; cbn in *; destruct HMatchOpt2 as (HMatchOpt2,HMatchOpt2'); inv HMatchOpt2'.

          apply contains_translate_tau2 in H.
          spec_assert H2 as H2 % contains_translate_tau2 by now apply surjectTape_isRight.
          apply surjectTape_isRight' in HMatchOpt2.

          repeat split; auto.
          - apply (tape_contains_ext HCompNth). cbn. now rewrite List.map_map.
          - apply (tape_contains_ext HCompNth2). cbn. now rewrite List.map_map.
        }

      }
      { (* Else branche of first [MatchOption] *)
        rename H0 into HMatchOpt1.
        specialize (HMatchOpt1 (nth_error heap a)). spec_assert HMatchOpt1.
        { apply contains_translate_tau1. apply (tape_contains_ext HCompNth3). cbn. rewrite !List.map_map. apply map_ext. auto. }
        destruct (nth_error heap a) as [ hEnt | ] eqn:ENth; cbn in *; destruct HMatchOpt1 as (HMatchOpt1&HMatchOpt1'); inv HMatchOpt1'.

        apply contains_translate_tau2 in H.
        spec_assert H2 as H2 % contains_translate_tau2 by now apply surjectTape_isRight.
        apply surjectTape_isRight' in HMatchOpt1.

        repeat split; auto.
        - apply (tape_contains_ext HCompNth). cbn. now rewrite List.map_map.
        - apply (tape_contains_ext HCompNth2). cbn. now rewrite List.map_map.
      }
    }

    { (* The Else branche of [MatchNat]: [n = 0] *)
      (* TODO *)
      admit.
    }
  }
Qed.




Definition Lookup_Loop := WHILE Lookup_Step.


(* Returns the [n] when [lookup] terminates *)
Fixpoint lookup_a (H:Heap) a n {struct n} : nat :=
  match n with
  | O => a
  | S n' =>
    match nth_error H a with
    | Some (Some (g, b)) => lookup_a H b n'
    | _ => a
    end
  end.


(* Returns the [n] when [lookup] terminates *)
Fixpoint lookup_n (H:Heap) a n {struct n} : nat :=
  match n with
  | O => 0
  | S n' =>
    match nth_error H a with
    | Some (Some (g, b)) => lookup_n H b n'
    | _ => n'
    end
  end.


Definition Lookup_Loop_Rel : Rel (tapes sigLookup^+ 7) (unit * tapes sigLookup^+ 7) :=
  ignoreParam (
      fun tin tout =>
        forall (H: Heap) (a n: nat),
          tin[@Fin0] ≃ H ->
          tin[@Fin1] ≃ a ->
          tin[@Fin2] ≃ n ->
          isRight tin[@Fin3] -> isRight tin[@Fin4] -> isRight tin[@Fin5] -> isRight tin[@Fin6] ->
          tout[@Fin0] ≃ H /\ (* [H] is saved *)
          tout[@Fin1] ≃ lookup_a H a n /\ (* the [a] when [lookup] terminated *)
          tout[@Fin2] ≃ lookup_n H a n /\ (* the [n] when [lookup] terminated *)
          tout[@Fin3] ≃ lookup H a n /\
          isRight tout[@Fin4] /\ (* internal tape of [Nth] *)
          isRight tout[@Fin5] /\ (* internal tape of [Nth] *)
          isRight tout[@Fin6] (* internal tape to save the result of [Nth] *)
    ).



Lemma Lookup_Loop_Realise : Lookup_Loop ⊨ Lookup_Loop_Rel.
Proof.
  eapply Realise_monotone.
  { unfold Lookup_Loop. repeat TM_Correct.
    - eapply Lookup_Step_Realise.
  }
  {
    apply WhileInduction; intros; intros H a n HEncH HEncA HEncN HRight3 HRight4 HRight5 HRight6.
    - hnf in HLastStep. specialize HLastStep with (1 := HEncH) (2 := HEncA) (3 := HEncN) (4 := HRight3) (5 := HRight4) (6 := HRight5) (7 := HRight6) as (HS1&HS2&HInt4&HInt5&HInt6).
      destruct n; [ destruct HS2 as (HEncA'&HEncN'&Hout&Hyout) | destruct HS2 as (HS2&HEncN')].
      + inv Hyout. cbn in *. destruct (nth_error H a) eqn:E; cbn in *; repeat split; auto.
      + cbn in *. destruct (nth_error H a) as [ e | ] eqn:E.
        * destruct e as [ (g,b) | ].
          -- destruct HS2 as (?&?&HS2); inv HS2.
          -- destruct HS2 as (?&?&?). repeat split; auto.
        * destruct HS2 as (?&?&?). repeat split; auto.
    - hnf in HStar. specialize HStar with  (1 := HEncH) (2 := HEncA) (3 := HEncN) (4 := HRight3) (5 := HRight4) (6 := HRight5) (7 := HRight6) as (HEncH'&HS2&HInt4&HInt5&HInt6).
      cbn in HLastStep.
      destruct n.
      + destruct HS2 as (HS2&HS3&HS4&HS5). inv HS5.
      + destruct HS2 as (HS2&HEncN').
        destruct (nth_error H a) as [  e | ] eqn:E.
        * destruct e as [ (g,b) | ].
          -- destruct HS2 as (HEncB&HRight3'&Hout). clear Hout.
             specialize HLastStep with (1 := HEncH') (2 := HEncB) (3 := HEncN') (4 := HRight3') (5 := HInt4) (6 := HInt5) (7 := HInt6) as (HLS1&HLS2&HLS3&HLS4&HLS5&HLS6&HLS7).
             cbn. repeat split; try rewrite E; auto.
          -- destruct HS2 as (?&?&HS2). inv HS2.
        * destruct HS2 as (?&?&HS2). inv HS2.
  }
Qed.



  
Definition Lookup_Rel : Rel (tapes sigLookup^+ 8) (unit * tapes sigLookup^+ 8) :=
  ignoreParam (
      fun tin tout =>
        forall (H: Heap) (a n: nat),
          tin[@Fin0] ≃ H ->
          tin[@Fin1] ≃ a ->
          tin[@Fin2] ≃ n ->
          isRight tin[@Fin3] -> isRight tin[@Fin4] -> isRight tin[@Fin5] -> isRight tin[@Fin6] -> isRight tin[@Fin7] ->
          tout[@Fin0] ≃ H /\ (* [H] is saved *)
          tout[@Fin1] ≃ a /\ (* [a] is saved *)
          isRight tout[@Fin2] /\ (* [n] is discarded *)
          tout[@Fin3] ≃ lookup H a n /\ (* output *)
          isRight tout[@Fin4] /\ (* internal tape of [Nth] *)
          isRight tout[@Fin5] /\ (* internal tape of [Nth] *)
          isRight tout[@Fin6] /\ (* internal tape to save the result of [Nth] *)
          isRight tout[@Fin7] (* internal tape to save [a] *)
    ).