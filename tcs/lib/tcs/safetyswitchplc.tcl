########################################################################

# This file is part of the UNAM telescope control system.

# $Id: safetyswitchplc.tcl 3594 2020-06-10 14:55:51Z Alan $

########################################################################

# Copyright © 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "config"
package require "client"
package require "log"
package require "server"
package require "utcclock"

package provide "safetyswitchplc" 0.0

namespace eval "safetyswitch" {

  variable svnid {$Id}

  ######################################################################

  proc checksafetyswitch {} {
    set start [utcclock::seconds]
    log::info "checking the safety switch."
    set safetyswitch ""
    if {
      [catch {client::update "plc"}] ||
      [catch {set safetyswitch [client::getdata "plc" "mode"]}] ||
      [string equal $safetyswitch ""]
    } {
      error "unable to determine the state of the safety switch."
    }
    server::setdata "safetyswitch" $safetyswitch
    if {![string equal $safetyswitch "remote"]} {
      error "the safety switch is not in remote mode."
    }
    log::info [format "finished checking the safety switch after %.1f seconds." [utcclock::diff now $start]]
  }

  ######################################################################

}
