########################################################################

# This file is part of the UNAM telescope control system.

# $Id: detectorfli.tcl 3557 2020-05-22 18:23:30Z Alan $

########################################################################

# Copyright © 2010, 2011, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package provide "detectorfli" 0.0

load [file join [directories::prefix] "lib" "detectorfli.so"] "detector"

namespace eval "detector" {
  
  variable bscale 1.0
  variable bzero  32768.0

  proc detectorrawstart {} {
    if {[catch {exec "sudo" "/sbin/modprobe" "fliusb" "buffersize=4194304"}]} {
      error "unable to load the fliusb kernel module."
    }
    foreach file [glob "/dev/fliusb*"] {
      if {[catch {exec "sudo" "/bin/chmod" "a=rw" "$file"}]} {
        error "unable to change the permissions of $file."
      }    
    }  
  }
  
  proc detectorrawaugmentfitsheader {channel} {
    return "ok"
  }
  
}

source [file join [directories::prefix] "lib" "tcs" "detector.tcl"]
