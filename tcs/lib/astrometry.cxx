////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2009, 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include "astrometry.h"

#include <string.h>

extern "C" {
  double sla_gmst_(double *);
  double sla_dtt_(double *);
  double sla_eqeqx_(double *);
  void sla_map_(double *, double *, double *, double *, double *, double *, double *, double *, double *, double *);
  void sla_aop_(double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *, double *);
  void sla_preces_(char *, double *, double *, double *, double *, unsigned long);
  void sla_rdplan_(double *, long *, double *, double *, double *, double *, double *);
}

////////////////////////////////////////////////////////////////////////

double
rawgast(double utcmjd)
{
  double ttmjd = utcmjd + sla_dtt_(&utcmjd) / (24.0 * 60.0 * 60.0);
  return sla_gmst_(&utcmjd) + sla_eqeqx_(&ttmjd);
}

////////////////////////////////////////////////////////////////////////

static void
toobserved(
  double rm, double dm, double eq,
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl,
  double *dob, double *rob
)
{
  double pr = 0;
  double pd = 0;
  double px = 0;
  double rv = 0;
  double ttmjd = utcmjd + sla_dtt_(&utcmjd) / (24.0 * 60.0 * 60.0);
  double ra;
  double da;
  sla_map_(&rm, &dm, &pr, &pd, &px, &rv, &eq, &ttmjd, &ra, &da);
  double dut = 0;
  double xp = 0;
  double yp = 0;
  double tlr = 0.0065;
  double aob;
  double zob;
  double hob;
  sla_aop_(&ra, &da, &utcmjd, &dut,
    &elong, &phim, &hm,
    &xp, &yp,
    &tdk, &pmb, &rh, &wl, &tlr,
    &aob, &zob, &hob, dob, rob);
}

double
rawobservedalpha(
  double rm, double dm, double eq, 
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl
)
{
  double dob;
  double rob;
  toobserved(rm, dm, eq, utcmjd, elong, phim, hm, tdk, pmb, rh, wl, &dob, &rob);
  return rob;
}


double
rawobserveddelta(
  double rm, double dm, double eq, 
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl
)
{
  double dob;
  double rob;
  toobserved(rm, dm, eq, utcmjd, elong, phim, hm, tdk, pmb, rh, wl, &dob, &rob);
  return dob;
}

////////////////////////////////////////////////////////////////////////

static void
toprecessed(
  double *alpha, double *delta,
  double startequinox, double endequinox
)
{
  char system[] = "FK5";
  sla_preces_(system, &startequinox, &endequinox, alpha, delta, strlen(system));  
}

double
rawprecessedalpha(
  double alpha, double delta,
  double startequinox, double endequinox
)
{
  toprecessed(&alpha, &delta, startequinox, endequinox);
  return alpha;
}

double
rawprecesseddelta(
  double alpha, double delta,
  double startequinox, double endequinox
)
{
  toprecessed(&alpha, &delta, startequinox, endequinox);
  return delta;
}

////////////////////////////////////////////////////////////////////////

static void
bodyapparent(
  long body,
  double utcmjd,
  double elong, double phim,
  double *ra, double *da
)
{
  double ttmjd = utcmjd + sla_dtt_(&utcmjd) / (24.0 * 60.0 * 60.0);
  double diameter;
  sla_rdplan_(&ttmjd, &body, &elong, &phim, ra, da, &diameter);
}

double
rawbodyapparentalpha(
  long body,
  double utcmjd,
  double elong, double phim
)
{
  double ra;
  double da;
  bodyapparent(body, utcmjd, elong, phim, &ra, &da);
  return ra;
}

double
rawbodyapparentdelta(
  long body,
  double utcmjd,
  double elong, double phim
)
{
  double ra;
  double da;
  bodyapparent(body, utcmjd, elong, phim, &ra, &da);
  return da;
}

////////////////////////////////////////////////////////////////////////

static void
bodyobserved(
  long body,
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl,
  double *dob, double *rob
)
{
  double ttmjd = utcmjd + sla_dtt_(&utcmjd) / (24.0 * 60.0 * 60.0);
  double ra;
  double da;
  double diameter;
  sla_rdplan_(&ttmjd, &body, &elong, &phim, &ra, &da, &diameter);
  // The conversion from apparent to observed coordinates is not
  // strictly accurate, as it assumes the target is far from the Earth.
  double dut = 0;
  double xp = 0;
  double yp = 0;
  double tlr = 0.0065;
  double aob;
  double zob;
  double hob;
  sla_aop_(&ra, &da, &utcmjd, &dut,
    &elong, &phim, &hm,
    &xp, &yp,
    &tdk, &pmb, &rh, &wl, &tlr,
    &aob, &zob, &hob, dob, rob);
}

double
rawbodyobservedalpha(
  long body,
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl
)
{
  double rob;
  double dob;
  bodyobserved(body, utcmjd, elong, phim, hm, tdk, pmb, rh, wl, &dob, &rob);
  return rob;
}

double
rawbodyobserveddelta(
  long body,
  double utcmjd,
  double elong, double phim, double hm,
  double tdk, double pmb, double rh, double wl
)
{
  double rob;
  double dob;
  bodyobserved(body, utcmjd, elong, phim, hm, tdk, pmb, rh, wl, &dob, &rob);
  return dob;
}

////////////////////////////////////////////////////////////////////////
