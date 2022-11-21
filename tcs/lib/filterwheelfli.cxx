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

static char description[FILTERWHEEL_MAX_INDEX + 1][FILTERWHEEL_STR_BUFFER_SIZE];
static long maxposition[FILTERWHEEL_MAX_INDEX + 1];
static long position[FILTERWHEEL_MAX_INDEX + 1];
static bool ishomed[FILTERWHEEL_MAX_INDEX + 1];

////////////////////////////////////////////////////////////////////////

#include "libfli.h"

static flidev_t device[FILTERWHEEL_MAX_INDEX + 1];

#define CHECK_FLI_CALL(f,e) \
  do { \
    if ((f) != 0) { \
      fprintf(stderr, "FLI error: %s\n", (e)); \
      FILTERWHEEL_ERROR(e); \
    } \
  } while (0)


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
  int j = 0;
  for (int i = 0; i < 10; ++i) {
    *device = FLI_INVALID_DEVICE;
    char name[FILTERWHEEL_STR_BUFFER_SIZE];
    snprintf(name, sizeof(name), "/dev/fliusb%x", i);
fprintf(stderr, "trying \"%s\".\n", name);
    if (FLIOpen(device, name, domain) != 0) {
      *device = FLI_INVALID_DEVICE;
      continue;
    }
    ++j;
fprintf(stderr, "j == %d  and identifier is %s.\n", j, identifier);
    if (j == 1 && strcmp(identifier, "first") == 0)
      break;
    if (j == 2 && strcmp(identifier, "second") == 0)
      break;
    if (j == 3 && strcmp(identifier, "third") == 0)
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
fprintf(stderr, "found device\n");
  if (*device == FLI_INVALID_DEVICE)
    FILTERWHEEL_ERROR("unable to open device.");
  return "ok";
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawopen(size_t index, char *identifier)
{
  //FLISetDebugLevel(NULL, FLIDEBUG_ALL);

fprintf(stderr, "filterwheelrawopen: index is %ld.\n", (unsigned long) index);
fprintf(stderr, "filterwheelrawopen: identifier is \"%s\".\n", (unsigned long) identifier);

  if (filterwheelrawgetisopen(index))
    FILTERWHEEL_ERROR("filter wheel is currently opened.");
  
fprintf(stderr, "filter wheel is not currently open.\n");

  { 
    const char *result = opendevice(&device[index], FLIDEVICE_FILTERWHEEL|FLIDOMAIN_USB, identifier);
    if (strcmp(result, "ok") != 0)
      return result;
  }

fprintf(stderr, "filter wheel is now open.\n");

  char model[FILTERWHEEL_STR_BUFFER_SIZE];
  char serial[FILTERWHEEL_STR_BUFFER_SIZE];
  CHECK_FLI_CALL(
    FLIGetModel(device[index], model, sizeof(model)),
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
    FLIGetSerialString(device[index], serial, sizeof(serial)),
    "unable to determine the serial number of the filter wheel."
  );
  stripspace(model);
fprintf(stderr, "model is \"%s\".\n", model);
  stripspace(serial);
fprintf(stderr, "serial is \"%s\".\n", serial);
  snprintf(description[index], sizeof(description[index]), "%s-(%s)", model, serial);    
  
  filterwheelrawsetisopen(index, true);

  CHECK_FLI_CALL(
    FLIGetFilterCount(device[index], &maxposition[index]),
    "unable to determine the filter wheel maximum position."
  );
  maxposition[index] -= 1;
printf("maxposition is %d.\n", (int) maxposition[index]);
  CHECK_FLI_CALL(
    FLISetFilterPos(device[index], 0),
    "unable to initialize the filter wheel."
  );

fprintf(stderr, "finished opening.\n");

  FILTERWHEEL_OK();

}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawclose(size_t index)
{
  filterwheelrawsetisopen(index, false);
  CHECK_FLI_CALL(
    FLIClose(device[index]),
    "unable to close the filter wheel."
  );
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
  CHECK_FLI_CALL(
    FLISetFilterPos(device[index], newposition),
    "unable to set the filter wheel position."
  );
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawhome(size_t index)
{
  FILTERWHEEL_CHECK_OPEN(index);
  CHECK_FLI_CALL(
    FLIHomeDevice(device[index]),
    "unable to move the filter wheel to the home position."
  );
  FILTERWHEEL_OK();
}

////////////////////////////////////////////////////////////////////////

const char *
filterwheelrawupdatestatus(size_t index)
{
fprintf(stderr, "filterwheelrawupdatestatus: index is %ld.\n", (unsigned long) index);
  FILTERWHEEL_CHECK_OPEN(index);

  CHECK_FLI_CALL(
    FLIGetFilterPos(device[index], &position[index]),
    "unable to determine the filter wheel position."
  );
  long status;
  FLIGetDeviceStatus(device[index], &status);
  ishomed[index] = (status == 0x80);

fprintf(stderr, "filterwheelrawupdatestatus: finished.\n");
  FILTERWHEEL_OK();
}

const char *
filterwheelrawgetvalue(size_t index, const char *name)
{
  static char value[FILTERWHEEL_STR_BUFFER_SIZE];
  if (strcmp(name, "description") == 0)
    snprintf(value, sizeof(value), "%s", description[index]);
  else if (strcmp(name, "position") == 0)
    snprintf(value, sizeof(value), "%ld", position[index]);
  else if (strcmp(name, "maxposition") == 0)
    snprintf(value, sizeof(value), "%ld", maxposition[index]);
  else if (strcmp(name, "ishomed") == 0)
    snprintf(value, sizeof(value), "%s", ishomed[index] ? "true" : "false");
  else
    snprintf(value, sizeof(value), "");
  return value;
}

////////////////////////////////////////////////////////////////////////
