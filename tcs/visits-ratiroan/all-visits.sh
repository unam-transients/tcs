if test $# != 3
then
  echo 1>&2 "usage: all-visits.sh date prefix priority"
  exit 1
fi

date=$1
prefix=$2
priority=$3

dir=/usr/local/var/tcs/$date/visits
mkdir -p $dir

for file in $prefix-*
do
  echo $priority-$file
  cp $file $dir/$priority-$file
done
