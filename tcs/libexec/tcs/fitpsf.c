////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2010, 2011, 2017, 2019 Alan M. Watson <alan@astro.unam.mx>
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

#include <math.h>
#include <string.h>

#include <fftw3.h>
#include <fitsio.h>

static int minimize(int m, double [m], double [m], double (*f)(int, double []), double, int);

typedef struct {
  double fwhm;
  double e;
  double theta;
} fit_t;

static long nfit = 16;

static long rnx = 0;
static long rny = 0;
static double *rz = NULL;
#define RZ(iy,ix) (rz[(iy) * rnx + (ix)])   

static long cnx = 0;
static long cny = 0;
static fftw_complex *cz = NULL;
#define CZ(iy,ix) (cz[(iy) * cnx + (ix)])

static fftw_plan r2cp = NULL;
static fftw_plan c2rp = NULL;

int 
imin(int i, int j)
{
  if (i < j)
    return i;
  else
    return j;
}

int 
imax(int i, int j)
{
  if (i > j)
    return i;
  else
    return j;
}

double
model_z(int m, double p[m], double y, double x)
{
  double pi = 4.0 * atan(1.0);
  
  double a = fabs(p[0]);
  double b = fabs(p[1]);
  double sx = fabs(p[2]);
  double sy = fabs(p[3]);
  double theta = p[4];
  
  double dx = + cos(theta) * x + sin(theta) * y;
  double dy = - sin(theta) * x + cos(theta) * y;
  
  double vxx = (dx * dx) / (sx * sx);
  double vyy = (dy * dy) / (sy * sy);
  
  return a + b * exp(- (vxx + vyy) / 2.0) / (2.0 * pi * sx * sy);
}

double
calc_rms(int m, double p[m])
{
  double d = 0;
  double w = 0;
  for (long iy = -nfit; iy <= nfit; ++iy) {
    for (long ix = -nfit; ix <= nfit; ++ix) {
      if ((ix != 0 && iy != 0) && sqrt(ix * ix + iy * iy) <= nfit) {
        double z = RZ((iy + rny) % rny, (ix + rnx) % rnx);
        double dz = z - model_z(m, p, iy, ix);
        d += (dz * dz) / (ix * ix + iy * iy);
        w += 1.0 / (ix * ix + iy * iy);
      }
    }
  }
  double rms = sqrt(d / w);
  return rms;
}

double
calc_mean(int n)
{
  double mean = 0;
  for (long iy = -n; iy <= n; ++iy) {
    for (long ix = -n; ix <= n; ++ix) {
      double z = RZ((iy + rny) % rny, (ix + rnx) % rnx);
      if (ix != 0 || iy != 0)
        mean += z;
    }
  }
  mean /= (2 * n + 1) * (2 * n + 1) - 1;
  return mean;
}

fit_t
fitpsf(long ny, long nx, double z[ny][nx], long wsx, long wnx, long wsy, long wny)
{
  double pi = 4.0 * atan(1.0);

  free(rz);
  rnx = wnx;
  rny = wny;
  rz = fftw_malloc(rnx * rny * sizeof(*rz));
  if (rz == NULL)
    abort();
  
  free(cz);
  cnx = (rnx / 2) + 1;
  cny = rny;
  cz = fftw_malloc(cnx * cny * sizeof(*cz));
  if (cz == NULL)
    abort();
  
  fftw_set_timelimit(1.0);
  fftw_destroy_plan(r2cp);
  r2cp = fftw_plan_dft_r2c_2d(rny, rnx, rz, cz, FFTW_PATIENT);
  fftw_destroy_plan(c2rp);
  c2rp = fftw_plan_dft_c2r_2d(rny, rnx, cz, rz, FFTW_PATIENT);
  
  for (long iy = 0; iy < wny; ++iy)
    for (long ix = 0; ix < wnx; ++ix)
      RZ(iy,ix) = z[wsy + iy][wsx + ix];

  fftw_execute(r2cp);  
  for (long iy = 0; iy < cny; ++iy)
    for (long ix = 0; ix < cnx; ++ix) {
      CZ(iy,ix)[0] = (CZ(iy,ix)[0] * CZ(iy,ix)[0] + CZ(iy,ix)[1] * CZ(iy,ix)[1]);
      CZ(iy,ix)[1] = 0;
    }
  fftw_execute(c2rp);

  for (long iy = 0; iy < rny; ++iy)
    for (long ix = 0; ix < rnx; ++ix)
      RZ(iy,ix) /= (rnx * rny) * (rnx * rny);
      
  double mean = calc_mean(nfit);
  double dmean = calc_mean(5) - mean;
  int m = 5;
  double p[] = { mean, dmean, 2, 2, 0};
  {
    double dp[] = { 0.01 * mean, 0.1 * dmean, 1, 1, 0};
    minimize(m, p, dp, calc_rms, 1e-4, 1e5);
  }
  {
    double dp[] = { 0.01 * mean, 0.1 * dmean, 1, 1, 1};
    minimize(m, p, dp, calc_rms, 1e-4, 1e5);
  }
  {
    double dp[] = { 0.01 * mean, 0.1 * dmean, 1, 1, 1};
    minimize(m, p, dp, calc_rms, 1e-8, 1e5);
  }
  
  fprintf(stderr, "%.2e ", sqrt(p[0]));
  fprintf(stderr, "%.2e ", sqrt(fabs(p[1])));
  fprintf(stderr, "%.2e ", fabs(p[2]));
  fprintf(stderr, "%.2e ", fabs(p[3]));
  fprintf(stderr, "%+.2e | ", p[4]);
  
  fprintf(stderr, "%.2e ", calc_rms(m, p));
  
  double sx = fabs(p[2]);
  double sy = fabs(p[3]);
  double fwhm = 2.0 * sqrt(log(2.0)) * sqrt((sx * sx + sy * sy) / 2.0);
  double e;
  double theta = p[4];
  if (sx > sy) {
    e = sy / sx;
  } else {
    e = sx / sy;
    theta += pi / 2.0;
  }
  while (theta > + pi / 2)
    theta -= pi;
  while (theta < - pi / 2)
    theta += pi;
  fprintf(stderr, "%5.2f %.2f %+6.1f", fwhm, e, theta * 180.0 / pi);
  
  fprintf(stderr, "\n");
    
  return (fit_t) { .fwhm = fwhm, .e = e, .theta = theta };
}

static void
import_wisdom(const char *wisdom_file)
{
  FILE *fp = fopen(wisdom_file, "r");
  if (fp != NULL) {
    fftw_import_wisdom_from_file(fp);
    fclose(fp);
  }
}

static void
export_wisdom(const char *wisdom_file)
{
  FILE *fp = fopen(wisdom_file, "w");
  if (fp != NULL) {
    fftw_export_wisdom_to_file(fp);
    fclose(fp);
  }
}

int
fit_cmp(const void *vx, const void *vy)
{
  fit_t x = * (fit_t *) vx;
  fit_t y = * (fit_t *) vy;
  if (x.fwhm < y.fwhm)
    return -1;
  else if (x.fwhm > y.fwhm)
    return +1;
  else
    return 0;
}

int
double_cmp(const void *vx, const void *vy)
{
  double x = * (double *) vx;
  double y = * (double *) vy;
  if (x < y)
    return -1;
  else if (x > y)
    return +1;
  else
    return 0;
}

void
destripey(long ny, long nx, double z[ny][nx])
{
  for (int ix = 0; ix < nx; ++ix) {
    double columnz[ny];
    for (int iy = 0; iy < ny; ++iy) {
      columnz[iy] = z[iy][ix];
    }
    qsort(columnz, ny, sizeof(*columnz), double_cmp);
    double medianz = columnz[ny / 2];
    for (int iy = 0; iy < ny; ++iy) {
      z[iy][ix] -= medianz;
    }
  }
}

void
desaturate(long ny, long nx, double zold[ny][nx], double znew[ny][nx], double saturationlevel, int w)
{

  for (int iy = 0; iy < ny; ++iy)
    for (int ix = 0; ix < nx; ++ix)
      znew[iy][ix] = zold[iy][ix];
      
  if (saturationlevel == 0)
    return;
      
  for (int iy = 0; iy < ny; ++iy)
    for (int ix = 0; ix < nx; ++ix)
      if (zold[iy][ix] >= saturationlevel) {
        for (int jy = imax(0, iy - w); jy < imin(ny, iy + w + 1); ++jy)
          for (int jx = imax(0, ix - w); jx < imin(nx, ix + w + 1); ++jx)
            znew[jy][jx] = 0;
      }

}

int
main(int argc, char *argv[])
{
  double pi = 4.0 * atan(1.0);

  if (argc != 11) {
    fprintf(stderr, "usage: %s fits_name wsx wnx wsy wny wm wn saturationlevel wsaturation wisdom_file.\n", argv[0]);
    exit(1);
  }

  const char *fits_file = argv[1];
  long wsx = atol(argv[2]);
  long wnx = atol(argv[3]);
  long wsy = atol(argv[4]);
  long wny = atol(argv[5]);
  long wm = atol(argv[6]);
  long wn = atol(argv[7]);
  double saturationlevel = atof(argv[8]);
  long wsaturation = atol(argv[9]);
  const char *wisdom_file = argv[10];

  import_wisdom(wisdom_file);

  fitsfile *ffp;         
  int status = 0;

  fits_open_file(&ffp, fits_file, READONLY, &status);
      
  int rank;
  fits_get_img_dim(ffp, &rank,  &status);
  long dimension[2];
  fits_get_img_size(ffp, sizeof(dimension) / sizeof(*dimension), dimension, &status);
  long nx = dimension[0];
  long ny = dimension[1];
  double *z = malloc(nx * ny * sizeof(*z));
  if (z == NULL)
    abort();
  fits_read_pix(ffp, TDOUBLE, (long []) {1, 1}, nx * ny, NULL, z, NULL, &status);
  fits_close_file(ffp, &status);
  if (status) {
    fits_report_error(stderr, status);
    exit(1);
  }
  
  destripey(ny, nx, (void *) z);

  double *zold = z;
  z = malloc(nx * ny * sizeof(*z));
  if (z == NULL)
    abort();
  desaturate(ny, nx, (void *) zold, (void *) z, saturationlevel, wsaturation);

  fit_t fit[wn];
  for (int i = 0; i < wn; ++i) {
    fit[i] = fitpsf(ny, nx, (void *) z, wsx + i * wm, wnx - 2 * i * wm, wsy + i * wm, wny - 2 * i * wm);
  }
  qsort(fit, wn, sizeof(*fit), fit_cmp);
  printf("%.2f %.2f %.1f\n", fit[(wn - 1) / 2].fwhm, fit[(wn - 1) / 2].e, fit[(wn - 1) / 2].theta * 180.0 / pi);

  export_wisdom(wisdom_file);
  
  return status != 0;
}

////////////////////////////////////////////////////////////////////////////////

#include <math.h>
#include <assert.h>

static void
maybe_move_highest(int m, int n, double q[n][m], double y[m],
                   double (*f)(int m, double []), int i_highest, double x,
                   int *nf)
{
  // Calculate the point in the middle of the face opposite the highest
  // point.
  double q_mid[m];
  for (int j = 0; j < m; ++j) {
    q_mid[j] = 0.0;
    for (int i = 0; i < n; ++i)
      if (i != i_highest)
        q_mid[j] += q[i][j];
    q_mid[j] /= n - 1;
  }

  // Reflect the highest point by a factor of x through the opposite
  // face.
  double q_new[m];
  for (int j = 0; j < m; ++j)
    q_new[j] = q_mid[j] + (q[i_highest][j] - q_mid[j]) * x;

  // Accept this point if it is lower.
  double y_new = f(m, q_new);
  ++*nf;
  if (y_new < y[i_highest]) {
    y[i_highest] = y_new;
    for (int j = 0; j < m; ++j) {
      q[i_highest][j] = q_new[j];
    }
  }
}

static void
move_all_but_lowest(int m, int n, double q[n][m], double y[m],
                    double (*f)(int m, double []), int i_lowest,
                    int *nf)
{
  for (int i = 0; i < n; i++) {
    if (i != i_lowest) {
      for (int j = 0; j < m; j++)
        q[i][j] = 0.5 * (q[i][j] + q[i_lowest][j]);
      y[i] = f(m, q[i]);
      ++*nf;
    }
  }
}

static int 
minimize(int m, double p[m], double dp[m], 
         double (*f)(int, double []), 
         double ftol, 
         int nf_max)
{
  int nf = 0;
  const int n = m + 1;

  double y[n];

  double q[n][m];
  for (int i = 0; i < n; ++i) {
    for (int j = 0; j < m; ++j)
      q[i][j] = p[j];
    if (i < m)
      q[i][i] += dp[i];
  }

  for (int i = 0; i < n; ++i)
    y[i] = f(m, q[i]);

  for (;;) {

    int i_lowest = 0;
    for (int i = 0; i < n; ++i)
      if (y[i] <= y[i_lowest])
        i_lowest = i;

    int i_highest = 0;
    for (int i = 0; i < n; ++i)
      if (y[i] >= y[i_highest])
        i_highest = i;
    
    int i_next_highest = i_lowest;
    for (int i = 0; i < n; ++i)
      if (y[i] >= y[i_next_highest] && i != i_highest)
        i_next_highest = i;
    
    assert(i_lowest != i_highest);
    assert(m <= 2 || (i_next_highest != i_highest));
    assert(m <= 2 || (i_next_highest != i_lowest));
    for (int i = 0; i < n; ++i) {
      assert(y[i] >= y[i_lowest]);
      assert(y[i] <= y[i_highest]);
      assert(y[i] <= y[i_next_highest] || i == i_highest);
    }

    double rtol=2.0*fabs(y[i_highest]-y[i_lowest])/(fabs(y[i_highest])+fabs(y[i_lowest]));

    if (rtol < ftol) {
      for (int j = 0; j < m; j++) 
        p[j] = q[i_lowest][j];
      return 1;
    }

    if (nf >= nf_max) {
      for (int j = 0; j < m; j++) 
         p[j] = q[i_lowest][j];
      return 0;
    }

    maybe_move_highest(m, n, q, y, f, i_highest, -1.0, &nf);

    if (y[i_highest] <= y[i_lowest]) {
      maybe_move_highest(m, n, q, y, f, i_highest, 2.0, &nf);
      continue;
    } 

    if (y[i_highest] < y[i_next_highest])
      continue;

    double y_highest = y[i_highest];
    maybe_move_highest(m, n, q, y, f, i_highest, 0.5, &nf);
    if (y[i_highest] < y_highest)
      continue;

    move_all_but_lowest(m, n, q, y, f, i_lowest, &nf);
  }
}

////////////////////////////////////////////////////////////////////////////////
