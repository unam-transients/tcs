////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

// $Id: detectorfli.cxx 3542 2020-05-16 00:42:23Z Alan $

////////////////////////////////////////////////////////////////////////

// Copyright © 2010, 2011, 2013, 2014, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include "detector.h"

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

#include "libfli.h"

#define CHECK_FLI_CALL(f,e) \
  do { \
    if ((f) != 0) \
      DETECTOR_ERROR(e); \
  } while (0)

static flidev_t device = -1;

////////////////////////////////////////////////////////////////////////

static char *
stripspace(char *s)
{
  char *t = s;
  char *u = s;
  while (1) {
    while (*t == ' ')
      ++t;
    *u = *t;
    if (*t == 0)
      break;
    ++u;
    ++t;
  }
  return s;
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawstart(void)
{
  DETECTOR_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

static const char *
opendevice(flidev_t *device, flidomain_t domain, const char *identifier)
{
  for (int i = 0; i < 10; ++i) {
    *device = FLI_INVALID_DEVICE;
    char name[DETECTOR_STR_BUFFER_SIZE];
    snprintf(name, sizeof(name), "/dev/fliusb%x", i);
    if (FLIOpen(device, name, domain) != 0) {
      *device = FLI_INVALID_DEVICE;
      continue;
    }
    if (strcmp(identifier, "first") == 0)
      break;
    char serialstring[DETECTOR_STR_BUFFER_SIZE];
    CHECK_FLI_CALL(
      FLIGetSerialString(*device, serialstring, sizeof(serialstring)),
      "unable to determine the serial number of a device."
    );
    if (strcmp(identifier, serialstring) == 0)
      break;
    CHECK_FLI_CALL(
      FLIClose(*device),
      "unable to close a device."
    );
    *device = FLI_INVALID_DEVICE;
  }
  if (*device == FLI_INVALID_DEVICE)
    DETECTOR_ERROR("unable to open device.");
  if (0) {
    FILE *fp = fopen("/tmp/readmode", "w");
    flimode_t modeindex = 0;
    char modedescription[DETECTOR_STR_BUFFER_SIZE];
    while (FLIGetCameraModeString(*device, modeindex, modedescription, sizeof (modedescription)) == 0) {
      fprintf(fp, "readmode %d = \"%s\"\n", (int) modeindex, modedescription);
      ++modeindex;
    }
    fclose(fp);
  }
  return "ok";
}

const char *
detectorrawopen(char *identifier)
{
  //FLISetDebugLevel(NULL, FLIDEBUG_ALL);

  if (detectorrawgetisopen())
    DETECTOR_ERROR("a detector is currently opened.");

  { 
    const char *result = opendevice(&device, FLIDEVICE_CAMERA|FLIDOMAIN_USB, identifier);
    if (strcmp(result, "ok") != 0)
      return result;
  }
  
  CHECK_FLI_CALL(
    FLIControlBackgroundFlush(device, FLI_BGFLUSH_START),
    "unable to set background flushing."
  );
  
  char model[DETECTOR_STR_BUFFER_SIZE];
  char serial[DETECTOR_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetModel(device, model, sizeof(model)),
    "unable to determine the detector model."
  );
  const char *microlineprefix = "MicroLine ";
  if (strncmp(model, microlineprefix, strlen(microlineprefix)) == 0) {
    memmove(
      model,
      model + strlen(microlineprefix),
      strlen(model) - strlen(microlineprefix) + 1
    );
  }
  CHECK_FLI_CALL(
    FLIGetSerialString(device, serial, sizeof(serial)),
    "unable to determine the serial number of the detector."
  );
  stripspace(model);
  stripspace(serial);
  snprintf(description, sizeof(description), "FLI %s (%s)", model, serial);    
  
  detectorrawsetisopen(true);
  
  // There is no public FLI API to determine the cooler set temperature.
  // However, when we open the CCD, we turn the cooler off (by setting
  // the hardware setpoint to 100 C) and set the software setpoint to 25
  // C.
  
  coolersettemperature = 25.0;
  cooler = "off";
  CHECK_FLI_CALL(
    FLISetTemperature(device, 100.0),
    "unable to turn the cooler off."
  );
  
  long ulx, uly, lrx, lry;
  CHECK_FLI_CALL(
    FLIGetArrayArea(device, &ulx, &uly, &lrx, &lry),
    "unable to determine the detector format."
  );
  fullnx = lrx - ulx;
  fullny = lry - uly;
  
  return detectorrawsetwindow(0, 0, 0, 0);
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawclose(void)
{
  detectorrawsetisopen(false);
  CHECK_FLI_CALL(
    FLIClose(device),
    "unable to close the detector."
  );
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

  CHECK_FLI_CALL(
    FLISetExposureTime(device, (long) (exposuretime * 1e3)),
    "unable to set the exposure time."
  );

  fliframe_t f;
  if (strcmp(shutter, "open") == 0)
    f = FLI_FRAME_TYPE_NORMAL;
  else if (strcmp(shutter, "closed") == 0)
    f = FLI_FRAME_TYPE_DARK;
  else
    DETECTOR_ERROR("invalid shutter argument.");
  CHECK_FLI_CALL(
    FLISetFrameType(device, f),
    "unable to set the frame type."
  );

  CHECK_FLI_CALL(
    FLIExposeFrame(device),
    "unable to start the exposure."
  );
  
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawcancel(void)
{
  DETECTOR_CHECK_OPEN();
  CHECK_FLI_CALL(
    FLICancelExposure(device),
    "unable to cancel the exposure."
  );
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

bool
detectorrawgetreadytoberead(void)
{
  DETECTOR_CHECK_OPEN();
  long timeleft;
  if (FLIGetExposureStatus(device, &timeleft) != 0)
    return false;
  return timeleft == 0;
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
  unsigned short usbuf[fullnx];
  long lbuf[nx];
  detectorrawpixstart();
  for (unsigned long iy = 0; iy < ny; ++iy) {
    CHECK_FLI_CALL(
      FLIGrabRow(device, usbuf, nx),
      "unable to read the detector."
    );
    for (unsigned long ix = 0; ix < nx; ++ix) {
      lbuf[ix] = usbuf[ix];
    }
    detectorrawpixnext(lbuf, nx);
  }
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
  flimode_t modeindex = 0;
  char trialmodedescription[DETECTOR_STR_BUFFER_SIZE];
  while (
    FLIGetCameraModeString(device, modeindex, trialmodedescription, sizeof (trialmodedescription)) == 0 &&
    strcmp(newreadmode, stripspace(trialmodedescription)) != 0
  ) {
    ++modeindex;
  }
  if (strcmp(newreadmode, trialmodedescription) != 0) {
    DETECTOR_ERROR("invalid detector read mode.");
  }
  CHECK_FLI_CALL(
    FLISetCameraMode(device, modeindex),
    "unable to set detector read mode."
  );
  snprintf(readmode, sizeof(readmode), "%s", newreadmode);
  DETECTOR_OK();
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

  // The FLISetImageArea handles binning oddly, so we'll temporarily set the binning to 1.
  CHECK_FLI_CALL(
    FLISetHBin(device, 1),
    "unable to set the detector binning."
  );
  CHECK_FLI_CALL(
    FLISetVBin(device, 1),
    "unable to set the detector binning."
  );
  
  unsigned long ulx = newsx;
  unsigned long uly = newsy;
  unsigned long lrx = newsx + newnx;
  unsigned long lry = newsy + newny;
  CHECK_FLI_CALL(
    FLISetImageArea(device, ulx, uly, lrx, lry),
    "unable to set the detector window."
  );

  windowsx = newsx;
  windowsy = newsy;
  windownx = newnx;
  windowny = newny;
  return detectorrawsetbinning(binning); 
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawsetbinning(unsigned long newbinning)
{
  DETECTOR_CHECK_OPEN();
  CHECK_FLI_CALL(
    FLISetHBin(device, newbinning),
    "unable to set the detector binning."
  );
  CHECK_FLI_CALL(
    FLISetVBin(device, newbinning),
    "unable to set the detector binning."
  );
  binning = newbinning;  
  detectorrawsetpixnx((windownx + binning - 1) / binning);
  detectorrawsetpixny((windowny + binning - 1) / binning);
  DETECTOR_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
detectorrawupdatestatus(void)
{
  DETECTOR_CHECK_OPEN();

  flimode_t modeindex;
  CHECK_FLI_CALL(
    FLIGetCameraMode(device, &modeindex),
    "unable to determine the detector read mode."
  );
  static char readmodebuffer[DETECTOR_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetCameraModeString(device, modeindex, readmodebuffer, sizeof(readmodebuffer)),
    "unable to determine the detector read mode."
  );
  snprintf(readmode, sizeof(readmode), "%s", stripspace(readmodebuffer));

  CHECK_FLI_CALL(
    FLIReadTemperature(device, FLI_TEMPERATURE_INTERNAL, &detectortemperature),
    "unable to determine the detector temperature."
  );

  CHECK_FLI_CALL(
    FLIReadTemperature(device, FLI_TEMPERATURE_EXTERNAL, &housingtemperature),
    "unable to determine the housing temperature."
  );

  if (strcmp(cooler, "following") == 0) {
    coolersettemperature = housingtemperature;
    CHECK_FLI_CALL(
      FLISetTemperature(device, coolersettemperature),
      "unable to set the cooler set temperature."
    );
  }

  CHECK_FLI_CALL(
    FLIGetCoolerPower(device, &coolerpower),
    "unable to determine the cooler power."
  );
  coolerpower /= 100;

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
  if (strcmp(newcooler, "off") == 0) {
    // There is no public FLI API to turn the cooler off, so we set the
    // detector set point to 100 C.
    CHECK_FLI_CALL(
      FLISetTemperature(device, 100.0),
      "unable to turn the cooler off."
    );
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
    CHECK_FLI_CALL(
      FLISetTemperature(device, coolersettemperature),
      "unable to set the cooler set temperature."
    );
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
