#!/bin/sh

awk '
{
  if (NF == 1 || $1 == ";;" || $11 == 180) {
    printf("%s\n", $0);
  } else {
    printf(";; %s\n", $0);
  } 
}' "$@"
