########################################################################

# This file is part of the UNAM telescope control system.

# $Id: schedulerserver.tcl 3590 2020-05-27 00:18:20Z Alan $

########################################################################

# Copyright © 2012, 2013, 2014, 2015, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "scheduler"
package require "log"
package require "server"

package provide "schedulerserver" 0.0

namespace eval "schedulerserver" {

  variable svnid {$Id}

  ######################################################################

  proc slavestop {} {
    scheduler::stop
    return
  }

  proc slavereset {} {
    scheduler::reset
    return
  }

  proc slaveenable {} {
    scheduler::enable
    return
  }

  proc slavedisable {} {
    scheduler::disable
    return
  }
  
  proc slaverespondtoalert {proposalidentifier blockidentifier type eventidentifier alerttimestamp eventtimestamp enabled alpha delta equinox uncertainty} {
    scheduler::respondtoalert $proposalidentifier $blockidentifier $type $eventidentifier $alerttimestamp $eventtimestamp $enabled $alpha $delta $equinox $uncertainty
  }

  proc slaverespondtolvcalert {proposalidentifier blockidentifier type eventidentifier alerttimestamp eventtimestamp enabled skymapurl} {
    scheduler::respondtolvcalert $proposalidentifier $blockidentifier $type $eventidentifier $alerttimestamp $eventtimestamp $enabled $skymapurl
  }

  proc slavesetfocused {} {
    scheduler::setfocused
  }

  proc slavesetunfocused {} {
    scheduler::setunfocused
  }

  proc configureslave {slave} {
    interp alias $slave stop              {} schedulerserver::slavestop
    interp alias $slave reset             {} schedulerserver::slavereset
    interp alias $slave enable            {} schedulerserver::slaveenable
    interp alias $slave disable           {} schedulerserver::slavedisable
    interp alias $slave respondtoalert    {} schedulerserver::slaverespondtoalert
    interp alias $slave respondtolvcalert {} schedulerserver::slaverespondtolvcalert
    interp alias $slave setfocused        {} schedulerserver::slavesetfocused
    interp alias $slave setunfocused      {} schedulerserver::slavesetunfocused
  }

  ######################################################################

  proc start {} {
    scheduler::start
    server::listen scheduler schedulerserver::configureslave
  }

  ######################################################################

}
