########################################################################

# This file is part of the RATTEL executor control system.

########################################################################

# Copyright © 2012, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "executor"
package require "log"
package require "server"

package provide "executorserver" 0.0

namespace eval "executorserver" {

  ######################################################################

  proc slavestop {} {
    executor::stop
    return
  }

  proc slavereset {} {
    executor::reset
    return
  }
  
  proc slaverecovertoopen {} {
    executor::recovertoopen
    return
  }
  
  proc slaverecovertoclosed {} {
    executor::recovertoclosed
    return
  }
  
  proc slaveinitialize {} {
    executor::initialize
    return
  }
  
  proc slaveopen {} {
    executor::open
    return
  }
  
  proc slaveopentoventilate {} {
    executor::opentoventilate
    return
  }
  
  proc slaveclose {} {
    executor::close
    return
  }
  
  proc slaveemergencyclose {} {
    executor::emergencyclose
    return
  }
  
  proc slavepark {} {
    executor::park
    return
  }
  
  proc slaveunpark {} {
    executor::unpark
    return
  }
  
  proc slaveexecute {filetype filename} {
    executor::execute $filetype $filename
    return
  }
  
  proc slaveidle {} {
    executor::idle
    return
  }
  
  proc slaveemergencystop {} {
    executor::emergencystop
    return
  }

  proc slaveinterrupt {} {
    executor::interrupt
    return
  }
  
  proc configureslave {slave} {
    interp alias $slave stop            {} executorserver::slavestop
    interp alias $slave reset           {} executorserver::slavereset
    interp alias $slave recovertoopen   {} executorserver::slaverecovertoopen
    interp alias $slave recovertoclosed {} executorserver::slaverecovertoclosed
    interp alias $slave initialize      {} executorserver::slaveinitialize
    interp alias $slave open            {} executorserver::slaveopen
    interp alias $slave opentoventilate {} executorserver::slaveopentoventilate
    interp alias $slave close           {} executorserver::slaveclose
    interp alias $slave emergencyclose  {} executorserver::slaveemergencyclose
    interp alias $slave park            {} executorserver::slavepark
    interp alias $slave unpark          {} executorserver::slaveunpark
    interp alias $slave execute         {} executorserver::slaveexecute
    interp alias $slave idle            {} executorserver::slaveidle
    interp alias $slave emergencystop   {} executorserver::slaveemergencystop
    interp alias $slave interrupt       {} executorserver::slaveinterrupt
  }

  ######################################################################

  proc start {} {
    executor::start
    server::listen executor executorserver::configureslave
  }

  ######################################################################

}
