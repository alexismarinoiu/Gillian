module type S = sig
  val cmd_name : string

  val exec_mode : ExecMode.t

  val run_all : test_suite_path:string -> unit
end

module Make (Backend : functor (Outcome : Outcome.S) (Suite : Suite.S) ->
  Backend.S with type category = Suite.category)
(Outcome : Outcome.S)
(Suite : Suite.S)
(Expectations : Expectations.S
                  with type info = Suite.info
                   and type category = Suite.category
                   and type matcher = Backend(Outcome)(Suite).matcher
                   and type outcome = Outcome.t) : S = struct
  module Backend = Backend (Outcome) (Suite)
  module PC = Outcome.ParserAndCompiler

  let cmd_name = Suite.cmd_name

  let exec_mode = Suite.exec_mode

  module CInterpreter =
    GInterpreter.Make (Outcome.Val) (Outcome.Subst) (Outcome.Store)
      (Outcome.State)
      (Outcome.External)

  let compilation_results = Hashtbl.create Config.small_tbl_size

  let cur_source_files = Hashtbl.create Config.small_tbl_size

  let cur_call_graphs = Hashtbl.create Config.small_tbl_size

  (** The test_table maps category to category tables.
      A category table maps file names to tests *)
  let test_table :
      ( Suite.category,
        (string, (Suite.info, Suite.category) Test.t) Hashtbl.t )
      Hashtbl.t =
    Hashtbl.create Config.small_tbl_size

  let add_test_to_table (test : (Suite.info, Suite.category) Test.t) =
    let cat_tbl_opt = Hashtbl.find_opt test_table test.category in
    let cat_tbl =
      match cat_tbl_opt with
      | Some c -> c
      | None   ->
          let new_cat_tbl = Hashtbl.create Config.small_tbl_size in
          let () = Hashtbl.replace test_table test.category new_cat_tbl in
          new_cat_tbl
    in
    Hashtbl.replace cat_tbl test.path test

  let register_one_test file_path =
    let code = Io_utils.load_file file_path in
    let tests =
      List.map
        (fun (name, info, category) ->
          Test.make ~name ~info ~category ~path:file_path)
        (Suite.create_tests file_path code)
    in
    List.iter add_test_to_table tests

  let register_tests file_list = List.iter register_one_test file_list

  let convert_other_imports oi =
    List.map
      (fun (ext, f) ->
        let fun_with_exn s = Stdlib.Result.get_ok (f s) in
        (ext, fun_with_exn))
      oi

  let compile_tests () =
    let open Outcome in
    let tests =
      Hashtbl.fold
        (fun _ tests_for_cat acc ->
          Hashtbl.fold (fun _ test acc -> test :: acc) tests_for_cat [] @ acc)
        test_table []
    in
    List.iter
      (fun (test : (Suite.info, Suite.category) Test.t) ->
        let () = Generators.reset () in
        let () = Suite.beforeEach () in
        let () = Suite.beforeTest test.info test.path in
        let compilation_res, source_files =
          match PC.parse_and_compile_files [ test.path ] with
          | Error err -> (Error err, None)
          | Ok progs  ->
              let e_progs = progs.gil_progs in
              let () = Gil_parsing.cache_labelled_progs e_progs in
              let e_prog = snd (List.hd e_progs) in
              let other_imports = convert_other_imports PC.other_imports in
              let prog = Gil_parsing.eprog_to_prog ~other_imports e_prog in
              (Ok prog, Some progs.source_files)
        in
        Hashtbl.add compilation_results test.path compilation_res;
        Option.fold ~none:()
          ~some:(fun files -> Hashtbl.add cur_source_files test.path files)
          source_files)
      tests

  let execute_test expect test =
    let open Outcome in
    let result = ref (Outcome.FailedExec "Execution failure") in
    let () =
      Backend.check_not_throw expect (fun () ->
          let () = Allocators.reset_all () in
          let () = CInterpreter.reset () in
          let res =
            match Hashtbl.find compilation_results test.Test.path with
            | Error err -> ParseAndCompileError err
            | Ok prog   -> (
                match UP.init_prog prog with
                | Error _ -> failwith "Failed to create unification plan"
                | Ok prog ->
                    let ret = CInterpreter.evaluate_prog prog in
                    let call_graph = CInterpreter.call_graph in
                    let copy = CallGraph.merge (CallGraph.make ()) call_graph in
                    Hashtbl.add cur_call_graphs test.path copy;
                    FinishedExec ret )
          in
          result := res)
    in
    !result

  let register_expectations () =
    Hashtbl.iter
      (Backend.register_expectations_for_category
         ~expectation:Expectations.expectation ~test_runner:execute_test)
      test_table

  let run_all ~test_suite_path =
    let start_time = Sys.time () in
    let list_files =
      List.filter Suite.filter_source (Utils.Io_utils.get_files test_suite_path)
    in
    Fmt.pr "Registering and compiling tests...\n@?";
    let () = Suite.init_suite list_files in
    let () = register_tests list_files in
    let () = compile_tests () in
    let cur_time = Sys.time () in
    Fmt.pr "Time to compile all: %f\n@?" (cur_time -. start_time);
    let () = register_expectations () in
    Backend.run ()
end

type t = (module S)

let cmd_name (r : t) =
  let (module R) = r in
  R.cmd_name

let run_all (r : t) =
  let (module R) = r in
  R.run_all

let exec_mode (r : t) =
  let (module R) = r in
  R.exec_mode

module DummyRunners = struct
  let runners = []
end
