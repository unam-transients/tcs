#!/bin/sh

export selectorserveraddr=tcs-a

usage () {
  echo 1>&2 "usage: alert enable <target> <alpha> <delta>"
  echo 1>&2 "usage: alert disable <target>"
  exit 1
}

enable () {
  shift
  if test $# != 3
  then
    usage
  fi
  visit=$1
  alpha=$2
  delta=$3
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%S")"
  request selector respondtoalert $(id -nu) $timestamp  $alpha $delta 2000 1as true 2012A-1002 $visit
}

disable () {
  shift
  if test $# != 1
  then
    usage
  fi
  visit=$1
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%S")"
  request selector respondtoalert $(id -nu) $timestamp 0 0 0 0 false 2012A-1002 $visit
}

if test $# = 0
then
  usage
fi
case $1 in
enable)
  enable "$@"
  ;;
disable)
  disable "$@"
  ;;
*)
  usage
  ;;
esac
