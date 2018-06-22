# Amazon Elastic Block Store Autoscale

This is an example of how to create a small daemon process that monitors a filesystem and automatically expands it when free space falls below a configured threshold. New [Amazon EBS](https://aws.amazon.com/ebs/) volumes are added to the instance as necessary and the underlying [BTRFS filesystem](http://btrfs.wiki.kernel.org) expands while still mounted. As new devices are added, the BTRFS metadata blocks are rebalanced to mitigate the risk that space for metadata will not run out.

## Assumptions:

1. That this code is running on a AWS EC2 instance
2. The instance has a IAM Instance Profile with appropriate permissions to create and attache new EBS volumes. Ssee the [IAM Instance Profile](#iam_instance_profile) section below for more details
3. That prerequisites are installed on the instance.

Provided in this repo are:

1. A [cloud-init](ebs-autoscale) file for installing the daemon and dependencies
2. A example upstart configuration file
3. A example logrotate configuration file
4. The daemon script that monitors disk space and expands an EBS volume and associated LVM and FS.
5. Some other utility scripts

## Installation

The easiest way to set up an instance is to provide a launch call with the 
