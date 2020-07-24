#!/bin/sh

########################################################################

# This file is part of the UNAM telescope control system.

# $Id: C0server 2959 2017-08-30 04:06:36Z alan $

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

set prefix [file normalize [file join [file dirname [info script]] ".." "tcs"]]
source [file join [directories::prefix] "lib" "tcs" "packages.tcl"]

namespace eval "log" {

  proc debug {message} {
    #puts stderr "debug: $message"
  }
  
  proc info {message} {
    puts stderr "info: $message"
  }
  
  proc warning {message} {
    puts stderr "wanring: $message"
  }
  
  proc error {message} {
    puts stderr "error: $message"
  }

}

package require "fitfocus"

set minz {} 

set n 0
set sx 0
set sy 0
set sz 0
set sxx 0
set sxz 0
set syy 0
set syz 0
set szz 0

while {true} {
  set x [gets stdin]
  if {[string equal $x ""]} {
    break
  }
  set y [gets stdin]
  set zlist [gets stdin]
  set fwhmlist [gets stdin]
  if {[catch {set z [fitfocus::findmin $zlist $fwhmlist]}]} {
    log::info "$x $y: fitting failed."
    puts stdout [format "%d,%d" $x $y]
  } else {
    log::info "$x $y: fitting succeeded $z"
    puts stdout [format "%d,%d,%.0f" $x $y $z]
    dict set minz $x $y $z
    set n   [expr {$n + 1}]
    set sx  [expr {$sx + $x}]
    set sy  [expr {$sy + $y}]
    set sz  [expr {$sz + $z}]
    set sxx [expr {$sxx + $x * $x}]
    set sxz [expr {$sxz + $x * $z}]
    set syy [expr {$syy + $y * $y}]
    set syz [expr {$syz + $y * $z}]
    set szz [expr {$szz + $z * $z}]
  }
}

set meanx [expr {$sx / $n}]
set meany [expr {$sy / $n}]
set meanz [expr {$sz / $n}]
set sxx [expr {$sxx - $n * $meanx * $meanx}]
set sxz [expr {$sxz - $n * $meanx * $meanz}]
set syy [expr {$syy - $n * $meany * $meany}]
set syz [expr {$syz - $n * $meany * $meanz}]
set szz [expr {$szz - $n * $meanz * $meanz}]

set bx [expr {$sxz / $sxx}]
set ax [expr {$meanz - $bx * $meanx}]
set by [expr {$syz / $syy}]
set ay [expr {$meanz - $by * $meany}]

info [format "ax = %.0f bx = %.0f" $ax $bx]
info [format "ay = %.0f by = %.0f" $ay $by]



