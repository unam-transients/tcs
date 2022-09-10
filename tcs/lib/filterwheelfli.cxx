////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2013, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include "filterwheel.h"

////////////////////////////////////////////////////////////////////////

static char description[FILTERWHEEL_STR_BUFFER_SIZE] = "";
static long maxposition;
static long position;
static bool ishomed;

////////////////////////////////////////////////////////////////////////

#include "libfli.h"

#define CHECK_FLI_CALL(f,e) \
  do { \
    if ((f) != 0) { \
      fprintf(stderr, "FLI error: %s\n", (e)); \
      FILTERWHEEL_ERROR(e); \
    } \
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
filterwheelrawstart(void)
{
  FILTERWHEEL_SHOULD_NOT_BE_CALLED();
}

////////////////////////////////////////////////////////////////////////

static const char *
opendevice(flidev_t *device, flidomain_t domain, const char *identifier)
{
  for (int i = 0; i < 10; ++i) {
    *device = FLI_INVALID_DEVICE;
    char name[FILTERWHEEL_STR_BUFFER_SIZE];
    snprintf(name, sizeof(name), "/dev/fliusb%x", i);
    if (FLIOpen(device, name, domain) != 0) {
      *device = FLI_INVALID_DEVICE;
      continue;
    }
    if (strcmp(identifier, "first") == 0)
      break;
    char serialstring[FILTERWHEEL_STR_BUFFER_SIZE];
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
    FILTERWHEEL_ERROR("unable to open device.");
  return "ok";
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawopen(char *identifier)
{
  //FLISetDebugLevel(NULL, FLIDEBUG_ALL);

  if (filterwheelrawgetisopen())
    FILTERWHEEL_ERROR("a filterwheel is currently opened.");
  
  { 
    const char *result = opendevice(&device, FLIDEVICE_FILTERWHEEL|FLIDOMAIN_USB, identifier);
    if (strcmp(result, "ok") != 0)
      return result;
  }

  char model[FILTERWHEEL_STR_BUFFER_SIZE];
  char serial[FILTERWHEEL_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetModel(device, model, sizeof(model)),
    "unable to determine the filter wheel model."
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
    "unable to determine the serial number of the filter wheel."
  );
  stripspace(model);
  stripspace(serial);
  snprintf(description, sizeof(description), "FLI %s (%s)", model, serial);    
  
  filterwheelrawsetisopen(true);

  CHECK_FLI_CALL(
    FLIGetFilterCount(device, &maxposition),
    "unable to determine the filter wheel maximum position."
  );
  maxposition -= 1;
  CHECK_FLI_CALL(
    FLISetFilterPos(device, 0),
    "unable to initialize the filter wheel."
  );
  FILTERWHEEL_OK();

}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawclose(void)
{
  filterwheelrawsetisopen(false);
  CHECK_FLI_CALL(
    FLIClose(device),
    "unable to close the filter wheel."
  );
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
  CHECK_FLI_CALL(
    FLISetFilterPos(device, newposition),
    "unable to set the filter wheel position."
  );
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawhome(void)
{
  FILTERWHEEL_CHECK_OPEN();
  CHECK_FLI_CALL(
    FLIHomeDevice(device),
    "unable to move the filter wheel to the home position."
  );
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawupdatestatus(void)
{
  FILTERWHEEL_CHECK_OPEN();

  CHECK_FLI_CALL(
    FLIGetFilterPos(device, &position),
    "unable to determine the filter wheel position."
  );
  long status;
  FLIGetDeviceStatus(device, &status);
  ishomed = (status == 0x80);

  FILTERWHEEL_OK();
}

const char *
filterwheelrawgetvalue(const char *name)
{
  static char value[FILTERWHEEL_STR_BUFFER_SIZE];
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description);
  else if (strcmp(name, "position") == 0)
    snprintf(value, sizeof(value), "%ld", position);
  else if (strcmp(name, "maxposition") == 0)
    snprintf(value, sizeof(value), "%ld", maxposition);
  else if (strcmp(name, "ishomed") == 0)
    snprintf(value, sizeof(value), "%s", ishomed ? "true" : "false");
  else
    snprintf(value, sizeof(value), "");
  return value;
}

////////////////////////////////////////////////////////////////////////
