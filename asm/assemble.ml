open String
open Unix

let run cmd args =
  let open Shexp_process in
  let open Shexp_process.Infix in
  eval (run cmd args |- read_all)

let asm_name directory name = Printf.sprintf "%s/%s.s" directory name

let object_name directory name = Printf.sprintf "%s/%s.o" directory name

let binary_name directory name = Printf.sprintf "%s/%s.exe" directory name

let macos () = run "uname" ["-s"] |> String.trim |> String.equal "Darwin"

let asm_to_file instrs asm_file =
  let text =
    instrs
    |> List.map (Directive.string_of_directive ~macos:(macos ()))
    |> String.concat "\n"
  in
  let file =
    Unix.openfile asm_file [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o666
  in
  Unix.single_write_substring file text 0 (String.length text) |> ignore

let assemble asm_file object_file =
  let format = if macos () then "macho64" else "elf64" in
  run "nasm" [asm_file; "-o"; object_file; "-f"; format] |> ignore

let copy_runtime runtime_file runtime_text =
  let file =
    Unix.openfile runtime_file [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o666
  in
  Unix.single_write_substring file runtime_text 0 (String.length runtime_text)
  |> ignore

let link object_file runtime_file binary_file =
  let disable_pie = if macos () then "-Wl,-no_pie" else "-no-pie" in
  run "gcc" [disable_pie; object_file; runtime_file; "-o"; binary_file]
  |> ignore

let remove_object_files object_file runtime_file =
  run "rm" [object_file; runtime_file] |> ignore

let build directory runtime name instrs =
  let _ = try Unix.mkdir directory 0o777 with Unix.Unix_error _ -> () in
  let asm_file = asm_name directory name in
  let object_file = object_name directory name in
  let runtime_file = object_name directory "runtime" in
  let binary_file = binary_name directory name in
  asm_to_file instrs asm_file ;
  assemble asm_file object_file ;
  copy_runtime runtime_file runtime ;
  link object_file runtime_file binary_file ;
  remove_object_files object_file runtime_file ;
  binary_file

let eval directory runtime name args instrs =
  run (build directory runtime name instrs) args
