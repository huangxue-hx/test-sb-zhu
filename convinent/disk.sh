#!/bin/bash

# 磁盘\分区名称
DISK=sdb
DISKNAME=${DISK}1
TIME=`date -d today +"%Y-%m-%d"`

# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 创建磁盘分区
CHECK_EXIST=`/sbin/fdisk -l 2> /dev/null | grep -o "$DISK"`
[ ! "$CHECK_EXIST" ] && { echo "Error: Disk is not found !"; exit 1; }

echo "1" >> /tmp/disk_$TIME.log

CHECK_DISK_EXIST=`/sbin/fdisk -l 2> /dev/null | grep -o "$DISK[1-9]"`
[ ! "$CHECK_DISK_EXIST" ] || { echo "WARNING: ${CHECK_DISK_EXIST} is Partition already !"; exit 1; }

echo "2" >> /tmp/disk_$TIME.log

fdisk /dev/$DISK<<EOF  
n




t
8e
w
EOF

# 创建pv和创建vg
pvcreate /dev/$DISKNAME
vgcreate docker /dev/$DISKNAME
lvcreate --wipesignatures y -n thinpool -l 90%VG docker #(vg名称)
lvcreate --wipesignatures y -n thinpoolmeta -l 5%VG docker #(vg名称)
lvconvert -y --zero n -c 512K --thinpool docker/thinpool --poolmetadata docker/thinpoolmeta

touch /etc/lvm/profile/docker-thinpool.profile
echo "activation {" >> /etc/lvm/profile/docker-thinpool.profile
echo "thin_pool_autoextend_threshold=80" >> /etc/lvm/profile/docker-thinpool.profile
echo "thin_pool_autoextend_percent=20}" >> /etc/lvm/profile/docker-thinpool.profile

lvchange --metadataprofile docker-thinpool docker/thinpool
