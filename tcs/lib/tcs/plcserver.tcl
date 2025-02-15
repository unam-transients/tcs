########################################################################

# This file is part of the UNAM telescope control system.

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
package require "plc[config::getvalue "plc" "type"]"
package require "log"
package require "server"

package provide "plcserver" 0.0

namespace eval "plcserver" {

  ######################################################################

  proc slaveinitialize {} {
    plc::initialize
  }

  proc slavestop {} {
    plc::stop
  }

  proc slavereset {} {
    plc::reset
  }

  proc slaveopen {} {
    plc::open
  }

  proc slaveclose {} {
    plc::close
  }
  
  proc slavesetforcemustbeclosed {value} {
    plc::setforcemustbeclosed $value
  }
  
  proc slavespecial {command args} {
    plc::special $command $args
  }
  
  proc configureslave {slave} {
    interp alias $slave initialize           {} plcserver::slaveinitialize
    interp alias $slave stop                 {} plcserver::slavestop
    interp alias $slave reset                {} plcserver::slavereset
    interp alias $slave open                 {} plcserver::slaveopen
    interp alias $slave close                {} plcserver::slaveclose
    interp alias $slave setforcemustbeclosed {} plcserver::slavesetforcemustbeclosed
    interp alias $slave special              {} plcserver::slavespecial
  }

  ######################################################################

  proc start {} {
    plc::start
    server::listen plc plcserver::configureslave
  }

  ######################################################################

}
