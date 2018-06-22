# Amazon Elastic Block Store Autoscale

This is an example of how to create a small daemon process that monitors a filesystem and automatically expands it when free space falls below a configured threshold. New [Amazon EBS](https://aws.amazon.com/ebs/) volumes are added to the instance as necessary and the underlying [BTRFS filesystem](http://btrfs.wiki.kernel.org) expands while still mounted. As new devices are added, the BTRFS metadata blocks are rebalanced to mitigate the risk that space for metadata will not run out.

## Assumptions:

1. That this code is running on a AWS EC2 instance
2. The instance has a IAM Instance Profile with appropriate permissions to create and attache new EBS volumes. Ssee the [IAM Instance Profile](#iam_instance_profile) section below for more details
3. That prerequisites are installed on the instance.

Provided in this repo are:

1. A [cloud-init](templates/cloud-init-userdata.yaml) file for installing the daemon and dependencies
2. A example [upstart configuration file](templates/ebs-autoscale.conf.template)
3. A example [logrotate configuration file](templates/ebs-autoscale.logrotate)
4. The daemon [script](bin/ebs-autoscale) that monitors disk space and expands an EBS volume and associated LVM and FS.
5. Some other utility scripts in [`bin`](bin/)

## Installation

The easiest way to set up an instance is to provide a launch call with the userdata cloud-init script. Here is an example of launching the [Amazon ECS-Optimized  AMI](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) in us-east-1 using this file:

```bash
aws ec2 run-instances --image-id ami-5253c32d \
  --key-name MyKeyPair \
  --user-data file://./templates/cloud-init-userdata.yaml \
  --count 1 \
  --security-group-ids sg-123abc123 \
  --instance-type t2.micro \
  --iam-instance-profile Name=MyInstanceProfileWithProperPermissions
```

## IAM Instance Profile

The following IAM policy is an example of the permissions that will be needed for these scripts to work:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVolumes",
                "ec2:ModifyInstanceAttribute",
                "ec2:DescribeVolumeAttribute",
                "ec2:CreateVolume"
            ],
            "Resource": "*"
        }
    ]
}
```
