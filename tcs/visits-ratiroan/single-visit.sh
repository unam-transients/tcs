if test $# != 3
then
  echo 1>&2 "usage: single-visit.sh date file priority"
  exit 1
fi

date=$1
file=$2
priority=$3

dir=/usr/local/var/tcs/$date/visits
mkdir -p $dir

cp $file $dir/$priority-$file
