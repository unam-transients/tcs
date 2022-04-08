#!/bin/sh

################################################################################

dir=/usr/local/var/tcs/blocks
mkdir -p $dir

################################################################################

allblocks () {
  if test $# != 2
  then
    echo 1>&2 "usage: allblocks prefix priority"
    exit 1
  fi
  prefix=$1
  priority=$2
  for file in $prefix-*
  do
    echo cp $file $dir/$priority-$file
  done
}

singleblock () {
  if test $# != 2
  then
    echo 1>&2 "usage: singleblock file priority"
    exit 1
  fi
  file=$1
  priority=$2
  echo cp $file $dir/$priority-$file
}

################################################################################

sh focus.sh
sh pointing-map.sh
sh focus-map.sh

sh roman.sh

################################################################################

(
  #singleblock 2019A-2002-virgo d0
  #singleblock 2019A-2002-virgo d1
  #singleblock 2019A-2002-virgo d2

  #allblocks 0013-focus-tilt o
  #allblocks 0010-focus-map o

  #allblocks 0014-apertures              e

 allblocks 2001-roman                  f
#   allblocks 2002-gomez-maqueo           g
#   singleblock 2003-parrott-0            h0
#   singleblock 2003-parrott-0            h1

#  singleblock 0100-150+45              k0
#  singleblock 0100-150+45              k1
#  singleblock 0100-150+45              k2
#  singleblock 0100-150+45              k3

#  allblocks 0008-pointing-map           k
  #allblocks 0010-focus-map              l

  allblocks 0004-initial-focus          m
  allblocks 0004-focus                  n

  allblocks 0001-twilight-flats-evening x
  allblocks 0002-biases                 y
  allblocks 0003-dark                   z

  allblocks 0013-signal-chain           z


) | sudo sh
