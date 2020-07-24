#!/bin/sh

usage () {
  echo 1>&2 "usage: manualalert enable <target> <alpha> <delta>"
  echo 1>&2 "usage: manualalert disable <target>"
  echo 1>&2 "usage: manualalert list"
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
  request selector respondtoalert 2019A-1002 0 $visit $(id -nu) manual $timestamp $timestamp $timestamp true $alpha $delta 2000 1as
}

disable () {
  shift
  if test $# != 1
  then
    usage
  fi
  visit=$1
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%S")"
  request selector respondtoalert 2019A-1002 0 $visit $(id -nu) manual $timestamp $timestamp $timestamp false 0 0 0 0
}

list () {
  shift
  if test $# != 0
  then
    usage
  fi
  rsync rsync://control/tcs/alert/
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
