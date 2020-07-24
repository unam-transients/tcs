#!/bin/sh

prefix=/mnt/volume/

sudo mkdir -p $prefix/local/cron
sudo mkdir -p $prefix/local/etc
sudo mkdir -p $prefix/local/sbin

sudo cp local/cron/update-archive     $prefix/local/cron
sudo cp local/cron/make-log-csv-file  $prefix/local/cron
sudo cp local/cron/make-log-txt-file  $prefix/local/cron

#sudo cp local/cron/clean-archive      $prefix/local/cron
#sudo cp local/etc/*                   $prefix/local/etc
sudo cp local/rsync-transientsoan/*    $prefix/local/etc
sudo cp local/sbin/*                  $prefix/local/sbin

sudo $prefix/local/sbin/localize
