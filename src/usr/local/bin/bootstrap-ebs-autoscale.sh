# if ebs-autoscale exe exists, skip bootstrap
if [ -e /usr/local/bin/ebs-autoscale ]; then
  exit 0
fi

function printUsage() {
  #statements
  echo "USAGE: $0 <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
}

if [ "$#" -ne "3" ]; then
  printUsage
  exit 1
fi

# If the ebs-autoscale conf file exists, then we should exit
if [ -b "$2" ]; then
  echo "LOGICAL VOLUME exists $2."
  printUsage
  exit 1
fi

VG=$1
LV=$2
MP=$3
AZ=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone/)
RG=$(echo ${AZ} | sed -e 's/[a-z]$//')
IN=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id)

# Get the next device ID
A=({a..z})
N=$(ls /dev/xvd* | grep -v -E '[0-9]$' | wc -l)
DV="/dev/xvd${A[$N]}"


# Create and attache the EBS Volume, also set it to delete on instance terminate
V=$(aws ec2 create-volume --region ${RG} --availability-zone ${AZ} --volume-type gp2 --size 10 --encrypted --query "VolumeId" | sed 's/\"//g' )

# await volume to become available
until [ "$(aws ec2 describe-volumes --volume-ids $V --region ${RG} --query "Volumes[0].State" | sed -e 's/\"//g')" == "available" ]; do
  echo "Volume $V not yet available"
  sleep 1
done

aws ec2 attach-volume --region ${RG} --device ${DV} --volume-id $V --instance-id ${IN}
# change the DeleteOnTermination volume attribute to true
aws ec2 modify-instance-attribute --region ${RG} --block-device-mappings "DeviceName=${DV},Ebs={DeleteOnTermination=true,VolumeId=$V}" --instance-id ${IN}

# wait until device is available to start adding to PV
until [ -b "${DV}" ]; do
  echo "Volume ${DV} not yet available"
  sleep 1
done

# Register the physical volume
pvcreate ${DV}
# create the new volume group
vgcreate ${VG} ${DV}
# get free extents in volume group
E=$(vgdisplay ${VG} |grep "Free" | awk '{print $5}')

# create the logical volume
lvcreate -l $E  -n ${LV} ${VG}

#make the filesystem and mount it
mkfs.ext4 /dev/${VG}/${LV}
if ! [ -d "${MP}" ]; then
  mkdir -p ${MP}
fi
mount /dev/${VG}/${LV} ${MP}
echo -e "/dev/${VG}/${LV}\t${MP}\text4\tdefaults\t0\t0" |  tee -a /etc/fstab

# copy out the upstart template
# cd /opt/ebs-autoscale/etc/init
cd $(dirname $0)/../../../
cp etc/init/ebs-autoscale.conf.template ebs-autoscale.conf
sed -i -e "s#YOUR_DV#${DV}#" ebs-autoscale.conf
sed -i -e "s#YOUR_VG#${VG}#" ebs-autoscale.conf
sed -i -e "s#YOUR_LV#${LV}#" ebs-autoscale.conf
sed -i -e "s#YOUR_MP#${MP}#" ebs-autoscale.conf
cp ebs-autoscale.conf  /etc/init/ebs-autoscale.conf
# copy logrotate conf
cp etc/logrotate.d/ebs-autoscale /etc/logrotate.d/ebs-autoscale

# copy exe
cp usr/local/bin/ebs-autoscale /usr/local/bin/ebs-autoscale

# Register the ebs-autoscale upstart conf and start the service
initctl reload-configuration
initctl start ebs-autoscale
