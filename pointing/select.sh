#!/bin/sh

selectrotation=$1
shift

grep -v '^#' "$@" |
awk -v selectrotation=$selectrotation '
BEGIN {
  pi = 4 * atan2(1, 1);
}
function degtorad(x) {
  return x * pi / 180;
}
function radtodeg(x) {
  return x * 180 / pi;
}
function asin(x) {
 return atan2(x, sqrt(1-x*x));
}
function acos(x) {
  return atan2(sqrt(1-x*x), x);
}
function atan(x) {
  return atan2(x,1);
}
function zenithdistance(ha, delta) {
  h = degtorad(h);
  delta = degtorad(delta);
  phi = degtorad(31.0455305556);
  z = acos(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h));
  return radtodeg(z);
}
{
  h = $7;
  delta = $8;
  rotation = $9;
  
  if (-90 <= delta && delta <= 90 && z <= 90 && rotation == selectrotation) {
    printf("%s\n", $0);
  } 
}' "$@"
