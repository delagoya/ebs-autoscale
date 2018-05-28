#!/bin/sh
DV=$1
mkfs.btrfs -d single $DV
mount $DV /scratch
