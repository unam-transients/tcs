///////////////////////////////////////////////////////////////////////////////

#define FIT_IH    1
#define FIT_ID    1
#define FIT_CH    1
#define FIT_NP    1
#define FIT_MA    1
#define FIT_ME    1
#define FIT_TF    0
#define FIT_FO    0
#define FIT_DAF   1
#define FIT_HHSH  1
#define FIT_HHCH  1
#define FIT_HHSH2 1
#define FIT_HHCH2 1
#define FIT_HDSD  1
#define FIT_HDCD  1
#define FIT_HDSD2 1
#define FIT_HDCD2 1
#define FIT_DICD  1
#define FIT_C0    0
#define FIT_C1    0
#define FIT_C2    0
#define FIT_C3    0

#define PHI 31.0455305556

///////////////////////////////////////////////////////////////////////////////

double fit_min_h = -180.0;
double fit_max_h = +180.0;
double fit_min_delta = -90.0;
double fit_max_delta = +90.0;
double fit_max_z = 90.0;

///////////////////////////////////////////////////////////////////////////////

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>

///////////////////////////////////////////////////////////////////////////////

double phi;

double pi;

double
degtorad(double deg)
{
  return deg * pi / 180;
}

double
radtodeg(double rad)
{
  return rad / pi * 180;
}

double
radtoarcmin(double rad)
{
  return radtodeg(rad) * 60;
}

double
radtoarcsec(double rad)
{
  return radtodeg(rad) * 3600;
}

double
fold(double x)
{
  while (x > pi)
    x -= 2 * pi;
  while (x < -pi)
    x += 2 * pi;
  return x;
}

double
fold_positive(double x)
{
  while (x > 2 * pi)
    x -= 2 * pi;
  while (x < 0)
    x += 2 * pi;
  return x;
}

double
sec(double x)
{
  return 1.0 / cos(x);
}

///////////////////////////////////////////////////////////////////////////////

size_t n_pointings;
#define POINTING_MAX 1024
#define NAME_MAX 1024

char name[POINTING_MAX][NAME_MAX];

// The requested coordinates in the standard equinox.
double requested_alpha[POINTING_MAX];
double requested_delta[POINTING_MAX];

// The actual coordinates in the standard equinox, typically obtained by solving
// the astrometry in an image.
double actual_alpha[POINTING_MAX];
double actual_delta[POINTING_MAX];

// The observed coordinates corresponding to the requested coordinates.
double observed_alpha[POINTING_MAX];
double observed_delta[POINTING_MAX];
double observed_h[POINTING_MAX];

// The mount coordinates corresponding to the observed coordinates.
double mount_alpha[POINTING_MAX];
double mount_delta[POINTING_MAX];
double mount_h[POINTING_MAX];
double mount_rotation[POINTING_MAX];

// The actual pointing errors.
double actual_alpha_error[POINTING_MAX];
double actual_delta_error[POINTING_MAX];
double actual_h_error[POINTING_MAX];
double actual_x_error[POINTING_MAX];
double actual_y_error[POINTING_MAX];

////////////////////////////////////////////////////////////////////////////////

double
mount_z(size_t i)
{
  double h     = mount_h[i];
  double delta = mount_delta[i];
  return acos(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h));
}

double
observed_z(size_t i)
{
  double h     = observed_h[i];
  double delta = observed_delta[i];
  return acos(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h));
}

////////////////////////////////////////////////////////////////////////////////

size_t n_parameters = 
  FIT_IH    +
  FIT_ID    +
  FIT_CH    +
  FIT_NP    +
  FIT_MA    +
  FIT_ME    +
  FIT_TF    +
  FIT_FO    +
  FIT_DAF   +
  FIT_HHSH  +
  FIT_HHCH  +
  FIT_HHSH2 +
  FIT_HHCH2 +
  FIT_HDSD  +
  FIT_HDCD  +
  FIT_HDSD2 +
  FIT_HDCD2 +
  FIT_DICD  +
  FIT_C0    +
  FIT_C1    +
  FIT_C2    +
  FIT_C3    +
  0
;

double IH    = 0.0;
double ID    = 0.0;
double CH    = 0.0;
double NP    = 0.0;
double MA    = 0.0;
double ME    = 0.0;
double TF    = 0.0;
double FO    = 0.0;
double DAF   = 0.0;

double HHSH  = 0.0;
double HHCH  = 0.0;
double HHSH2 = 0.0;
double HHCH2 = 0.0;

double HDSD  = 0.0;
double HDCD  = 0.0;
double HDSD2 = 0.0;
double HDCD2 = 0.0;

double DICD  = 0.0;

double C0    = 0.0;
double C1    = 0.0;
double C2    = 0.0;
double C3    = 0.0;

double
model_h_error(size_t i)
{
  double h     = observed_h[i];
  double delta = observed_delta[i];

  double error = 0;

  error += IH;

  error += CH * sec(delta);
  error += NP * tan(delta);

  error -= MA * cos(h) * tan(delta);
  error += ME * sin(h) * tan(delta);

  error += TF * cos(phi) * sin(h) * sec(delta);
  error -= DAF * (cos(phi) * cos(h) + sin(phi) * tan(delta));

  error += HHSH * sin(h);
  error += HHCH * cos(h);
  error += HHSH2 * sin(2 * h);
  error += HHCH2 * cos(2 * h);

  return error;
}

double
model_delta_error(size_t i)
{
  double h     = observed_h[i];
  double delta = observed_delta[i];

  double error = 0;

  error += ID;

  error += MA * sin(h);
  error += ME * cos(h);

  error += TF * (cos(phi) * cos(h) * sin(delta) - sin(phi) * cos(delta));
  error += FO * cos(h);

  error += HDSD * sin(delta);
  error += HDCD * cos(delta);
  error += HDSD2 * sin(2 * delta);
  error += HDCD2 * cos(2 * delta);

  error += DICD / cos(delta);
  
  return error;
}

double
model_x_error(size_t i)
{
  return model_h_error(i) * cos(actual_delta[i]);
}

double
model_y_error(size_t i)
{
  return model_delta_error(i);
}

double
calc_rms_residual(double *p)
{
  if (p != 0) {
    size_t i = 0;
    if (FIT_IH   ) IH    = p[i++];
    if (FIT_ID   ) ID    = p[i++];
    if (FIT_CH   ) CH    = p[i++];
    if (FIT_NP   ) NP    = p[i++];
    if (FIT_MA   ) MA    = p[i++];
    if (FIT_ME   ) ME    = p[i++];
    if (FIT_TF   ) TF    = p[i++];
    if (FIT_FO   ) FO    = p[i++];
    if (FIT_DAF  ) DAF   = p[i++];
    if (FIT_HHSH ) HHSH  = p[i++];
    if (FIT_HHCH ) HHCH  = p[i++];
    if (FIT_HHSH2) HHSH2 = p[i++];
    if (FIT_HHCH2) HHCH2 = p[i++];
    if (FIT_HDSD ) HDSD  = p[i++];
    if (FIT_HDCD ) HDCD  = p[i++];
    if (FIT_HDSD2) HDSD2 = p[i++];
    if (FIT_HDCD2) HDCD2 = p[i++];
    if (FIT_DICD ) DICD  = p[i++];
    if (FIT_C0   ) C0    = p[i++];
    if (FIT_C1   ) C1    = p[i++];
    if (FIT_C2   ) C2    = p[i++];
    if (FIT_C3   ) C3    = p[i++];
    assert(i == n_parameters);
  }
  
  double sum_squared_residual = 0.0;
  double n = 0.0;
  
  for (size_t i = 0; i < n_pointings; ++i) {
    if (
      observed_delta[i] >= fit_min_delta &&
      observed_delta[i] <= fit_max_delta &&
      observed_h[i] >= fit_min_h &&
      observed_h[i] <= fit_max_h && 
      observed_z(i) <= fit_max_z
    ) {
      double x_residual = actual_x_error[i] - model_x_error(i);
      double y_residual = actual_y_error[i] - model_y_error(i);
      sum_squared_residual += x_residual * x_residual;
      sum_squared_residual += y_residual * y_residual;
      ++n;
    }
  }
  
  assert (n != 0);
  double rms_residual = sqrt(sum_squared_residual / n);
  
  return rms_residual;
}

////////////////////////////////////////////////////////////////////////////////

void
read_pointings(void)
{
  n_pointings = 0;
  while (11 == scanf("%s %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf", 
    name[n_pointings],
    &requested_alpha[n_pointings],
    &requested_delta[n_pointings],
    &observed_alpha[n_pointings],
    &observed_delta[n_pointings],
    &mount_h[n_pointings],
    &mount_alpha[n_pointings],
    &mount_delta[n_pointings],
    &mount_rotation[n_pointings],
    &actual_alpha[n_pointings],
    &actual_delta[n_pointings]))
    ++n_pointings;
    
  for (size_t i = 0; i < n_pointings; ++i) {
    requested_alpha[i] = degtorad(requested_alpha[i]);
    requested_delta[i] = degtorad(requested_delta[i]);
    observed_alpha[i]  = degtorad(observed_alpha[i]);
    observed_delta[i]  = degtorad(observed_delta[i]);
    mount_h[i]         = degtorad(mount_h[i]);
    mount_alpha[i]     = degtorad(mount_alpha[i]);
    mount_delta[i]     = degtorad(mount_delta[i]);
    mount_rotation[i]  = degtorad(mount_rotation[i]);
    actual_alpha[i]    = degtorad(actual_alpha[i]);
    actual_delta[i]    = degtorad(actual_delta[i]);
  }

  for (size_t i = 0; i < n_pointings; ++i) {
    observed_h[i] = fold(mount_h[i] + (observed_alpha[i] - mount_alpha[i]));
  }
  
  for (size_t i = 0; i < n_pointings; ++i) {
    actual_alpha_error[i] = fold(requested_alpha[i] - actual_alpha[i]);
    actual_delta_error[i] = fold(requested_delta[i] - actual_delta[i]);
    actual_h_error[i]     = -actual_alpha_error[i];
    actual_x_error[i]     = actual_h_error[i] * cos(actual_delta[i]);
    actual_y_error[i]     = actual_delta_error[i];
  }
  
  printf("RMS residual = %.2f\n", radtoarcmin(calc_rms_residual(0)));

  for (size_t i = 0; i < n_pointings; ++i) {
    double applied_model_alpha = fold(mount_alpha[i] - observed_alpha[i]);
    double applied_model_delta = fold(mount_delta[i] - observed_delta[i]);
    requested_alpha[i] = fold_positive(requested_alpha[i] + applied_model_alpha);
    requested_delta[i] = fold(requested_delta[i] + applied_model_delta);
  }
  
  for (size_t i = 0; i < n_pointings; ++i) {
    actual_alpha_error[i] = fold(requested_alpha[i] - actual_alpha[i]);
    actual_delta_error[i] = fold(requested_delta[i] - actual_delta[i]);
    actual_h_error[i]     = -actual_alpha_error[i];
    actual_x_error[i]     = actual_h_error[i] * cos(actual_delta[i]);
    actual_y_error[i]     = actual_delta_error[i];
  }
  
  printf("n_pointings = %lu\n", (long unsigned) n_pointings);
  for (size_t i = 0; i < n_pointings; ++i) {
    printf("%s %+7.2f %6.2f %+7.2f %6.2f %+6.2f %+6.2f\n", 
      name[i], 
      radtodeg(mount_h[i]), radtodeg(mount_delta[i]),
      radtodeg(requested_alpha[i]), radtodeg(requested_delta[i]),
      radtoarcmin(actual_x_error[i]), radtoarcmin(actual_y_error[i]));
  }
  printf("RMS residual = %.2f\n", radtoarcmin(calc_rms_residual(0)));
}

void minimize(double (*demerit)(double *));

void
fit_model(void)
{
  printf("Fitting model ... ");
  minimize(calc_rms_residual);
  printf("done.\n");
}

void
show_model(void)
{
  printf("Residuals:\n");
  for (size_t i = 0; i < n_pointings; ++i) {
    printf("%s %+7.2f %6.2f %+7.2f %6.2f %+6.2f %+6.2f %+6.2f %+6.2f\n", 
      name[i], 
      radtodeg(mount_h[i]), radtodeg(mount_delta[i]),
      radtodeg(requested_alpha[i]), radtodeg(requested_delta[i]),
      radtoarcmin(actual_x_error[i]), radtoarcmin(actual_y_error[i]),
      radtoarcmin(actual_x_error[i] - model_x_error(i)), radtoarcmin(actual_y_error[i] - model_y_error(i)));
  }

  printf("Config parameters:\n");
  printf("  %-6s %10.6f\n", "IH"   , IH   );
  printf("  %-6s %10.6f\n", "ID"   , ID   );
  printf("  %-6s %10.6f\n", "CH"   , CH   );
  printf("  %-6s %10.6f\n", "NP"   , NP   );
  printf("  %-6s %10.6f\n", "MA"   , MA   );
  printf("  %-6s %10.6f\n", "ME"   , ME   );
  printf("  %-6s %10.6f\n", "TF"   , TF   );
  printf("  %-6s %10.6f\n", "FO"   , FO   );
  printf("  %-6s %10.6f\n", "DAF"  , DAF  );
  printf("  %-6s %10.6f\n", "HHSH" , HHSH );
  printf("  %-6s %10.6f\n", "HHCH" , HHCH );
  printf("  %-6s %10.6f\n", "HHSH2", HHSH2);
  printf("  %-6s %10.6f\n", "HHCH2", HHCH2);
  printf("  %-6s %10.6f\n", "HDSD" , HDSD );
  printf("  %-6s %10.6f\n", "HDCD" , HDCD );
  printf("  %-6s %10.6f\n", "HDSD2", HDSD2);
  printf("  %-6s %10.6f\n", "HDCD2", HDCD2);
  printf("  %-6s %10.6f\n", "DICD" , DICD );
  printf("  %-6s %10.6f\n", "C0"   , C0   );
  printf("  %-6s %10.6f\n", "C1"   , C1   );
  printf("  %-6s %10.6f\n", "C2"   , C2   );
  printf("  %-6s %10.6f\n", "C3"   , C3   );
  

  printf("Fit:\n");
  if (FIT_IH   ) printf("%-6s = %+6.2f\n", "IH"   , radtoarcmin(IH   ));
  if (FIT_ID   ) printf("%-6s = %+6.2f\n", "ID"   , radtoarcmin(ID   ));
  if (FIT_CH   ) printf("%-6s = %+6.2f\n", "CH"   , radtoarcmin(CH   ));
  if (FIT_NP   ) printf("%-6s = %+6.2f\n", "NP"   , radtoarcmin(NP   ));
  if (FIT_MA   ) printf("%-6s = %+6.2f\n", "MA"   , radtoarcmin(MA   ));
  if (FIT_ME   ) printf("%-6s = %+6.2f\n", "ME"   , radtoarcmin(ME   ));
  if (FIT_TF   ) printf("%-6s = %+6.2f\n", "TF"   , radtoarcmin(TF   ));
  if (FIT_FO   ) printf("%-6s = %+6.2f\n", "FO"   , radtoarcmin(FO   ));
  if (FIT_DAF  ) printf("%-6s = %+6.2f\n", "DAF"  , radtoarcmin(DAF  ));
  if (FIT_HHSH ) printf("%-6s = %+6.2f\n", "HHSH" , radtoarcmin(HHSH ));
  if (FIT_HHCH ) printf("%-6s = %+6.2f\n", "HHCH" , radtoarcmin(HHCH ));
  if (FIT_HHSH2) printf("%-6s = %+6.2f\n", "HHSH2", radtoarcmin(HHSH2));
  if (FIT_HHCH2) printf("%-6s = %+6.2f\n", "HHCH2", radtoarcmin(HHCH2));
  if (FIT_HDSD ) printf("%-6s = %+6.2f\n", "HDSD" , radtoarcmin(HDSD ));
  if (FIT_HDCD ) printf("%-6s = %+6.2f\n", "HDCD" , radtoarcmin(HDCD ));
  if (FIT_HDSD2) printf("%-6s = %+6.2f\n", "HDSD2", radtoarcmin(HDSD2));
  if (FIT_HDCD2) printf("%-6s = %+6.2f\n", "HDCD2", radtoarcmin(HDCD2));
  if (FIT_DICD ) printf("%-6s = %+6.2f\n", "DICD" , radtoarcmin(DICD ));
  if (FIT_C0   ) printf("%-6s = %+6.2f\n", "C0"   , radtoarcmin(C0   ));
  if (FIT_C1   ) printf("%-6s = %+6.2f\n", "C1"   , radtoarcmin(C1   ));
  if (FIT_C2   ) printf("%-6s = %+6.2f\n", "C2"   , radtoarcmin(C2   ));
  if (FIT_C3   ) printf("%-6s = %+6.2f\n", "C3"   , radtoarcmin(C3   ));
  
  printf("RMS residual = %.2f\n", radtoarcmin(calc_rms_residual(0)));

  fit_min_h     = degtorad(-120);
  fit_max_h     = degtorad(+120);
  fit_min_delta = degtorad(-90);
  fit_max_delta = degtorad(+60);
  fit_max_z     = degtorad(90);
  printf("RMS residual = %.2f\n", radtoarcmin(calc_rms_residual(0)));

  FILE *fp = fopen("residuals.dat", "w");
  assert(fp != 0);
  for (size_t i = 0; i < n_pointings; ++i) {
    fprintf(fp, "%+10.5f %10.5f %10.5f %+10.2f %10.2f\n", 
      radtodeg(mount_h[i]), radtodeg(mount_delta[i]), radtodeg(mount_z(i)),
      radtoarcsec(actual_x_error[i] - model_x_error(i)), radtoarcsec(actual_y_error[i] - model_y_error(i)));
  }
  fclose(fp);
}

int
main()
{
  pi = 4 * atan(1);

  phi = degtorad(PHI);

  fit_min_h     = degtorad(fit_min_h);
  fit_max_h     = degtorad(fit_max_h);
  fit_min_delta = degtorad(fit_min_delta);
  fit_max_delta = degtorad(fit_max_delta);
  fit_max_z     = degtorad(fit_max_z);

  read_pointings();
  fit_model();
  show_model();
}

///////////////////////////////////////////////////////////////////////////////

// We now define a wrapper for the Numerical Recipes amoeba function that hides
// all of the 1-based array nonsense.

double (*real_demerit)(double *);

double
raw_demerit(double *q)
{
  // Convert the 1-based array q to a 0-based array p.
  double *p = q + 1;
  return real_demerit(p);
}

void amoeba(double **p, double y[], int ndim, double ftol,
	double (*funk)(double []), int *nfunk);

void
minimize(double (*demerit)(double *))
{
  real_demerit = demerit;
    
  // q and y are 1-based arrays

  double **q;
  q = malloc(sizeof(*q) * (n_parameters + 2));
  assert(q != 0);
  for (size_t i = 1; i < n_parameters + 2; ++i) {
    q[i] = malloc(sizeof(**q) * (n_parameters + 1));
    assert(q[i] != 0);
    for (size_t j = 1; j < n_parameters + 1; ++j) {
      q[i][j] = 0.0;
    }
  }
  
  double *y;
  y = malloc(sizeof(*y) * (n_parameters + 2));
  assert(y != 0);

  for (int k = 0; k < 3; ++k) {

    for (size_t i = 1; i < n_parameters + 1; ++i) {
      q[i][i] += 1e-3;
    }
   
    for (size_t i = 1; i < n_parameters + 2; ++i) {
      y[i] = raw_demerit(q[i]);
    }

    int n = 0;
    amoeba(q, y, n_parameters, 1e-8, raw_demerit, &n);
  
  }
  
  size_t i_min = 1;
  for (size_t i = 2; i < n_parameters + 2; ++i) {
    if (y[i] < y[i_min]) {
      i_min = i;
    }
  }
  raw_demerit(q[i_min]);

}
