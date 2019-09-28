### 贝壳云Openwrt镜像制作工具
#### Usage
1. 编译, 不会的可以去 [Lean's OpenWrt source](https://github.com/coolsnowwolf/lede "Lean's OpenWrt source") 
target选

Target System (QEMU ARM Virtual Machine)  ---> 
Subtarget (ARMv8 multiplatform)  ---> 

2. 将编译好的固件放入到"openwrt"目录 
   注意: 固件格式只支持"rootfs.tar.gz"、"ext4-factory.img.gz"、"ext4-factory.img"、"root.ext4.gz"和"root.ext4"
3. 执行以root身份执行脚本或使用sudo bash BKmkop.sh, 默认输出路径"out/xxx.img"


