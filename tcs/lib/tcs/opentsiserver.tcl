########################################################################

# This file is part of the UNAM telescope control system.

# $Id: opentsiserver.tcl 3557 2020-05-22 18:23:30Z Alan $

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

package require "config"
package require "log"
package require "server"

package require "opentsi"

package provide "opentsiserver" 0.0

namespace eval "opentsiserver" {

  variable svnid {$Id}

  ######################################################################

  proc slaveinitialize {} {
    opentsi::initialize
  }

  proc slavestop {} {
    opentsi::stop
  }

  proc slavereset {} {
    opentsi::reset
  }

  proc slaveopen {} {
    opentsi::open
  }

  proc slaveclose {} {
    opentsi::close
  }

  proc configureslave {slave} {
    interp alias $slave initialize {} opentsiserver::slaveinitialize
    interp alias $slave stop       {} opentsiserver::slavestop
    interp alias $slave reset      {} opentsiserver::slavereset
    interp alias $slave open       {} opentsiserver::slaveopen
    interp alias $slave close      {} opentsiserver::slaveclose
  }

  ######################################################################

  proc start {} {
    opentsi::start
    server::listen opentsi opentsiserver::configureslave
  }

  ######################################################################

}
