////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

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

static char description[FILTERWHEEL_MAX_INDEX + 1][FILTERWHEEL_STR_BUFFER_SIZE];
static long maxposition[FILTERWHEEL_MAX_INDEX + 1];
static long position[FILTERWHEEL_MAX_INDEX + 1];
static bool ishomed[FILTERWHEEL_MAX_INDEX + 1];

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawstart(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawopen(size_t index, char *identifier)
{
  if (filterwheelrawgetisopen(index))
    FILTERWHEEL_ERROR("a filter wheel is currently opened.");
  if (sscanf(identifier, "%ld", &maxposition[index]) != 1)
    FILTERWHEEL_ERROR("invalid filter wheel identifier.");
  snprintf(description[index], sizeof(description[index]), "%s:%ld", "dummy", (long) maxposition[index]);    
  --maxposition[index];
  filterwheelrawsetisopen(index, true);
  position[index] = 0;
  ishomed[index] = 1;
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawclose(size_t index)
{
  filterwheelrawsetisopen(index, false);
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawreset(size_t index)
{
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawmove(size_t index, long newposition)
{
  FILTERWHEEL_CHECK_OPEN(index);
  if (newposition < maxposition[index]) {
    position[index] = newposition;
    FILTERWHEEL_OK();
  } else {
    FILTERWHEEL_ERROR("invalid filter wheel position.");
  }
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawhome(size_t index)
{
  FILTERWHEEL_CHECK_OPEN(index);
  position[index] = 0;
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawupdatestatus(size_t index)
{
  FILTERWHEEL_CHECK_OPEN(index);
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawgetvalue(size_t index, const char *name)
{
  static char value[FILTERWHEEL_STR_BUFFER_SIZE];
  value[0] = 0;
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description[index]);
  else if (strcmp(name, "position") == 0)
    snprintf(value, sizeof(value), "%ld", position[index]);
  else if (strcmp(name, "maxposition") == 0)
    snprintf(value, sizeof(value), "%ld", maxposition[index]);
  else if (strcmp(name, "ishomed") == 0)
    snprintf(value, sizeof(value), "%s", ishomed[index] ? "true" : "false");
  return value;
}

////////////////////////////////////////////////////////////////////////
