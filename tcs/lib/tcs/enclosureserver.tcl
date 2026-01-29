########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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


package require "log"
package require "server"

set enclosuretype [config::getvalue "enclosure" "type"]
switch -exact $enclosuretype {
  "arts" {
    package require "enclosurearts"
  }
  "plc" {
    package require "enclosureplc"
  }
  default {
    error "invalid enclosure type \"$enclosuretype\"."
  }
}

package provide "enclosureserver" 0.0

namespace eval "enclosureserver" {

  ######################################################################

  proc slaveinitialize {} {
    enclosure::initialize
  }

  proc slavestop {} {
    enclosure::stop
  }

  proc slavereset {} {
    enclosure::reset
  }

  proc slaveopen {{position ""}} {
    enclosure::open $position
  }

  proc slaveopentoventilate {} {
    enclosure::opentoventilate
  }

  proc slaveclose {} {
    enclosure::close
  }
  
  proc slaveemergencyclose {} {
    enclosure::emergencyclose
  }

  proc configureslave {slave} {
    interp alias $slave initialize     {} enclosureserver::slaveinitialize
    interp alias $slave stop           {} enclosureserver::slavestop
    interp alias $slave reset          {} enclosureserver::slavereset
    interp alias $slave open           {} enclosureserver::slaveopen
    interp alias $slave opentoventilate     {} enclosureserver::slaveopentoventilate
    interp alias $slave close          {} enclosureserver::slaveclose
    interp alias $slave emergencyclose {} enclosureserver::slaveemergencyclose
  }

  ######################################################################

  proc start {} {
    enclosure::start
    server::listen enclosure enclosureserver::configureslave
  }

  ######################################################################

}
