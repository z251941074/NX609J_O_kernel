#!/bin/bash
### DO NOT EDIT THIS FILE ###

#################################################1 define INIT_TARGET_PRODUCT and TARGET_PRODUCT ###############################################

app_build_root=`pwd`
echo ${app_build_root}


INIT_TARGET_PRODUCT=NX609J
FINAL_TARGET_PRODUCT=NX609J
KERNEL_PERF_DEFCONFIG=perf

echo -e "\033[01;32mINIT_TARGET_PRODUCT=${INIT_TARGET_PRODUCT}\033[0m"
echo -e "\033[01;32mFINAL_TARGET_PRODUCT=${FINAL_TARGET_PRODUCT}\033[0m"

#################################################2 kernel modules ###############################################

KERNEL_MODULES_OUT=${app_build_root}/out/target/product/${FINAL_TARGET_PRODUCT}/system/lib/modules
function mv-modules()
{
	#find用法：-type f表示是文件名  -name 文件名,返回文件完整路径
	mdpath=`find ${KERNEL_MODULES_OUT} -type f -name modules.dep`
	echo -e "\033[01;32m mdpath=${mdpath}\033[0m"

	if [ "$mdpath" != "" ];then
		#dirname用法：路径去除后面文件，只保留上一层路径
		#basename用法：路径去除上一层路径，只保留最后一个文件名，举例如下：
		# mdpath=/home/dream/samba/NX609J_O_kernel-master/out/target/product/NX609J/system/lib/modules/4.4.78/modules.dep
		# dirname mdpath=/home/dream/samba/NX609J_O_kernel-master/out/target/product/NX609J/system/lib/modules/4.4.78
		# basename basepath=modules.dep

		mpath=`dirname $mdpath`
		echo -e "\033[01;32m dirname mdpath=${mpath}\033[0m"
		basepath=`basename $mdpath`
		echo -e "\033[01;32m basename basepath=${basepath}\033[0m"		
		#echo mpath=$mpath
		ko=`find $mpath/kernel -type f -name *.ko`
		for i in $ko
		do
			mv $i ${KERNEL_MODULES_OUT}/
		done
	fi
}

function clean-module-folder()
{
	mdpath=`find ${KERNEL_MODULES_OUT} -type f -name modules.dep`
	if [ "$mdpath" != "" ];then
		mpath=`dirname $mdpath`
		rm -rf $mpath
	fi
}

####################################################3 dts and kernel config ############################################
export TARGET_KERNEL_APPEND_DTB=true
export ZTEMT_DTS_NAME="msm8998-v2.1-mtp-${FINAL_TARGET_PRODUCT}.dtb msm8998-v2-mtp-${FINAL_TARGET_PRODUCT}.dtb msm8998-mtp-${FINAL_TARGET_PRODUCT}.dtb"
echo -e "\033[01;32mZTEMT_DTS_NAME = ${ZTEMT_DTS_NAME}\033[0m"

if [ "${KERNEL_PERF_DEFCONFIG}" == "perf" ]
then
	KERNEL_DEFCONFIG=msmcortex-perf-NX609J_defconfig
else
	KERNEL_DEFCONFIG=msmcortex-NX609J_defconfig
fi
echo -e "\033[01;32mKERNEL_DEFCONFIG = ${KERNEL_DEFCONFIG}\033[0m"


###################################################4 config PATH #######################


echo -e "\033[01;32m======================config build kernel environment value============================\033[0m"
export  PATH=${app_build_root}/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin:${app_build_root}/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin:$PATH
#export用法：输出当前的Linux环境变量
export
echo -e "\033[01;32m=======================================================================================\033[0m"


###################################################5 clear old Image-gz #######################

echo -e "\033[01;32mdelete Image.gz-dtb...\033[0m"
rm -rf out/target/product/${FINAL_TARGET_PRODUCT}/obj/KERNEL_OBJ/arch/arm64/boot


###################################################6 config .config #######################
echo -e "\033[01;32mBuilding .config...\033[0m"
make -C kernel/msm-4.4 O=../../out/target/product/${FINAL_TARGET_PRODUCT}/obj/kernel/msm-4.4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- ${KERNEL_DEFCONFIG}


###################################################7 build new Image-gz and moudles #######################
echo -e "\033[01;32mBuilding kernel...\033[0m"
make -C kernel/msm-4.4 O=../../out/target/product/${FINAL_TARGET_PRODUCT}/obj/kernel/msm-4.4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- KCFLAGS=-mno-android  -j`grep processor /proc/cpuinfo |wc -l`
RET_VAL=$?
make -C kernel/msm-4.4 O=../../out/target/product/${FINAL_TARGET_PRODUCT}/obj/kernel/msm-4.4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- KCFLAGS=-mno-android modules
#INSTALL_MOD_PATH表示安装路径 O=表示当前位置
make -C kernel/msm-4.4 O=../../out/target/product/${FINAL_TARGET_PRODUCT}/obj/kernel/msm-4.4 INSTALL_MOD_PATH=../../../system INSTALL_MOD_STRIP=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- modules_install


###################################################8 mv moudles to system/lib/modules #######################
echo -e "\033[01;32mmv-modules clean-module-folder...\033[0m"
mv-modules
clean-module-folder

if [ $RET_VAL -gt 0 ]
then
	echo -e "\033[01;32m***********************************************************\033[0m"
	echo -e "\033[01;31m         Build error!!! Please see build log above         \033[0m"
	echo -e "\033[01;32m***********************************************************\033[0m"
	exit $RET_VAL
fi


####9.1 cp Image.gz-dtb to kernel #######################
####9.2 mkbootfs root | minigzip > ramdisk.img #######################
####9.3 mkbootimg --kernel kernel  --ramdisk ramdisk.img  --base 0x00000000 --pagesize 4096 --cmdline "..." --os_version 8.1.0 --os_patch_level 2018-02-01  --output boot.img#######################


echo -e "\033[01;32mcp -rf Image.gz-dtb kernel...\033[0m"
cp -rf out/target/product/${FINAL_TARGET_PRODUCT}/obj/kernel/msm-4.4/arch/arm64/boot/Image.gz-dtb out/target/product/${FINAL_TARGET_PRODUCT}/kernel

echo -e "\033[01;32mmkbootfs ramdisk.img...\033[0m"
out/host/linux-x86/bin/mkbootfs -d out/target/product/${FINAL_TARGET_PRODUCT}/system out/target/product/${FINAL_TARGET_PRODUCT}/root | out/host/linux-x86/bin/minigzip > out/target/product/${FINAL_TARGET_PRODUCT}/ramdisk.img

echo -e "\033[01;32mmkbootimg boot.img...\033[0m"
out/host/linux-x86/bin/mkbootimg --kernel out/target/product/${FINAL_TARGET_PRODUCT}/kernel --ramdisk out/target/product/${FINAL_TARGET_PRODUCT}/ramdisk.img --base 0x00000000 --pagesize 4096 --cmdline "console=ttyMSM0,115200,n8 androidboot.console=ttyMSM0 earlycon=msm_serial_dm,0xc1b0000 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 sched_enable_hmp=1 sched_enable_power_aware=1 service_locator.enable=1 swiotlb=2048 androidboot.configfs=true androidboot.usbcontroller=a800000.dwc3 buildvariant=userdebug"  --os_version 8.1.0 --os_patch_level 2018-02-01  --output out/target/product/${FINAL_TARGET_PRODUCT}/boot.img

####10 mboot_signer boot.img#####################################

echo -e "\033[01;32mboot_signer boot.img...\033[0m"
out/host/linux-x86/bin/boot_signer /boot out/target/product/${FINAL_TARGET_PRODUCT}/boot.img build/target/product/security/verity.pk8 build/target/product/security/verity.x509.pem out/target/product/${FINAL_TARGET_PRODUCT}/boot.img


echo "[01;32m==================================================================[0m"
echo "Now, the boot.img images are in dir:"
echo -e "\033[01;32m${app_build_root}/out/target/product/${FINAL_TARGET_PRODUCT}/boot.img\033[0m"
echo "[01;32m==================================================================[0m"


echo "=============================================="
echo          Build finished at `date`.
echo "=============================================="


### DO NOT EDIT THIS FILE ###
