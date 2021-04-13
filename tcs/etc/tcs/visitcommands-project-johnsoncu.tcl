########################################################################

# This file is part of the UNAM telescope control system.

# $Idvisit: alertvisit-project-ddotioan 3388 2019-11-01 19:50:09Z Alan $

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

proc alertcommand {filters} {
  log::summary "alertcommand: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning 1
  set i 0
  while {$i < 20} {
    executor::expose object 60
    incr i
    coroutine::after 10000
  }
  log::summary "alertcommand: finished."
  return true
}

########################################################################

proc biasesvisit {} {
  log::summary "biasesvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning 1
  set i 0
  while {$i < 20} {
    executor::expose bias 0
    executor::analyze levels
    incr i
    coroutine::after 10000
  }
  log::summary "biasesvisit: finished."
  return true
}

########################################################################

proc darksvisit {} {
  log::summary "darksvisit: starting."
  executor::move
  executor::setwindow "default"
  executor::setbinning 1
  set i 0
  while {$i < 20} {
    executor::expose dark 60
    executor::analyze levels
    incr i
    coroutine::after 10000
  }
  log::summary "darksvisit: finished."
  return true
}

########################################################################
