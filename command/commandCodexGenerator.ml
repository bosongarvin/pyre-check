(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open Core

open Ast
open Pyre
open Service

let to_json ~root handles =
  let get_sources =
    List.fold
      ~init:[]
      ~f:(fun sources path ->
          match AstSharedMemory.get_source path with
          | Some source -> source::sources
          | None -> sources)
  in
  let sources = get_sources handles in
  `Assoc (List.map sources ~f:(Codex.source_to_json root))

let run is_parallel source_root () =
  if Sys.is_directory source_root <> `Yes then
    raise (Invalid_argument (Format.asprintf "`%s` is not a directory" source_root));

  let configuration =
    Configuration.create
      ~parallel:is_parallel
      ~source_root:(Path.create_absolute source_root)
      ()
  in
  let scheduler = Scheduler.create ~configuration () in
  let root = Path.create_absolute source_root in

  Log.info "Parsing...";
  let source_handles = Service.Parser.parse_sources scheduler ~configuration in

  Log.info "Generating JSON for Codex...";
  to_json ~root:(Path.absolute root) source_handles
  |> Yojson.Safe.to_string
  |> Log.print "%s"


let command =
  Command.basic_spec
    ~summary:"Generates JSON for Codex without a server"
    Command.Spec.(
      empty
      +> flag "-parallel" no_arg ~doc:"Runs Pyre processing in parallel."
      +> anon (maybe_with_default "." ("source-root" %: string)))
    run
