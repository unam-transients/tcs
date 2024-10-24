########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "telescope[config::getvalue "telescope" "type"]"

package provide "telescopeserver" 0.0

namespace eval "telescopeserver" {

  ######################################################################

  proc slavestartup {} {
    telescope::startup
  }

  proc slaveshutdown {} {
    telescope::shutdown
  }

  proc slavereset {} {
    telescope::reset
  }

  proc slaverecover {} {
    telescope::recover
  }

  proc slavestop {} {
    telescope::stop
  }
  
  proc slaveemergencystop {} {
    telescope::emergencystop
  }
  
  proc slaveinitialize {} {
    telescope::initialize
  }

  proc slaveopen {} {
    telescope::open
  }

  proc slaveopentoventilate {} {
    telescope::opentoventilate
  }

  proc slaveclose {} {
    telescope::close
  }

  proc slaveemergencyclose {} {
    telescope::emergencyclose
  }

  proc slavemove {coordinate0 coordinate1 {system "equatorial"}} {
    telescope::move $coordinate0 $coordinate1 $system
  }
  
  proc slavemovetoidle {} {
    telescope::movetoidle
  }
  
  proc slavemovetozenith {} {
    telescope::movetozenith
  }
  
  proc slavemoveawayfromsun {} {
    telescope::moveawayfromsun
  }
  
  proc slavepark {} {
    telescope::park
  }
  
  proc slaveunpark {} {
    telescope::unpark
  }
  
  proc slavetrack {alpha delta equinox {alphaoffset 0} {deltaoffset 0} {epoch "now"} {alpharate 0} {deltarate 0} {aperture "default"}} {
    telescope::track $alpha $delta $equinox $alphaoffset $deltaoffset $epoch $alpharate $deltarate $aperture
  }
  
  proc slavetrackcatalogobject {catalogname objectname {aperture "default"}} {
    telescope::trackcatalogobject $catalogname $objectname $aperture
  }

  proc slavetracktopocentric {ha delta {aperture "default"}} {
    telescope::tracktopocentric $ha $delta $aperture
  }
  
  proc slaveoffset {{alphaoffset 0} {deltaoffset 0} {aperture "default"}} {
    telescope::offset $alphaoffset $deltaoffset $aperture
  }
  
  proc slavesetpointingaperture {aperture} {
    telescope::setpointingaperture $aperture
  }

  proc slavecorrect {{truemountalpha ""} {truemountdelta ""} {equinox ""}} {
    telescope::correct $truemountalpha $truemountdelta $equinox
  }
  
  proc slavemovesecondary {{z0 "z0"} {setasinitial false}} {
    telescope::movesecondary $z0 $setasinitial
  }
  
  proc slavesetsecondaryoffset {dz} {
    telescope::setsecondaryoffset $dz
  }
  
  ######################################################################

  proc configureslave {slave} {

    interp alias $slave startup                     {} telescopeserver::slavestartup
    interp alias $slave shutdown                    {} telescopeserver::slaveshutdown
    interp alias $slave reset                       {} telescopeserver::slavereset
    interp alias $slave recover                     {} telescopeserver::slaverecover
    interp alias $slave stop                        {} telescopeserver::slavestop
    interp alias $slave initialize                  {} telescopeserver::slaveinitialize
    interp alias $slave open                        {} telescopeserver::slaveopen
    interp alias $slave opentoventilate                  {} telescopeserver::slaveopentoventilate
    interp alias $slave close                       {} telescopeserver::slaveclose
    interp alias $slave emergencyclose              {} telescopeserver::slaveemergencyclose
    interp alias $slave move                        {} telescopeserver::slavemove
    interp alias $slave movetoidle                  {} telescopeserver::slavemovetoidle
    interp alias $slave movetozenith                {} telescopeserver::slavemovetozenith
    interp alias $slave moveawayfromsun             {} telescopeserver::slavemoveawayfromsun
    interp alias $slave park                        {} telescopeserver::slavepark
    interp alias $slave unpark                      {} telescopeserver::slaveunpark
    interp alias $slave track                       {} telescopeserver::slavetrack
    interp alias $slave trackcatalogobject          {} telescopeserver::slavetrackcatalogobject
    interp alias $slave tracktopocentric            {} telescopeserver::slavetracktopocentric
    interp alias $slave offset                      {} telescopeserver::slaveoffset
    interp alias $slave setpointingaperture         {} telescopeserver::slavesetpointingaperture
    interp alias $slave correct                     {} telescopeserver::slavecorrect
    interp alias $slave movesecondary               {} telescopeserver::slavemovesecondary
    interp alias $slave setsecondaryoffset          {} telescopeserver::slavesetsecondaryoffset
    interp alias $slave emergencystop               {} telescopeserver::slaveemergencystop

  }

  ######################################################################

  proc start {} {
    telescope::start
    server::listen telescope telescopeserver::configureslave
  }

  ######################################################################

}
