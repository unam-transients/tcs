////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2013, 2014, 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include <float.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

// These function should never be called; they exist only to keep the loader happy.

const char *
detectorrawstart(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawopen(char *identifier)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawclose(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawreset(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawgetvalue(const char *)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawsetcooler(const char *newcoolerstate)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawsetunbinnedwindow(unsigned long newsx, unsigned long newsy, unsigned long newnx, unsigned long newny)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

bool
detectorrawgetreadytoberead(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawread()
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawcancel(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *detectorrawexpose(double exposuretime, const char *shutter)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawaugmentfitsheader(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawfilterwheelmove(unsigned long newposition)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawfilterwheelupdatestatus(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

const char *
detectorrawfilterwheelgetvalue(const char *name)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////
