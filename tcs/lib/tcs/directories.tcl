########################################################################

# This file is part of the UNAM telescope control system.

# $Id: directories.tcl 3576 2020-05-23 20:24:48Z Alan $

########################################################################

# Copyright © 2010, 2011, 2012, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

package require "environment"
package require "utcclock"

package provide "directories" 0.0

namespace eval "directories" {

  variable svnid {$Id}

  ######################################################################
  
  variable prefix [file normalize [file join [file dirname [info script]] ".." ".."]]
  
  proc prefix {} {
    variable prefix
    return $prefix
  }
  
  variable bindirectory   [file normalize [file join [prefix] "bin"]]
  variable etcdirectory   [file normalize [file join [prefix] "etc" "tcs"]]
  variable vardirectory   [file normalize [file join [prefix] "var" "tcs"]]
  variable sharedirectory [file normalize [file join [prefix] "share" "tcs"]]
  
  proc bin {} {
    variable bindirectory
    return $bindirectory
  }

  proc etc {} {
    variable etcdirectory
    return $etcdirectory
  }

  proc var {} {
    variable vardirectory
    catch {file mkdir $vardirectory}
    return $vardirectory
  }

  proc share {} {
    variable sharedirectory
    return $sharedirectory
  }
  
  proc varfordate {{seconds now}} {
    variable vardirectory
    set directory [file join $vardirectory [utcclock::formatdate $seconds false]]
    catch {file mkdir $directory}
    return $directory    
  }

  proc vartoday {{seconds now}} {
    variable vardirectory
    set directory [file join $vardirectory [utcclock::formatdate $seconds false]]
    catch {file mkdir $directory}
    linklatest $directory
    return $directory    
  }
  
  proc linklatest {filename} {
    set targetname [file tail $filename]
    set linkname   [file join [file dirname $filename] "latest[file extension $filename]"]
    if {[catch {file readlink $linkname} currenttargetname]} {
      set currenttargetname ""
    }
    if {![string equal $currenttargetname $targetname]} {
      catch {exec "/bin/ln" "-sfT" $targetname $linkname.[pid]}
      catch {exec "/bin/mv" "-fT" $linkname.[pid] $linkname}
      catch {exec "/bin/rm" "-f" $linkname.[pid]}
    }
  }
  
  ######################################################################

}
