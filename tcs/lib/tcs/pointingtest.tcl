#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: executorserver 2585 2017-02-15 22:21:23Z alan $

########################################################################

# Copyright © 2009 Alan M. Watson <alan@astro.unam.mx>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
# DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
# PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

########################################################################

#\
umask 0; PATH=/usr/local/opt/tcl-tk/bin:$PATH exec tclsh8.6 -encoding "utf-8" "$0" ${1+"$@"}

set prefix [file normalize [file join [file dirname [info script]] ".." ".."]]
source [file join [directories::prefix] "lib" "tcs" "packages.tcl"]

package require "pointing"

proc test {ha delta dx0 dy0} {
  set parameters {
  IH 0.00266302456489445
  ID -1.64083176950246e-05
  CHS 0.000211697382685725
  NPS 0.000395119749680931
  MA -0.00311468991893478
  ME 0.0028566038290536
  TF 0.000438662086694434
  }
  set ha    [astrometry::parseha $ha] 
  set delta [astrometry::parsedelta $delta] 
  set dx1 [expr {[pointing::modeldha $parameters $ha $delta] * cos($delta)}]
  set dy1 [pointing::modelddelta $parameters $ha $delta]
  set ddx [expr {$dx1 - $dx0}]
  set ddy [expr {$dy1 - $dy0}]  
  puts [format "%+3.0fd %+3.0fd %+4.0fas %+4.0fas" [astrometry::radtodeg $ha] [astrometry::radtodeg $delta] [astrometry::radtoarcsec $ddx] [astrometry::radtoarcsec $ddy]]
}

test 1.13346147213093 0.524493640343324 0.00501155384762808 -0.00174421221079969
test 1.14628989779655 0.0010480497709268 0.00322167765100643 -0.00190415491446461
test 1.15447040428546 1.04802240676289 0.00558238527514107 -0.00169108961750068
test 0.375024043734431 1.04668273020813 0.00543922878050374 0.00169031554470611
test 0.38269309546231 0.523157926572273 0.00483281821704233 0.00144868911770832
test 0.389368681577147 -0.000351068539357233 0.00301585678181509 0.00121767868116448
test 0.396489803889709 -0.523744162880347 0.00047666349275095 0.00104646710800523
test -0.380653028844846 1.04565466478985 0.00222565842467311 0.00398141279094617
test -0.374219300367566 0.522142516495485 0.0026871582076125 0.00375944860551047
test -0.367799974265462 -0.00136400720265373 0.00231416628992898 0.00354237337019487
test -0.361858824063403 -0.524712147384443 0.00120527111636857 0.00338597064787255
test -1.14018955447587 -0.00133511723114843 0.00211206245791386 0.00377992580560831
test -1.13320751308807 0.522053247335745 0.000927068820814037 0.00389863387153381
test -1.12644082555867 1.04554660436545 -0.000630640723242051 0.0040501385730031
