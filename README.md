# Amazon Elastic Block Store Autoscale

This is a simple daemon process that monitors a filesystem on a LVM group and extends it as it get full, via resizing the underlying Amazon EBS volume.

### Assumptions:

1. Running on an AWS instance and are using EBS for a data storage volume
2. LVM2 was used to create a physical volume, volume group, and logical volume
3. Prerequisites for this daemon and your filesystem are installed


Provided in this repo are

1. A [cloud-init](ebs-autoscale) file for installing the daemon and dependencies
2. A upstart configuration file
3. A logrotate configuration file
4. The daemon script that monitors disk space and expands an EBS volume and associated LVM and FS.

### Install
