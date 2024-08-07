########################################################################

# This file is part of the UNAM telescope control system.

########################################################################

# Copyright © 2009, 2011, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

AC_INIT(tcs, 0.0, alan@astro.unam.mx)

########################################################################

# tclsh is installed into:
#   /usr/local/opt/tcl-tk/bin by Homebrew
#   /usr/bin by apt-get

TCLSH_PATH="/usr/local/opt/tcl-tk/bin:/usr/local/bin:/usr/bin:/bin"

AC_ARG_VAR([TCLSH], [full path to tclsh])
AC_PATH_PROG([TCLSH], [tclsh8.6], [], [$TCLSH_PATH])
if test "$TCLSH" = ""
then
  AC_MSG_ERROR("tclsh is required.")
fi

AC_MSG_CHECKING(tclsh version)
TCL_VERSION=$(echo 'puts $tcl_version' | $TCLSH)
AC_MSG_RESULT($TCL_VERSION)
case $TCL_VERSION in
  [[01234567].*|8.[012345]])
    AC_MSG_ERROR(tclsh version 8.6 or higher is required.)
    ;;
esac

AC_SUBST(TCL_VERSION)

TCL_LIBDIR="$(echo "$TCLSH" | sed 's:bin/tclsh.*:lib:')"

AC_SUBST(TCL_LIBDIR)

########################################################################

AC_SEARCH_LIBS(FLIOpen, fli, AC_DEFINE(HAVE_LIBFLI),,-lm)

########################################################################

AC_PROG_CXX(g++)

AC_PROG_F77(gfortran)
AC_F77_LIBRARY_LDFLAGS

########################################################################

AC_CONFIG_FILES(Makefile)
AC_OUTPUT

########################################################################
