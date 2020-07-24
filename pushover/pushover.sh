#!/bin/sh

curl -s \
  --form-string "token=aJf8MbVrwupkvUeFNQimP45WtLz7oh" \
  --form-string "user=uopAQF3pQRWhpJNCQgd2q8tGKDZRjW" \
  --form-string "priority=2" \
  --form-string "retry=60" \
  --form-string "expire=86400" \
  --form-string "message=Test" \
  https://api.pushover.net/1/messages.json