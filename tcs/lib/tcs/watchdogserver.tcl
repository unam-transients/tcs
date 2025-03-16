########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "watchdog"
package require "log"
package require "server"

package provide "watchdogserver" 0.0

namespace eval "watchdogserver" {

  ######################################################################

  proc slaveenable {} {
    watchdog::enable
    return
  }

  proc slavedisable {} {
    watchdog::disable
    return
  }
  
  proc slavereset {} {
    watchdog::reset
    return
  }
  
  proc configureslave {slave} {
    interp alias $slave enable            {} watchdogserver::slaveenable
    interp alias $slave disable           {} watchdogserver::slavedisable
    interp alias $slave reset             {} watchdogserver::slavereset
  }

  ######################################################################

  proc start {} {
    watchdog::start
    server::listen watchdog watchdogserver::configureslave
  }

  ######################################################################

}
