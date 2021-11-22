#!/bin/sh

################################################################################

case $1 in
default|[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
  date="$1"
  ;;
"")
  date=$(date +%Y%m%d -d tomorrow)
  ;;
*)
  date=$(date +%Y%m%d -d "$1")
  ;;
esac
echo "$date"
if test "$date" = "default"
then
  dir=/usr/local/etc/tcs/blocks
else
  dir=/usr/local/var/tcs/$date/blocks
fi

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
sh sdss-standards.sh
sh landolt-standard-fields.sh
sh stripe-82.sh
sh pointing-map.sh
sh sky-brightness.sh
sh 2017A-0010.sh

# sh go-fox.sh
# sh go-michel.sh
# sh 2018A-2000.sh

rm 2017A-0010-100
rm 2017A-0010-101
rm 2017A-0010-102
rm 2017A-0010-103
rm 2017A-0010-110
rm 2017A-0010-128
rm 2017A-0010-132

################################################################################

rm -f 2019A-2000-0-*
sh 2019A-2000-0.sh

# sh lvc-S190426c.sh

(
  echo mkdir -p $dir
  
  if test "$date" = "default"  
  then
    echo rm -rf $dir
  fi

  echo mkdir -p $dir

  if test "$date" != "default"  
  then
    
    :
    
  
    allblocks 0012-focus-offsets         v
    #allblocks 0008-pointing-map         w
    #allblocks 0007-donut                o

  fi

  singleblock 2021B-2001-costero-0      f

  singleblock 2021B-2000-fast-guiding-0 g

  allblocks 0004-initial-focus          m
  allblocks 0004-focus                  n
  
  allblocks 0001-twilight-flats-evening x
  allblocks 0002-biases                 y
  allblocks 0003-darks                  z


) | sudo sh
