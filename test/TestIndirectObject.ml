(*****************************************************************************)
(*  Caradoc: a PDF parser and validator                                      *)
(*  Copyright (C) 2015 ANSSI                                                 *)
(*                                                                           *)
(*  This program is free software; you can redistribute it and/or modify     *)
(*  it under the terms of the GNU General Public License version 2 as        *)
(*  published by the Free Software Foundation.                               *)
(*                                                                           *)
(*  This program is distributed in the hope that it will be useful,          *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(*  GNU General Public License for more details.                             *)
(*                                                                           *)
(*  You should have received a copy of the GNU General Public License along  *)
(*  with this program; if not, write to the Free Software Foundation, Inc.,  *)
(*  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.              *)
(*****************************************************************************)


open OUnit
open Directobject
open Indirectobject.IndirectObject
open Mapkey
open Errors
open Boundedint
open Params
open Pdfstream


let init_params () =
  Params.clear_global ();
  Params.global.Params.sort_dicts <- true

let tests =
  "IndirectObject" >:::
  [
    "to_string" >:::
    [
      "direct" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct DirectObject.Null))
                      "null") ;
        "(2)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Bool true)))
                      "true") ;
        "(3)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Int ~:531)))
                      "531") ;
        "(4)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Real "1.0")))
                      "1.0") ;
        "(5)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.String "hello\nworld")))
                      "(hello\\nworld)") ;
        "(6)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Name "hello")))
                      "/hello") ;
        "(7)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Array [DirectObject.Bool true ; DirectObject.String "blabla" ; DirectObject.Name "key"])))
                      "[true (blabla) /key]") ;
        "(8)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Dictionary (TestDict.add_all ["Key", DirectObject.String "value" ; "Foo", DirectObject.Name "bar"]))))
                      "<<\n    /Foo /bar\n    /Key (value)\n>>") ;
        "(9)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Direct (DirectObject.Reference (Key.make_gen ~:3 ~:2))))
                      "3 2 R") ;
      ] ;

      "stream" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Stream (TestStream.make_decoded "stream content")))
                      "<<\n    /Length 14\n>>\nstream <decoded stream of length 14>") ;
        "(2)" >:: (fun _ -> assert_equal
                      (init_params ();
                       Params.global.Params.expand_streams <- true;
                       to_string (Stream (TestStream.make_decoded "stream content")))
                      "<<\n    /Length 14\n>>\nstream <decoded stream of length 14>\nstream content\nendstream\n") ;
        "(3)" >:: (fun _ -> assert_equal
                      (init_params (); to_string (Stream (TestStream.make_raw_dict ["foo", DirectObject.String "bar"] "encoded content")))
                      "<<\n    /Length 15\n    /foo (bar)\n>>\nstream <encoded stream of length 15>") ;
        "(4)" >:: (fun _ -> assert_equal
                      (init_params ();
                       Params.global.Params.expand_streams <- true;
                       to_string (Stream (TestStream.make_raw "encoded content")))
                      "<<\n    /Length 15\n>>\nstream <encoded stream of length 15>\nencoded content\nendstream\n") ;
      ] ;
    ] ;

    "to_pdf" >:::
    [
      "direct" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct DirectObject.Null))
                      "null") ;
        "(2)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Bool false)))
                      "false") ;
        "(3)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Int ~:(-10))))
                      "-10") ;
        "(4)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Real "1.0")))
                      "1.0") ;
        "(5)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.String "hello\n\r\t\b\x0C\\world")))
                      "(hello\\n\\r\\t\\b\\f\\\\world)") ;
        "(6)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Name "hello\n#world")))
                      "/hello#0A#23world") ;
        "(7)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Array [DirectObject.String "test" ; DirectObject.Bool true ; DirectObject.Int ~:123 ; DirectObject.String "blabla" ; DirectObject.Name "key" ; DirectObject.Null ; DirectObject.Name "name" ; DirectObject.Name "other" ; DirectObject.String "value" ; DirectObject.Int ~:456])))
                      "[(test)true 123(blabla)/key null/name/other(value)456]") ;
        "(8)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Dictionary (TestDict.add_all ["Key", DirectObject.String "value" ; "Foo", DirectObject.Bool false ; "G", DirectObject.Dictionary (TestDict.add_all ["Nested", DirectObject.Int ~:456])]))))
                      "<</Foo false/G<</Nested 456>>/Key(value)>>") ;
        "(9)" >:: (fun _ -> assert_equal
                      (to_pdf (Direct (DirectObject.Reference (Key.make_gen ~:3 ~:2))))
                      "3 2 R") ;
      ] ;

      "stream" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (to_pdf (Stream (TestStream.make_raw "raw content")))
                      "<</Length 11>>stream\nraw content\nendstream") ;
      ] ;
    ] ;

    "refs" >:::
    [
      "direct" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (refs (Direct (DirectObject.Array [DirectObject.Reference (Key.make_gen ~:2 ~:1) ; DirectObject.Reference (Key.make_0 ~:5) ; DirectObject.Reference (Key.make_gen ~:2 ~:1) ; DirectObject.Reference (Key.make_0 ~:3) ; DirectObject.Reference (Key.make_0 ~:123456)])))
                      (TestSetkey.add_all [Key.make_gen ~:2 ~:1 ; Key.make_0 ~:5 ; Key.make_0 ~:3 ; Key.make_0 ~:123456])) ;
      ] ;

      "stream" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (refs (Stream (TestStream.make_raw_dict ["Key", DirectObject.Reference (Key.make_0 ~:2)] "raw content")))
                      (TestSetkey.add_all [Key.make_0 ~:2])) ;
      ] ;
    ] ;

    "relink" >:::
    [
      "direct" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (relink (TestMapkey.add_all [Key.make_0 ~:4, Key.make_0 ~:1 ; Key.make_0 ~:3, Key.make_0 ~:2]) Key.Trailer
                         (Direct (DirectObject.Array [DirectObject.Reference (Key.make_0 ~:3) ; DirectObject.Array [DirectObject.Reference (Key.make_0 ~:4)]])))
                      (Direct (DirectObject.Array [DirectObject.Reference (Key.make_0 ~:2) ; DirectObject.Array [DirectObject.Reference (Key.make_0 ~:1)]]))) ;
        "(2)" >:: (fun _ -> assert_equal
                      (relink (TestMapkey.add_all [Key.make_0 ~:4, Key.make_0 ~:1 ; Key.make_0 ~:3, Key.make_0 ~:2]) Key.Trailer
                         (Direct (DirectObject.Dictionary (TestDict.add_all ["Key", DirectObject.Reference (Key.make_0 ~:3) ; "Other", DirectObject.Reference (Key.make_0 ~:4)]))))
                      (Direct (DirectObject.Dictionary (TestDict.add_all ["Other", DirectObject.Reference (Key.make_0 ~:1) ; "Key", DirectObject.Reference (Key.make_0 ~:2)])))) ;

        "(3)" >:: (fun _ -> assert_raises
                      (Errors.PDFError ("Reference to unknown object : 2", Errors.make_ctxt_key Key.Trailer))
                      (fun () -> relink MapKey.empty Key.Trailer (Direct (DirectObject.Reference (Key.make_0 ~:2))))) ;
      ] ;

      "stream" >:::
      [
        "(1)" >:: (fun _ -> assert_equal
                      (relink (TestMapkey.add_all [Key.make_0 ~:2, Key.make_0 ~:1]) Key.Trailer
                         (Stream (TestStream.make_raw_dict ["Key", DirectObject.Reference (Key.make_0 ~:2)] "raw content")))
                      (Stream (TestStream.make_raw_dict ["Key", DirectObject.Reference (Key.make_0 ~:1)] "raw content"))) ;
      ] ;
    ] ;

    "get_direct" >:::
    [
      "(1)" >:: (fun _ -> assert_equal
                    (get_direct "msg" Errors.ctxt_none (Direct (DirectObject.String "blabla")))
                    (DirectObject.String "blabla")) ;
      "(2)" >:: (fun _ -> assert_equal
                    (get_direct "msg" Errors.ctxt_none (Direct DirectObject.Null))
                    DirectObject.Null) ;

      "(3)" >:: (fun _ -> assert_raises
                    (Errors.PDFError ("msg", Errors.ctxt_none))
                    (fun () -> get_direct "msg" Errors.ctxt_none (Stream (TestStream.make_raw "")))) ;
    ] ;

    "get_direct_of" >:::
    [
      "(1)" >:: (fun _ -> assert_equal
                    (get_direct_of "msg" Errors.ctxt_none ~transform:(DirectObject.get_name ()) (Direct (DirectObject.Name "foo")))
                    "foo") ;
      "(2)" >:: (fun _ -> assert_equal
                    (get_direct_of "msg" Errors.ctxt_none ~transform:(DirectObject.get_positive_int ()) (Direct (DirectObject.Int ~:123)))
                    ~:123) ;

      "(3)" >:: (fun _ -> assert_raises
                    (Errors.PDFError ("msg", Errors.ctxt_none))
                    (fun () -> get_direct_of "msg" Errors.ctxt_none ~transform:(DirectObject.get_name ()) (Direct (DirectObject.String "foo")))) ;
      "(4)" >:: (fun _ -> assert_raises
                    (Errors.PDFError ("msg", Errors.ctxt_none))
                    (fun () -> get_direct_of "msg" Errors.ctxt_none ~transform:(DirectObject.get_name ()) (Stream (TestStream.make_raw "content")))) ;
    ] ;

    "get_stream" >:::
    [
      "(1)" >:: (fun _ -> assert_equal
                    (get_stream "msg" Errors.ctxt_none (Stream (TestStream.make_raw "content")))
                    (TestStream.make_raw "content")) ;

      "(2)" >:: (fun _ -> assert_raises
                    (Errors.PDFError ("msg", Errors.ctxt_none))
                    (fun () -> get_stream "msg" Errors.ctxt_none (Direct (DirectObject.String "blabla")))) ;
    ] ;
  ]

