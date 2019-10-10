#!/bin/bash
#
red="\033[31m"
green="\033[32m"
white="\033[0m"

out_dir="./out"
openwrt_dir="./openwrt"
rootfs_dir="/media/rootfs"
loop=


echo  -e "\n贝壳云Openwrt镜像制作工具"
#检测root权限
if [ $UID -ne 0 ];then
echo -e "$red \n 错误：请使用root用户或sudo执行此脚本！$white" && exit
fi


#清理重建目录
if [ -d $out_dir ]; then
    sudo rm -rf $out_dir
fi

mkdir -p $out_dir/openwrt
sudo mkdir -p $rootfs_dir

# 解压openwrt固件
cd $openwrt_dir
if [ -f *ext4-factory.img.gz ]; then
    gzip -d *ext4-factory.img.gz
elif [ -f *root.ext4.gz ]; then
    gzip -d *root.ext4.gz
elif [ -f *rootfs.tar.gz ] || [ -f *ext4-factory.img ] || [ -f *root.ext4 ]; then
    [ ]
else
    echo -e "$red \n openwrt目录下不存在固件或固件类型不受支持! $white" && exit
fi

# 挂载openwrt固件
if [ -f *rootfs.tar.gz ]; then
    sudo tar -xzf *rootfs.tar.gz -C ../$out_dir/openwrt
elif [ -f *ext4-factory.img ]; then
    loop=$(sudo losetup -P -f --show *ext4-factory.img)
    if ! sudo mount -o rw ${loop}p2 $rootfs_dir; then
        echo -e "$red \n 挂载OpenWrt镜像失败! $white" && exit
    fi
elif [ -f *root.ext4 ]; then
    sudo mount -o loop *root.ext4 $rootfs_dir
fi

# 拷贝openwrt rootfs
echo -e "$green \n 提取OpenWrt ROOTFS... $white"
cd ../$out_dir
if df -h | grep $rootfs_dir > /dev/null 2>&1; then
    sudo cp -r $rootfs_dir/* openwrt/ && sync
    sudo umount $rootfs_dir
    [ $loop ] && sudo losetup -d $loop
fi

sudo cp -r ../armbian/beikeyun/rootfs/* openwrt/ && sync

# 制作可启动镜像
echo && read -p "请输入ROOTFS分区大小(单位MB)，默认256M: " rootfssize
[ $rootfssize ] || rootfssize=256

openwrtsize=$(sudo du -hs openwrt | cut -d "M" -f 1)
[ $rootfssize -lt $openwrtsize ] && \
    echo -e "$red \n ROOTFS分区最少需要 $openwrtsize MB! $white" && \
    exit

echo -e "$green \n 生成空镜像(.img)... $white"

fallocate -l ${rootfssize}MB "$(date +%Y-%m-%d)-openwrt-beikeyun-auto-generate.img"


# 格式化镜像
echo -e "$green \n 格式化... $white"
loop=$(sudo losetup -P -f --show *.img)
[ ! $loop ] && \
    echo -e "$red \n 格式化失败! $white" && \
    exit

    #MBR引导
sudo parted -s $loop  mklabel msdos> /dev/null 2>&1
    #创建分区1/设定主分区
sudo parted $loop mkpart primary 17 $rootfssize  >/dev/null 2>&1
    #
loopp1=${loop}p1 
    #格式化分区1
sudo mkfs.ext4 $loopp1 > /dev/null 2>&1
    #获取分区1UUID
p1uuid=$(sudo tune2fs -l $loopp1|grep UUID|awk '{print $3}')
    #设定分区目录挂载路径
rootfs_dir=/media/$p1uuid
    #删除重建目录
sudo rm -rf $rootfs_dir
sudo mkdir $rootfs_dir
    #挂载p1分区到新建目录
    sudo mount -o rw $loopp1 $rootfs_dir
echo "p1uuid:$p1uuid"
    #写入UUID 到fstab
    sudo echo "UUID=$p1uuid / ext4 defaults,noatime,nodiratime,commit=600,errors=remount-ro 0 1">openwrt/etc/fstab
    sudo echo "tmpfs /tmp tmpfs defaults,nosuid 0 0">>openwrt/etc/fstab

# 拷贝文件到启动镜像
cd ../
    #创建armbianEnv.txt
    sudo rm -rf armbian/beikeyun/boot/armbianEnv.txt
    sudo touch armbian/beikeyun/boot/armbianEnv.txt
    #写入UUID到armbianEnv
    sudo echo "verbosity=7">armbian/beikeyun/boot/armbianEnv.txt
    sudo echo "overlay_prefix=rockchip">>armbian/beikeyun/boot/armbianEnv.txt
    sudo echo "rootdev=UUID=$p1uuid">>armbian/beikeyun/boot/armbianEnv.txt
    sudo echo "rootfstype=ext4">>armbian/beikeyun/boot/armbianEnv.txt
    sudo echo "fdtfile=rk3328-beikeyun.dtb">>armbian/beikeyun/boot/armbianEnv.txt

    sudo cp -r armbian/beikeyun/boot $out_dir/openwrt/boot
    sudo chown -R root:root $out_dir/openwrt/
    sudo mv $out_dir/openwrt/* $rootfs_dir




# 取消挂载
if df -h | grep $rootfs_dir > /dev/null 2>&1 ; then
    sudo umount $rootfs_dir
fi

[ $loopp1 ] && sudo losetup -d $loop

# 清理残余
sudo rm -rf $boot_dir
sudo rm -rf $rootfs_dir
sudo rm -rf $out_dir/openwrt

#添加idb标识以及uboot
    #获取输出镜像文件名
img=$(ls -l $out_dir|grep img|awk '{print $9}')
echo -e  "$green \n 写入idb $white"
dd if=armbian/beikeyun/others/idb of=$out_dir/$img bs=16 seek=2048 conv=notrunc
echo -e  "$green \n 写入uboot $white"
dd if=armbian/beikeyun/others/u-boot of=$out_dir/$img bs=16 seek=524288  conv=notrunc


echo -e "$green \n 制作成功, 输出文件夹 --> $out_dir $white"

