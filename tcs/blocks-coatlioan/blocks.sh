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
  
    # allblocks 2019A-1002 c

    # allblocks 2017A-0008-pointing-map           a

    # singleblock 2019A-2001-0 a0

    # allblocks 2019A-2000-0 b0
    # singleblock 2019A-2000-1 b1
    # singleblock 2019A-2000-2 b1
    # singleblock 2019A-2000-3 b1
   

    # allblocks 2017A-0010 e
  
    allblocks 0008-pointing-map           w

  fi

  #for letter in a b c d e f g h i j k l m n o p q r s t u v w x y z
  #do 
  #  singleblock 2019B-1002-0 e$letter
  #done
  
  singleblock 2019B-1100-0 f0
  singleblock 2019B-1100-0 f1
  singleblock 2019B-1100-0 f2
  singleblock 2019B-1100-0 f3
  singleblock 2019B-1100-0 f4
  singleblock 2019B-1100-0 f5
  singleblock 2019B-1100-0 f6
  singleblock 2019B-1100-0 f7
  singleblock 2019B-1100-0 f8
  singleblock 2019B-1100-0 f9

  allblocks 0011-sky-brightness         l
  allblocks 0004-initial-focus          n0
  allblocks 0004-focus-swift            n1
  allblocks 0004-focus-not-swift        n2

  allblocks 0001-twilight-flats-evening s

  allblocks 0002-biases-east            t
  allblocks 0002-biases-west            t

  allblocks 0003-darks-east              u
  allblocks 0003-darks-west              u


) | sudo sh
