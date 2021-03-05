#!/bin/sh

selectrotation=$1
shift

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
  ha = degtorad(ha);
  delta = degtorad(delta);
  latitude = degtorad(31);
  z = acos(sin(latitude) * sin(delta) + cos(latitude) * cos(delta) * cos(ha));
  return radtodeg(z);
}
{
  if (NF == 1 || $1 == ";;") {
    print $0;
    next;
  }
  
  ha = $9;
  delta = $10;
  rotation = $11;
  
  if (delta < 70 && zenithdistance(ha, delta) <= 65 && rotation == selectrotation) {
    printf("%s\n", $0);
  } else {
    printf(";; %s\n", $0);
  } 
}' "$@"
