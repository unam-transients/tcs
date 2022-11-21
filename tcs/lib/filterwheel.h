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

#include <stddef.h>

#if !SWIG

#define FILTERWHEEL_MAX_INDEX 9
#define FILTERWHEEL_STR_BUFFER_SIZE 1024

#define FILTERWHEEL_ERROR(s)  return (s)
#define FILTERWHEEL_OK()      return "ok"

#define FILTERWHEEL_SHOULD_NOT_BE_CALLED() \
  do { \
    fprintf(stderr, "ERROR: %s:%lu: raw filter wheel function \"%s\" should not have been called.\n", \
      __FILE__, (unsigned long) __LINE__, __FUNCTION__); \
    abort(); \
  } while(0)

#define FILTERWHEEL_CHECK_OPEN(index) \
  do { \
    if (!filterwheelrawgetisopen(index)) \
      FILTERWHEEL_ERROR("no filter wheel is currently opened."); \
  } while (0)

#endif

// These functions must be implemented for each type of filter wheel, either in C++ or Tcl.

extern const char *filterwheelrawstart(void);
extern const char *filterwheelrawopen(size_t index, char *);
extern const char *filterwheelrawclose(size_t index);

extern const char *filterwheelrawreset(size_t index);

extern const char *filterwheelrawupdatestatus(size_t index);
extern const char *filterwheelrawgetvalue(size_t index, const char *);

extern const char *filterwheelrawmove(size_t index, long);
extern const char *filterwheelrawhome(size_t index);

// These C++ functions are shared by all filterwheels.

extern const char *filterwheelrawsetisopen(size_t index, bool);
extern bool        filterwheelrawgetisopen(size_t index);

