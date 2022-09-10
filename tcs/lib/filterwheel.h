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

#if !SWIG

#define FILTERWHEEL_STR_BUFFER_SIZE 1024

#define FILTERWHEEL_ERROR(s)  return (s)
#define FILTERWHEEL_OK()      return "ok"

#define FILTERWHEEL_SHOULD_NOT_BE_CALLED() \
  do { \
    fprintf(stderr, "ERROR: %s:%lu: raw filter wheel function \"%s\" should not have been called.\n", \
      __FILE__, (unsigned long) __LINE__, __FUNCTION__); \
    abort(); \
  } while(0)

#define FILTERWHEEL_CHECK_OPEN() \
  do { \
    if (!filterwheelrawgetisopen()) \
      FILTERWHEEL_ERROR("no filter wheel is currently opened."); \
  } while (0)

#endif

// These functions must be implemented for each type of filter wheel, either in C++ or Tcl.

extern const char *filterwheelrawstart(void);
extern const char *filterwheelrawopen(char *);
extern const char *filterwheelrawclose(void);

extern const char *filterwheelrawreset(void);

extern const char *filterwheelrawupdatestatus(void);
extern const char *filterwheelrawgetvalue(const char *);

extern const char *filterwheelrawmove(long);
extern const char *filterwheelrawhome(void);

// These C++ functions are shared by all filterwheels.

extern const char *filterwheelrawsetisopen(bool);
extern bool        filterwheelrawgetisopen(void);

