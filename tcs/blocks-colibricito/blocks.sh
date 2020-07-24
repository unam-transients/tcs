#!/bin/sh

################################################################################

case $1 in
[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
  date="$1"
  ;;
"")
  date=$(date +%Y%m%d -d tomorrow)
  ;;
*)
  date=$(date +%Y%m%d -d "$1")
  ;;
esac
echo $date
dir=/usr/local/var/tcs/$date/blocks

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
#sh sdss-standards.sh
#sh landolt-standard-fields.sh
#sh stripe-82.sh
sh pointing-map.sh
sh sky-brightness.sh

################################################################################

(
  echo mkdir -p $dir

#  allblocks 2019A-0008-pointing-map           a

#  singleblock 2019A-1000-1001 a0
#  singleblock 2019A-1000-1001 a1

#  allblocks 2019A-0010 e
  
#  allblocks 2019A-0011-sky-brightness         l
  allblocks 2019A-0004-initial-focus          n0
  allblocks 2019A-0004-focus-swift            n1
  allblocks 2019A-0004-focus-not-swift        n2

  allblocks 2019A-0001-twilight-flats-evening s
  allblocks 2019A-0002-biases-east            t
  allblocks 2019A-0002-biases-west            t
  allblocks 2019A-0003-dark-east              u
  allblocks 2019A-0003-dark-west              u

  allblocks 2019A-0008-pointing-map           w

) | sudo sh
