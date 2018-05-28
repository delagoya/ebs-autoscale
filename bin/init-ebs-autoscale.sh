#!/bin/sh

function printUsage() {
  #statements
  echo "USAGE: $0 <MOUNT POINT> [<DEVICE>]"
}

if [ "$#" -lt "1" ]; then
  printUsage
  exit 1
fi


MP=$1
DV=$2

AZ=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone/)
RG=$(echo ${AZ} | sed -e 's/[a-z]$//')
IN=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id)
BASEDIR=$(dirname $0)

# If a device is not given, create one 20GB volume
if [ -z "${DV}" ]; then
  DV=$(python ${BASEDIR}/create-ebs-volume.py --size 20)
fi

mkfs.btrfs -f -d single $DV
mount $DV $MP

echo -e "${DV}\t${MP}\tbtrfs\tdefaults\t0\t0" |  tee -a /etc/fstab

# copy out the upstart template
cd ${BASEDIR}/../templates
sed -e "s#YOUR_DEVICE#${DV}#" ebs-autoscale.conf.template > /etc/init/ebs-autoscale.conf

# copy logrotate conf
cp ebs-autoscale.logrotate /etc/logrotate.d/ebs-autoscale


# Register the ebs-autoscale upstart conf and start the service
initctl reload-configuration
initctl start ebs-autoscale
