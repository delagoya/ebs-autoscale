if [ "$#" -ne "4" ]; then
  echo "USAGE: $0 <DEVICE> <VOLUME GROUP NAME> <LOGICAL VOLUME NAME> <MOUNT POINT>"
  exit 1
fi

DV=$1
VG=$2
LV=$3
MP=$4
AZ=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone/)
RG=$(echo $Z | sed -e 's/[a-z]$//')
IN=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id)

# if docker-ebs-autoscale exe exists, skip bootstrap
if [ -e /usr/local/bin/docker-ebs-autoscale ]; then
  exit 0
fi

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
mkdir ${MP}
mount /dev/${VG}/${LV} ${MP}
echo -e "/dev/${VG}/${LV}\t${MP}\text4\tdefaults\t0\t0" |  tee -a /etc/fstab

# Register the ebs-autoscale upstart conf and start the service
initctl reload-configuration
initctl restart ebs-autoscale
