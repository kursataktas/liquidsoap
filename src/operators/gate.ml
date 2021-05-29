(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2021 Savonet team

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
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

 *****************************************************************************)

open Mm
open Source

class gate ~kind ~threshold ~attack ~release ~hold ~range ~window
  (source : source) =
  object (self)
    inherit operator ~name:"gate" kind [source]

    method stype = source#stype

    method remaining = source#remaining

    method seek = source#seek

    method is_ready = source#is_ready

    method abort_track = source#abort_track

    method self_sync = source#self_sync

    (* Position of the gate between 0. and 1. *)
    val mutable gate = 1.

    method gate = gate

    (* Smoothed peak. *)
    val mutable peak = 0.

    (* Current state. *)
    val mutable state = `Open

    (* Time remaining before closing. *)
    val mutable hold_delay =
      int_of_float (hold () *. float (Lazy.force Frame.audio_rate))

    method private get_frame buf =
      let offset = AFrame.position buf in
      source#get buf;
      let position = AFrame.position buf in
      let buf = AFrame.pcm buf in
      let chans = self#audio_channels in
      let samplerate = float (Lazy.force Frame.audio_rate) in
      let attack = attack () in
      let attack_rate = 1. /. (attack *. samplerate) in
      let release = release () in
      let release_rate = 1. /. (release *. samplerate) in
      let threshold = threshold () in
      let threshold_lin = Audio.lin_of_dB threshold in
      let window_coef = 1. -. exp (-1. /. (window () *. samplerate)) in
      let range = range () in
      let hold = int_of_float (hold () *. samplerate) in
      for i = offset to position - 1 do
        let x =
          let x = ref 0. in
          for c = 0 to chans - 1 do
            x := max !x (abs_float buf.(c).{i})
          done;
          peak <- peak +. (window_coef *. (!x -. peak));
          peak
        in
        ( match state with
          | `Closed -> if x > threshold_lin then state <- `Opening
          | `Opening ->
              gate <- gate +. attack_rate;
              if gate >= 1. then (
                gate <- 1.;
                hold_delay <- hold;
                state <- `Open )
          | `Open ->
              if x < threshold_lin then
                if hold_delay <= 0 then state <- `Closing
                else hold_delay <- hold_delay - 1
              else hold_delay <- hold
          | `Closing ->
              gate <- gate -. release_rate;
              if x >= threshold_lin then state <- `Opening
              else if gate <= 0. then (
                gate <- 0.;
                state <- `Closed ) );
        let gain = Audio.lin_of_dB (range *. (1. -. gate)) in
        for c = 0 to chans - 1 do
          buf.(c).{i} <- buf.(c).{i} *. gain
        done
      done
  end

let () =
  let kind = Lang.audio_pcm in
  let return_t = Lang.kind_type_of_kind_format kind in
  Lang.add_operator "gate"
    [
      ( "attack",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 10.),
        Some "Time to fully open the gate (ms)." );
      ( "release",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 2000.),
        Some "Time to fully close the gate (ms)." );
      ( "threshold",
        Lang.getter_t Lang.float_t,
        Some (Lang.float (-30.)),
        Some "Threshold at which the gate will open (dB)." );
      ( "hold",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1000.),
        Some "Minimum amount of time the gate stays open (ms)." );
      ( "range",
        Lang.getter_t Lang.float_t,
        Some (Lang.float (-30.)),
        Some "Difference between closed and open level (dB)." );
      ( "window",
        Lang.getter_t Lang.float_t,
        Some (Lang.float 1.),
        Some "Duration for computing peak (ms)." );
      ("", Lang.source_t return_t, None, None);
    ]
    ~return_t ~category:Lang.SoundProcessing
    ~descr:
      "Reduce the volume when the stream is silent (typically in order to \
       avoid low intensity noise)."
    ~meth:
      [
        ( "gate",
          ([], Lang.fun_t [] Lang.float_t),
          "Position of the gate (0. means closed, 1. means open).",
          fun s -> Lang.val_fun [] (fun _ -> Lang.float s#gate) );
      ]
    (fun p ->
      let threshold = List.assoc "threshold" p |> Lang.to_float_getter in
      let attack = List.assoc "attack" p |> Lang.to_float_getter in
      let attack () = attack () /. 1000. in
      let release = List.assoc "release" p |> Lang.to_float_getter in
      let release () = release () /. 1000. in
      let hold = List.assoc "hold" p |> Lang.to_float_getter in
      let hold () = hold () /. 1000. in
      let range = List.assoc "range" p |> Lang.to_float_getter in
      let window = List.assoc "window" p |> Lang.to_float_getter in
      let window () = window () /. 1000. in
      let src = List.assoc "" p |> Lang.to_source in
      let kind = Source.Kind.of_kind kind in
      new gate ~kind ~threshold ~attack ~release ~hold ~range ~window src)
