########################################################################

# This file is part of the RATTEL supervisor control system.

########################################################################

# Copyright © 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "supervisor"
package require "log"
package require "server"

package provide "supervisorserver" 0.0

namespace eval "supervisorserver" {

  ######################################################################

  proc slaveenable {} {
    supervisor::enable
    return
  }

  proc slavedisable {} {
    supervisor::disable
    return
  }

  proc slaveopen {} {
    supervisor::open
    return
  }
  
  proc slaveclose {} {
    supervisor::close
    return
  }

  proc slaveabandonnight {} {
    supervisor::abandonnight
  }
  
  proc slaverequestaccess {} {
    supervisor::requestaccess
    return
  }
  
  proc slaveemergencyclose {} {
    supervisor::emergencyclose
    return
  }

  
  ######################################################################

  proc configureslave {slave} {

    interp alias $slave enable         {} supervisorserver::slaveenable
    interp alias $slave disable        {} supervisorserver::slavedisable
    interp alias $slave open           {} supervisorserver::slaveopen
    interp alias $slave close          {} supervisorserver::slaveclose
    interp alias $slave abandonnight   {} supervisorserver::slaveabandonnight
    interp alias $slave requestaccess  {} supervisorserver::slaverequestaccess
    interp alias $slave emergencyclose {} supervisorserver::slaveemergencyclose
    
  }

  ######################################################################

  proc start {} {
    supervisor::start
    server::listen supervisor supervisorserver::configureslave
  }

  ######################################################################

}
