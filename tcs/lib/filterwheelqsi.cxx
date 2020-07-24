////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: filterwheelqsi.cxx 3540 2020-05-11 18:06:24Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2011, 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
//
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the
// above copyright notice and this permission notice appear in all
// copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
// DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
// PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
// TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

////////////////////////////////////////////////////////////////////////

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fitsio.h>
#include <qsiapi.h>

#include "filterwheel.h"
#include "detector.h"

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawstart(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawopen(char *identifier)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawclose(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawreset(void)
{
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawhome(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawmove(long newposition)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawupdatestatus(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawgetvalue(const char *)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////
