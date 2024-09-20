########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
package require "telescopecontroller[config::getvalue "telescopecontroller" "type"]"
package require "log"
package require "server"

package provide "telescopecontrollerserver" 0.0

namespace eval "telescopecontrollerserver" {

  ######################################################################

  proc slaveinitialize {} {
    telescopecontroller::initialize
  }

  proc slavestop {} {
    telescopecontroller::stop
  }

  proc slavereset {} {
    telescopecontroller::reset
  }

  proc slaveresetpanic {} {
    telescopecontroller::resetpanic
  }

  proc slaveswitchon {} {
    telescopecontroller::switchon
  }

  proc slaveswitchoff {} {
    telescopecontroller::switchoff
  }

  proc configureslave {slave} {
    interp alias $slave initialize {} telescopecontrollerserver::slaveinitialize
    interp alias $slave stop       {} telescopecontrollerserver::slavestop
    interp alias $slave reset      {} telescopecontrollerserver::slavereset
    interp alias $slave resetpanic {} telescopecontrollerserver::slaveresetpanic
    interp alias $slave switchon   {} telescopecontrollerserver::slaveswitchon
    interp alias $slave switchoff  {} telescopecontrollerserver::slaveswitchoff
  }

  ######################################################################

  proc start {} {
    telescopecontroller::start
    server::listen telescopecontroller telescopecontrollerserver::configureslave
  }

  ######################################################################

}
