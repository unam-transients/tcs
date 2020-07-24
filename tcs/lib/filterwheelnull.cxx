////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: filterwheelqsi.cxx 3373 2019-10-30 15:09:02Z Alan $

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

#include "filterwheel.h"

////////////////////////////////////////////////////////////////////////

static char description[FILTERWHEEL_STR_BUFFER_SIZE] = "";
static long maxposition;
static long position;
static bool ishomed;

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
  if (filterwheelrawgetisopen())
    FILTERWHEEL_ERROR("a filter wheel is currently opened.");
  if (strcmp(identifier, "null") != 0)
    FILTERWHEEL_ERROR("invalid filter wheel identifier.");
  snprintf(description, sizeof(description), "%s", "null");    
  filterwheelrawsetisopen(true);
  maxposition = 0;
  position = 0;
  ishomed = 1;
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawclose(void)
{
  filterwheelrawsetisopen(false);
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawreset(void)
{
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawmove(long newposition)
{
  FILTERWHEEL_CHECK_OPEN();
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawhome(void)
{
  FILTERWHEEL_CHECK_OPEN();
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawupdatestatus(void)
{
  FILTERWHEEL_CHECK_OPEN();
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawgetvalue(const char *name)
{
  static char value[FILTERWHEEL_STR_BUFFER_SIZE];
  value[0] = 0;
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  if (strcmp(name, "position") == 0)
    snprintf(value, sizeof(value), "%ld", position);
  else if (strcmp(name, "maxposition") == 0)
    snprintf(value, sizeof(value), "%ld", maxposition);
  else if (strcmp(name, "ishomed") == 0)
    snprintf(value, sizeof(value), "%s", ishomed ? "true" : "false");
  return value;
}

////////////////////////////////////////////////////////////////////////
