#!/bin/sh

# For a relative pointing map, we essentially replace the requested coordinates
# with the observed coordinates of the reference detector.

paste $1 $2 |
sed '/#/d' |
awk '
{
  printf("%s/%s %s %s %s %s %s %s %s %s %s %s %s\n", \
    $1, $13, $14, $15, $4, $5, $6, $7, $8, $9, $10, $11, $12)
}
'