#!/bin/sh
O="$(date '+%Y%m%d-%H%M%S')-usage.log"
if [ -z "$1" ]; then
  echo "USAGE: $0 <S3 DEST URI (e.g. \"s3://myfiles/logs/\")> "
  exit 0
fi
S3URI=$(echo $1 | sed -e 's#/$##')

btrfs filesystem usage /scratch > /tmp/$O
aws s3 cp /tmp/$O ${S3URI}/$O
