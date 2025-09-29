////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2016, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#include <qhyccd.h>

#include "detector.h"

////////////////////////////////////////////////////////////////////////

static const char *description = "dummy";
static double detectortemperature = 0;
static double housingtemperature = 0;
static double coolerpower = 0;
static double coolersettemperature = 0;
static const char *cooler = "";

static char readmode[DETECTOR_STR_BUFFER_SIZE] = "";

static unsigned long fullnx = 2048;
static unsigned long fullny = 2048;
static unsigned long unbinnedwindowsx = 0;
static unsigned long unbinnedwindowsy = 0;
static unsigned long unbinnedwindownx = 0;
static unsigned long unbinnedwindowny = 0;

static unsigned long binning = 1;

////////////////////////////////////////////////////////////////////////

static time_t exposureend = 0;

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawopen(char *identifier)
{
  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently open.");
  detectorrawsetisopen(true);
  coolersettemperature = 0.0;
  cooler = "off";
  return detectorrawsetunbinnedwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  detectorrawsetisopen(false);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawreset(void)
{
  DETECTOR_CHECK_OPEN();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawmovefilterwheel(unsigned long position)
{
  DETECTOR_CHECK_OPEN();
  if (position != 0)
    DETECTOR_ERROR("unable to move the filter wheel.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawexpose(double exposuretime, const char *shutter)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(shutter, "open") != 0 && strcmp(shutter, "closed") != 0)
    DETECTOR_ERROR("invalid shutter argument.");
  exposureend = time(NULL) + exposuretime;
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  exposureend = 0;
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool
detectorrawgetreadytoberead(void)
{
  return time(NULL) > exposureend;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawread(void)
{
  DETECTOR_CHECK_OPEN();
  if (!detectorrawgetreadytoberead())
    DETECTOR_ERROR("the detector is not ready to be read.");
  long pix = 0;
  unsigned long nx = detectorrawgetpixnx();
  unsigned long ny = detectorrawgetpixny();
  for (unsigned long iy = 0; iy < ny; ++iy) {
    for (unsigned long ix = 0; ix < nx; ++ix) {
      pix = ix;
      detectorrawpixnext(&pix, 1);
    }
  }
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(newreadmode, "") == 0)
    DETECTOR_OK();
  if (strlen(newreadmode) >= DETECTOR_STR_BUFFER_SIZE) {
    DETECTOR_ERROR("invalid detector read mode.");
  }
  strcpy(readmode, newreadmode);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetunbinnedwindow(unsigned long newsx, unsigned long newsy, unsigned long newnx, unsigned long newny)
{
  DETECTOR_CHECK_OPEN();
  if (newsx == 0 && newnx == 0) {
    newnx = fullnx;
  }
  if (newsy == 0 && newny == 0) {
    newny = fullny;
  }
  unbinnedwindowsx = newsx;
  unbinnedwindowsy = newsy;
  unbinnedwindownx = newnx;
  unbinnedwindowny = newny;
  return detectorrawsetbinning(1); 
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_CHECK_OPEN();
  binning = newbinning;
  detectorrawsetpixnx((unbinnedwindownx + binning - 1) / binning);
  detectorrawsetpixny((unbinnedwindowny + binning - 1) / binning);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(cooler, "on") == 0) {
    detectortemperature = coolersettemperature;
    coolerpower = 1.0;
  } else if (strcmp(cooler, "following") == 0) {
    coolersettemperature = housingtemperature;
    detectortemperature = coolersettemperature;
    coolerpower = 0.5;
  } else {
    detectortemperature = housingtemperature + 10;
    coolerpower = 0;
  }
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawgetvalue(const char *name)
{
  static char value[DETECTOR_STR_BUFFER_SIZE]; 
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  else if (strcmp(name, "detectortemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", detectortemperature);
  else if (strcmp(name, "housingtemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", housingtemperature);
  else if (strcmp(name, "coolersettemperature") == 0)
    snprintf(value, sizeof(value), "%+.1f", coolersettemperature);
  else if (strcmp(name, "coolerpower") == 0)
    snprintf(value, sizeof(value), "%.2f", coolerpower);
  else if (strcmp(name, "cooler") == 0)
    snprintf(value, sizeof(value), "%s", cooler);
  else if (strcmp(name, "readmode") == 0)
    snprintf(value, sizeof(value), "%s", readmode);
  else if (strcmp(name, "unbinnedwindowsx") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowsx);
  else if (strcmp(name, "unbinnedwindowsy") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowsy);
  else if (strcmp(name, "unbinnedwindownx") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindownx);
  else if (strcmp(name, "unbinnedwindowny") == 0)
    snprintf(value, sizeof(value), "%lu", unbinnedwindowny);
  else if (strcmp(name, "binning") == 0)
    snprintf(value, sizeof(value), "%lu", binning);
  else
    snprintf(value, sizeof(value), "%s", detectorrawgetdatavalue(name));
  return value;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetcooler(const char *newcooler)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(newcooler, "on") == 0) {
    cooler = "on";
    DETECTOR_OK();
  } else if (strcmp(newcooler, "off") == 0) {
    cooler = "off";
    DETECTOR_OK();
  } else if (strcmp(newcooler, "following") == 0) {
    cooler = "following";    
    coolersettemperature = housingtemperature;
    DETECTOR_OK();
  } else {
    char *end;
    coolersettemperature = strtod(newcooler, &end);
    if (*end != 0)
      DETECTOR_ERROR("invalid arguments.");
    cooler = "on";
    DETECTOR_OK();
  }
}

////////////////////////////////////////////////////////////////////////

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
