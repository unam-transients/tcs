////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: detectorqsi.cxx 3542 2020-05-16 00:42:23Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2009, 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include "detector.h"
#include "filterwheel.h"

////////////////////////////////////////////////////////////////////////

static char description[DETECTOR_STR_BUFFER_SIZE] = "";

static char readmode[DETECTOR_STR_BUFFER_SIZE] = "";

static unsigned long fullnx = 0;
static unsigned long fullny = 0;
static unsigned long windowsx = 0;
static unsigned long windowsy = 0;
static unsigned long windownx = 0;
static unsigned long windowny = 0;
static unsigned long binning = 1;

static double coolerpower = 0;
static double coolersettemperature = 0;
static const char *cooler;

static double detectortemperature = 0;
static double housingtemperature = 0;

////////////////////////////////////////////////////////////////////////

#define CHECK_QSI_CALL(f,e) \
  do { \
    if ((f) != 0) \
      DETECTOR_ERROR(e); \
  } while (0)

////////////////////////////////////////////////////////////////////////

#include "qsiapi.h"

static QSICamera cam;
static bool hasfilterwheel = false;

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawopen(char *identifier)
{
  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently opened.");
      
  cam.put_UseStructuredExceptions(false);
  
  char fullidentifier[9];
  snprintf(fullidentifier, sizeof(fullidentifier), "%08ld", strtol(identifier, NULL, 10));
  
  CHECK_QSI_CALL(
    cam.put_SelectCamera(fullidentifier),
    "unable to select detector.");
  CHECK_QSI_CALL(
    cam.put_Connected(1),
    "unable to connect to detector.");

  static std::string ModelNumber;
  CHECK_QSI_CALL(
    cam.get_ModelNumber(ModelNumber),
    "unable to determine the detector description.");
  snprintf(description, sizeof(description), "QSI %s (%s)", ModelNumber.c_str(), fullidentifier);

  CHECK_QSI_CALL(
    cam.get_HasFilterWheel(&hasfilterwheel),
    "unable to determine if a filter wheel is present.");
  
  detectorrawsetisopen(true);
  
  coolersettemperature = 25.0;
  cooler = "off";
  CHECK_QSI_CALL(
    cam.put_FanMode(QSICamera::fanQuiet),
    "unable to set the fans to quiet.");
  CHECK_QSI_CALL(
    cam.put_CoolerOn(false),
    "unable to turn cooler off.");
  
  long nx;
  CHECK_QSI_CALL(
    cam.get_CameraXSize(&nx),
    "unable to determine detector size in x.");
  fullnx = nx;
  long ny;
  CHECK_QSI_CALL(
    cam.get_CameraYSize(&ny),
    "unable to determine detector size in y.");
  fullny = ny;

  return detectorrawsetwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  detectorrawsetisopen(false);
  cam.put_UseStructuredExceptions(false);
  CHECK_QSI_CALL(
    cam.put_Connected(0),
    "unable to close the detector.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawreset(void)
{
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawexpose(double exposuretime, const char *shutter)
{
  DETECTOR_CHECK_OPEN();
  cam.put_UseStructuredExceptions(false);

  double MaxExposureTime;
  CHECK_QSI_CALL(
    cam.get_MaxExposureTime(&MaxExposureTime),
    "cannot get maximum exposure time.");
  double MinExposureTime;
  CHECK_QSI_CALL(
    cam.get_MinExposureTime(&MinExposureTime),
    "cannot get minimum exposure time.");

  if (exposuretime > MaxExposureTime)
    exposuretime = MaxExposureTime;
  if (exposuretime < MinExposureTime)
    exposuretime = MinExposureTime;

  bool light;
  if (strcmp(shutter, "open") == 0)
    light = true;
  else if (strcmp(shutter, "closed") == 0)
    light = false;
  else
    DETECTOR_ERROR("invalid arguments.");

  CHECK_QSI_CALL(
    cam.StartExposure(exposuretime, light),
    "unable to start the exposure.");

  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  cam.put_UseStructuredExceptions(false);
  CHECK_QSI_CALL(
    cam.AbortExposure(),
    "unable to cancel the exposure.");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool
detectorrawgetreadytoberead(void)
{
  DETECTOR_CHECK_OPEN();
  cam.put_UseStructuredExceptions(false);
  bool detectoready = false;
  cam.get_ImageReady(&detectoready);
  return detectoready;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawread()
{
  DETECTOR_CHECK_OPEN();
  if (!detectorrawgetreadytoberead())
    DETECTOR_ERROR("the detector is not ready to be read.");
  unsigned long nx = detectorrawgetpixnx();
  unsigned long ny = detectorrawgetpixny();
  unsigned short *usbuf = (unsigned short *) malloc(ny * nx * sizeof(*usbuf));
  if (usbuf == NULL)
    DETECTOR_ERROR("malloc failed.");    
  CHECK_QSI_CALL(
    cam.get_ImageArray(usbuf),
    "unable to read the detector.");
  long lbuf[nx];
  detectorrawpixstart();
  for (unsigned long iy = 0; iy < ny; ++iy) {
    for (unsigned long ix = 0; ix < nx; ++ix)
      lbuf[ix] = usbuf[iy * nx + ix];
    detectorrawpixnext(lbuf, nx);
  }    
  free(usbuf);
  detectorrawpixend();
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetreadmode(const char *newreadmode)
{
  DETECTOR_CHECK_OPEN();
  if (strcmp(newreadmode, "") == 0)
    DETECTOR_OK();
  DETECTOR_ERROR("invalid detector read mode.");
}

const char *
detectorrawgetreadmode(void)
{
  return readmode;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetwindow(unsigned long newsx, unsigned long newsy, unsigned long newnx, unsigned long newny)
{
  DETECTOR_CHECK_OPEN();

  if (newsx == 0 && newnx == 0) {
    newnx = fullnx;
  }
  if (newsy == 0 && newny == 0) {
    newny = fullny;
  }

//  if (newsx != 0 && newsy != 0)
//    DETECTOR_ERROR("invalid window.");

  windowsx = newsx;
  windowsy = newsy;
  windownx = newnx;
  windowny = newny;
  return detectorrawsetbinning(1);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_CHECK_OPEN();
  
  if (
    windowsx % newbinning != 0 || 
    windowsy % newbinning != 0 ||
    windownx % newbinning != 0 ||
    windowny % newbinning != 0
  )
    DETECTOR_ERROR("binning is not commensurate with the window.");
    
  short maxbinning;
  unsigned long maxbinningx;
  CHECK_QSI_CALL(
    cam.get_MaxBinX(&maxbinning),
    "unable to get the maximum detector binning in x."
  );
  maxbinningx = maxbinning;
  unsigned long maxbinningy;
  CHECK_QSI_CALL(
    cam.get_MaxBinY(&maxbinning),
    "unable to get the maximum detector binning in y."
  );
  maxbinningy = maxbinning;
  if (newbinning > maxbinningx || newbinning > maxbinningy)
    DETECTOR_ERROR("binning is too coarse.");

  CHECK_QSI_CALL(
    cam.put_BinX(newbinning),
    "unable to set the detector binning.");
  CHECK_QSI_CALL(
    cam.put_BinY(newbinning),
    "unable to set the detector binning.");
  binning = newbinning;  
  detectorrawsetpixnx(windownx / binning);
  detectorrawsetpixny(windowny / binning);
  CHECK_QSI_CALL(
    cam.put_StartX(windowsx / binning),
    "cannot set format");
  CHECK_QSI_CALL(
    cam.put_StartY(windowsy / binning),
    "cannot set format");
  CHECK_QSI_CALL(
    cam.put_NumX(detectorrawgetpixnx()),
    "cannot set format");
  CHECK_QSI_CALL(
    cam.put_NumY(detectorrawgetpixny()),
    "cannot set format");
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();
  CHECK_QSI_CALL(
    cam.get_CCDTemperature(&detectortemperature),
    "unable to determine the detector temperature.");

  CHECK_QSI_CALL(
    cam.get_HeatSinkTemperature(&housingtemperature),
    "unable to determine the housing temperature."
  );

  if (strcmp(cooler, "following") == 0) {
    coolersettemperature = housingtemperature;
    CHECK_QSI_CALL(cam.get_SetCCDTemperature(&coolersettemperature),
      "unable to determine the cooler set temperature.");
  }

  DETECTOR_OK();
}

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
  else if (strcmp(name, "windowsx") == 0)
    snprintf(value, sizeof(value), "%lu", windowsx);
  else if (strcmp(name, "windowsy") == 0)
    snprintf(value, sizeof(value), "%lu", windowsy);
  else if (strcmp(name, "windownx") == 0)
    snprintf(value, sizeof(value), "%lu", windownx);
  else if (strcmp(name, "windowny") == 0)
    snprintf(value, sizeof(value), "%lu", windowny);
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
  cam.put_UseStructuredExceptions(false);
  if (strcmp(newcooler, "off") == 0) {
    CHECK_QSI_CALL(
      cam.put_FanMode(QSICamera::fanQuiet),
      "unable to set the fans to quiet.");
    CHECK_QSI_CALL(
      cam.put_CoolerOn(false),
      "unable to turn cooler off.");
    cooler = "off";
    DETECTOR_OK();
  } else {  
    if (strcmp(newcooler, "following") == 0) {
      detectorrawupdatestatus();
      coolersettemperature = housingtemperature;
    } else if (strcmp(newcooler, "on") != 0) {
      char *end;
      double newcoolersettemperature = strtod(newcooler, &end);
      if (*end != 0)
        DETECTOR_ERROR("invalid cooler state.");
      coolersettemperature = newcoolersettemperature;
      newcooler = "on";
    }
    CHECK_QSI_CALL(
      cam.put_FanMode(QSICamera::fanQuiet),
      "unable to set the fans to quiet.");
    CHECK_QSI_CALL(
      cam.put_SetCCDTemperature(coolersettemperature),
      "unable to set the cooler set temperature.");
    CHECK_QSI_CALL(
      cam.put_CoolerOn(true),
      "unable to turn cooler on.");
    cooler = newcooler;
    DETECTOR_OK();
  }
}

const char *
detectorrawgetcooler(void)
{
  return cooler;
}

////////////////////////////////////////////////////////////////////////

static unsigned long position;
static unsigned long maxposition;

const char *
detectorrawfilterwheelmove(unsigned long newposition)
{
  DETECTOR_CHECK_OPEN();
  CHECK_QSI_CALL(
    cam.put_Position(newposition),
    "unable to move the filter wheel.");
  DETECTOR_OK();
}

const char *
detectorrawfilterwheelupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();
  if (hasfilterwheel) {
    int filtercount;
    CHECK_QSI_CALL(
      cam.get_FilterCount(filtercount),
      "unable to determine the filter wheel maximum position.");
    maxposition = filtercount - 1;
    short i;
    CHECK_QSI_CALL(
      cam.get_Position(&i),
      "unable to determine the filter wheel position.");
    position = i;
  } else {
    maxposition = 0;
    position    = 0;
  }
  DETECTOR_OK();
}

const char *
detectorrawfilterwheelgetvalue(const char *name)
{
  static char value[FILTERWHEEL_STR_BUFFER_SIZE];
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  else if (strcmp(name, "position") == 0)
    snprintf(value, sizeof(value), "%ld", position);
  else if (strcmp(name, "maxposition") == 0)
    snprintf(value, sizeof(value), "%ld", maxposition);
  else
    snprintf(value, sizeof(value), "");
  return value;
}

////////////////////////////////////////////////////////////////////////
