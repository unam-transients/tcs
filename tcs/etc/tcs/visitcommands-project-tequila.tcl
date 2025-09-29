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

proc starsgridvisit {
    gridpoints
    eastfullsize
    northfullsize
    exposuretimes
    filters
    {binnings 1}
    {windows "default"}
    {adapttimes false}
    {defocus false}
} {

    log::summary "starsgridvisit: starting."

    executor::setsecondaryoffset 0
    executor::track
    executor::waituntiltracking

    # For the moment, we ignore binnings, windows, adapttimes, and defocus.

    if {[string equal $gridpoints 1]} {
        set offsets {
            0.0 0.0
        }
    } elseif {[string equal $gridpoints 4]} {
        set offsets {
            -0.5 -0.5
            -0.5 +0.5
            +0.5 +0.5
            +0.5 -0.5
        }
    } elseif {[string equal $gridpoints 9]} {
        set offsets {
            +0.0 +0.0
            -0.5 -0.5
            +0.0 +0.5
            +0.5 -0.5
            -0.5 +0.0
            +0.5 +0.5
            +0.0 -0.5
            -0.5 +0.5
            +0.5 +0.0
        }
    } else {
        error "starsgridvisit: invalid gridpoints argument \"$gridpoints\"."
    }
    log::info [format "starsgridvisit: %d grid points." $gridpoints]

    set eastfullsize  [astrometry::parseoffset $eastfullsize ]
    set northfullsize [astrometry::parseoffset $northfullsize]
    log::info [format "starsgridvisit: grid size is %s east and %s north." \
        [astrometry::formatoffset $eastfullsize ] \
        [astrometry::formatoffset $northfullsize] \
    ]

set exposuretimes0 [lindex $exposuretimes 0]
set filters0       [lindex $filters       0]

foreach {eastoffset northoffset} $offsets {

    set eastoffset  [format "%+.1fas" [astrometry::radtoarcsec [expr {$eastoffset  * $eastfullsize }]]]
    set northoffset [format "%+.1fas" [astrometry::radtoarcsec [expr {$northoffset * $northfullsize}]]]

    log::info [format "starsgridvisit: offset is %s east and %s north." \
        [astrometry::formatoffset $eastoffset ] \
        [astrometry::formatoffset $northoffset] \
    ]

executor::offset $eastoffset $northoffset "default"
executor::waituntiltracking

log::info "starsgridvisit: exposing."
set i 0
while {$i < [llength $exposuretimes0]} {
    set exposuretime0 [lindex $exposuretimes0 $i]
    set filter0       [lindex $filters0       $i]
    executor::movefilterwheel $filter0 "z"
    executor::expose object $exposuretime0 $exposuretime0
    incr i
}

}

log::summary "starsgridvisit: finished."
return true
}

########################################################################

proc starswaitvisit {endtime} {
    log::info "starswait: waiting until [utcclock::format $endtime]."
    set endseconds [utcclock::scan $endtime]
    while {[utcclock::seconds] <= $endseconds} {
        coroutine::after 100
    }
}

########################################################################

proc alertvisit {{filters ""}} {
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

proc coarsefocusvisit {{exposuretime 5} {filter "i"} {readmode "conventionaldefault"}} {

    log::summary "coarsefocusvisit: starting."
    executor::setfocused
    log::summary "coarsefocusvisit: finished."

    return true
}

########################################################################

proc focusvisit {{exposuretime 5} {filter "i"}} {

    log::summary "focusvisit: starting."
    executor::setfocused
    log::summary "focusvisit: finished."

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
