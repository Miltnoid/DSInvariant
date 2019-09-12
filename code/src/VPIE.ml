open Core

module Make (V : Verifier.t) (S : Synthesizer.t) = struct

  let negs : Value.t list ref = ref []
  let possibilities : Expr.t list ref = ref [Expr.mk_constant_true_func (Type._t)]

  let satisfies_testbed
      ~(problem:Problem.t)
      (tb:TestBed.t)
      (e : Expr.t)
    : bool =
    List.for_all
      ~f:(fun p ->
          let ans =
            Eval.evaluate_with_holes
              ~eval_context:problem.eval_context
              (Expr.mk_app e (Value.to_exp p))
          in
          Value.equal
            ans
            Value.mk_true)
      tb.pos_tests
      &&
      List.for_all
        ~f:(fun p ->
            let ans =
              Eval.evaluate_with_holes
                ~eval_context:problem.eval_context
                (Expr.mk_app e (Value.to_exp p))
            in
            Value.equal
              ans
              Value.mk_false)
        tb.neg_tests

  let learnVPreCondAll
      ~(problem : Problem.t)
      ~(pre : Expr.t)
      ~(post : UniversalFormula.t)
      ~(positives : Value.t list)
      ~(checker : Expr.t -> Value.t list)
    : (Expr.t,Value.t list) Either.t =
    let rec helper
        (attempt:int)
        (testbed:TestBed.t)
        (pres:Expr.t list)
      : (Expr.t,Value.t list) Either.t =
      (Log.info (lazy ("VPIE Attempt "
                       ^ (Int.to_string attempt)
                       ^ "."));
       let pres =
         begin match List.filter ~f:(satisfies_testbed ~problem testbed) pres with
           | [] ->
             let subvalues =
               List.concat_map
                 ~f:Value.strict_subvalues
                 (testbed.pos_tests@testbed.neg_tests)
             in
             let all_inside_examples =
               List.filter
                 ~f:(fun e ->
                     Typecheck.type_equiv
                       problem.tc
                       (Type._t)
                       (Typecheck.typecheck_exp problem.ec problem.tc problem.vc (Value.to_exp e)))
                 subvalues
             in
             let testbed =
               List.fold_left
                 ~f:(fun tb e ->
                     if not
                         (List.is_empty
                            (V.true_on_examples
                               ~problem
                               ~examples:[e]
                               ~eval:(Expr.mk_identity_func (Type._t))
                               ~eval_t:(Type.mk_arrow (Type._t) (Type._t))
                               ~post:post)) then
                       TestBed.add_neg_test ~testbed:tb e
                     else
                       (if TestBed.contains_test ~testbed:tb e then
                          tb
                        else
                         TestBed.add_pos_test ~testbed:tb e)
                   )
                 ~init:testbed
                 all_inside_examples
             in
             Log.info (lazy "testbed");
             Log.info (lazy (TestBed.show testbed));
             List.map ~f:(fun e -> assert (satisfies_testbed ~problem testbed e); Expr.simplify e) (snd (S.synth ~problem ~testbed:testbed))
           | pres ->
             pres
         end
       in
       let synthed_pre = List.hd_exn pres in
       Log.info (lazy ("Candidate Precondition: " ^ (DSToMyth.full_to_pretty_myth_string ~problem synthed_pre)));
       let full_pre = Expr.and_predicates pre synthed_pre in
       let boundary_ce =
         checker full_pre
       in
       begin match boundary_ce with
         | [] ->
           let model_o =
             List.fold_left
               ~f:(fun acc (eval,eval_t) ->
                   begin match acc with
                     | [] ->
                       Log.info (lazy (DSToMyth.full_to_pretty_myth_string ~problem eval));
                       V.implication_counter_example
                         ~problem
                         ~pre:full_pre
                         ~eval
                         ~eval_t
                         ~post
                     | _ -> acc
                   end)
               ~init:[]
               problem.mod_vals
           in
           begin match model_o with
             | [] ->
               Log.info (lazy ("Verified Precondition: " ^ (DSToMyth.full_to_pretty_myth_string ~problem synthed_pre)));
               First synthed_pre
             | model ->
                 Log.info (lazy ("Add negative examples: " ^ (List.to_string ~f:Value.show model)));
                 helper
                   (attempt+1)
                   (TestBed.add_neg_tests
                      ~testbed
                      model)
                   pres
           end
         | ce -> Second ce
       end)
    in
    let testbed = TestBed.create_positive positives in
    helper 0 testbed [Expr.mk_constant_true_func (Type._t)]

  let learnVPreCond
      ~(problem:Problem.t)
      ~(pre:Expr.t)
      ~(eval : Expr.t)
      ~(eval_t : Type.t)
      ~(post : UniversalFormula.t)
      ~(positives : Value.t list)
    : Expr.t =
    let rec helper
        (attempt:int)
        (testbed:TestBed.t)
      : Expr.t =
       let pres =
         begin match List.filter ~f:(satisfies_testbed ~problem testbed) !possibilities with
           | [] ->
             (Log.info (lazy ("Learning new precondition set.")));
             let subvalues =
               List.concat_map
                 ~f:Value.strict_subvalues
                 (testbed.pos_tests@testbed.neg_tests)
             in
             let all_inside_examples =
               List.filter
                 ~f:(fun e ->
                     Typecheck.type_equiv
                       problem.tc
                       (Type._t)
                       (Typecheck.typecheck_exp problem.ec problem.tc problem.vc (Value.to_exp e)))
                 subvalues
             in
             let testbed =
               List.fold_left
                 ~f:(fun tb e ->
                     if not
                         (List.is_empty
                            (V.true_on_examples
                               ~problem
                               ~examples:[e]
                               ~eval:(Expr.mk_identity_func (Type._t))
                               ~eval_t:(Type.mk_arrow (Type._t) (Type._t))
                               ~post:post)) then
                       TestBed.add_neg_test ~testbed:tb e
                     else
                       TestBed.add_pos_test ~testbed:tb e
                   )
                 ~init:testbed
                 all_inside_examples
             in
             Log.info (lazy "testbed");
             Log.info (lazy (TestBed.show testbed));
             let pres = List.map ~f:Expr.simplify (snd (S.synth ~problem ~testbed:testbed))
              in possibilities := pres
               ; pres
           | pres ->
             pres
         end
       in
      (Log.info (lazy ("VPIE Attempt "
                       ^ (Int.to_string attempt)
                       ^ "."));
       let synthed_pre = List.hd_exn pres in
       Log.info (lazy ("Candidate Precondition: " ^ (DSToMyth.full_to_pretty_myth_string ~problem synthed_pre)));
       let full_pre = Expr.and_predicates pre synthed_pre in
       let model_o =
         V.implication_counter_example
           ~problem
           ~pre:full_pre
           ~eval
           ~eval_t
           ~post
       in
       begin match model_o with
         | [] ->
           Log.info (lazy ("Verified Precondition: " ^ (DSToMyth.full_to_pretty_myth_string ~problem synthed_pre)));
           synthed_pre
         | model ->
           if (List.length model <> 1) then
             failwith ("cannot do such functions yet: " ^ (List.to_string ~f:Value.show model))
           else
             let new_neg_example = List.hd_exn model in
             negs := new_neg_example::!negs;
             Log.info (lazy ("Add negative example: " ^ (Value.show new_neg_example)));
             helper
               (attempt+1)
               (TestBed.add_neg_test ~testbed new_neg_example)
       end)
    in
    let testbed = TestBed.create_positive positives in
    let testbed =
      List.fold
        ~f:(fun testbed n -> TestBed.add_neg_test ~testbed n)
        ~init:testbed
        !negs
    in
    helper 0 testbed
end
