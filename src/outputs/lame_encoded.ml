(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2007 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 *****************************************************************************)

(** Outputs using the LAME encoder for MP3. *)

open Source
open Dtools
open Lame

let create_encoder ~samplerate ~bitrate ~quality ~stereo =
  let enc = Lame.create_encoder () in
    (* Input settings *)
    Lame.set_in_samplerate enc (Fmt.samples_per_second ()) ;
    Lame.set_num_channels enc (Fmt.channels ()) ;
    (* Output settings *)
    Lame.set_mode enc (if stereo then Lame.Stereo else Lame.Mono) ;
    Lame.set_quality enc quality ;
    Lame.set_out_samplerate enc samplerate ;
    Lame.set_brate enc bitrate ;
    Lame.init_params enc ;
    enc

class virtual base =
object (self)
  method encode e b start len =
    if Fmt.channels () = 1 then
      Lame.encode_buffer_float_part e b.(0) b.(0) start len
    else
      Lame.encode_buffer_float_part e b.(0) b.(1) start len
end

(** Output in an MP3 file *)

class to_file
  ~filename ~samplerate ~bitrate ~quality ~stereo ~autostart source =
object (self)
  inherit
    [Lame.encoder] Output.encoded
         ~name:filename ~kind:"output.file" ~autostart source
  inherit base

  method reset_encoder encoder m = ""

  val mutable fd = None

  method output_start =
    assert (fd = None) ;
    let enc = create_encoder ~quality ~bitrate ~stereo ~samplerate in
      fd <- Some (open_out filename) ;
      encoder <- Some enc

  method output_stop =
    match fd with
      | None -> assert false
      | Some v -> close_out v ; fd <- None

  method send b =
    match fd with
      | None -> assert false
      | Some fd -> output_string fd b

  method output_reset = ()
end

let () =
  Lang.add_operator "output.file.mp3"
    [ "start",
      Lang.bool_t, Some (Lang.bool true),
      Some "Start output threads on operator initialization." ;

      "samplerate",
      Lang.int_t,
      Some (Lang.int 44100),
      None ;

      "bitrate",
      Lang.int_t,
      Some (Lang.int 128),
      None ;

      "quality",
      Lang.int_t,
      Some (Lang.int 5),
      None ;

      "stereo",
      Lang.bool_t,
      Some (Lang.bool true),
      None;

      "",
      Lang.string_t,
      None,
      Some "Filename where to output the MP3 stream." ;

      "", Lang.source_t, None, None ]
    ~category:Lang.Output
    ~descr:"Output the source's stream as an MP3 file."
    (fun p ->
       let e f v = f (List.assoc v p) in
       let quality = e Lang.to_int "quality" in
       let autostart = e Lang.to_bool "start" in
       let stereo = e Lang.to_bool "stereo" in
       let samplerate = e Lang.to_int "samplerate" in
       let bitrate = e Lang.to_int "bitrate" in
       let filename = Lang.to_string (Lang.assoc "" 1 p) in
       let source = Lang.assoc "" 2 p in
         ((new to_file ~filename
             ~quality ~bitrate ~samplerate ~stereo ~autostart source):>source))
