#!/bin/bash

: "	
	linux 环境配置
"

# linux系统版本
LINUX_SYS_VERSION=

# linux的arch名称
LINUX_ARCH_NAME=

# linux的URL文件名称
URL_FILE_NAME=

# linux的文件名称
LINUX_FILE_NAME=

# 日期时间标识
TIMESTAMP_DIR_NAME=

# 脚本当前路径
SCRIPT_CUR_PATH=$(cd `dirname "$0}"` >/dev/null 2>&1; pwd)

# linux安装包路径
LINUX_PACKAGE_PATH=${SCRIPT_CUR_PATH}/packages

# linux系统路径
LINUX_SYSTEM_PATH=

# linux版本路径
LINUX_VERSION_PATH=

# linux文件包路径
LINUX_FILE_PATH=

# linux的URL路径
LINUX_URL_PATH=

# linux的binds路径
LINUX_BINDS_PATH=

# linux版本数组
LINUX_VER_ARRAY=(ubuntu debian kali fedora)

# linux操作数组
LINUX_EXEC_ARRAY=(install uninstall configure)

# 显示操作目录
showExecMenu()
{
	ver=$1
	
	printf "\033[1;33m%s\033[0m\n" "please input the correct comand:"
	printf "\033[1;31m%2d. %s\033[0m\n" 0 "return"
	
	for ((i=0; i<${#LINUX_EXEC_ARRAY[@]}; i++)) do
		printf "\033[1;36m%2d. %s\033[0m\n" $((i+1)) "${LINUX_EXEC_ARRAY[i]} ${ver} version"
	done
	
	printf "\033[1;33m%s\033[0m" "please input the command index:"
}

# 显示linux版本目录
showLinuxMenu()
{
	printf "\033[1;33m%s\033[0m\n" "please select the linux version:"
	printf "\033[1;31m%2d. %s\033[0m\n" "0" "exit"
	
	for ((i=0; i<${#LINUX_VER_ARRAY[@]}; i++)) do
		printf "\033[1;36m%2d. %s\033[0m\n" $((i+1)) "${LINUX_VER_ARRAY[i]}"
    done
	
	printf "\033[1;33m%s\033[0m" "please input the linux version index:"
}

# 获取命令序号
getUserIndex()
{
	stty erase ^H
	read value
	
	echo "$value"|[ -n "`sed -n '/^[0-9][0-9]*$/p'`" ]
	
	if [ "$?" = "0" ]; then
		result=$value
	else
		result=-1
	fi
	
	echo "$result"
}

# 暂停中止命令
pause()
{
	read -n 1 -p "$*" inp
	
	if [ "$inp" != '' ]; then
		echo -ne '\b \n'
	fi
}

# 设置linux所需环境
setLinuxEnv()
{
	if [ ! -d "${LINUX_PACKAGE_PATH}" ]; then
		mkdir "${LINUX_PACKAGE_PATH}"
	fi
	
	arch=$(uname -m)	# $(dpkg --print-architecture)
	case "${arch}" in
	aarch64)
		LINUX_ARCH_NAME="arm64"
		;;
	arm)
		LINUX_ARCH_NAME="armhf"
		;;
	amd64)
		LINUX_ARCH_NAME="amd64"
		;;
	x86_64)
		LINUX_ARCH_NAME="amd64" 
		;;
	i*86)
		LINUX_ARCH_NAME="i386"
		;;
	*)
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m unknown architecture :- $arch\n"
		exit 1
		;;
	esac
	
	if ! dpkg -l | grep -q wget; then
		apt install wget
	fi
	
	
	if ! dpkg -l | grep -q proot; then
		pkg install proot
	fi
	
	if ! dpkg -l | grep -q pulseaudio; then
		apt install pulseaudio
	fi
}

# 获取linux下载URL
getLinuxUrl()
{
	ver=$1
	
	case $ver in
	ubuntu)
		LINUX_SYS_VERSION=jammy
		# bionic(18.04) focal(20.04) jammy(22.04) lunar(23.04)
		
		URL_FILE_NAME="ubuntu-${LINUX_SYS_VERSION}-core-cloudimg-${LINUX_ARCH_NAME}-root.tar.gz"
		LINUX_URL_PATH="https://partner-images.canonical.com/core/${LINUX_SYS_VERSION}/current/${URL_FILE_NAME}"
		;;
	debian)
		LINUX_SYS_VERSION=buster
		# buster(10) bullseye(11) bookworm(12)
		
		URL_FILE_NAME="rootfs.tar.xz"
		TIMESTAMP_DIR_NAME="20240309_05:24"
		LINUX_URL_PATH="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/${LINUX_SYS_VERSION}/${LINUX_ARCH_NAME}/default/${TIMESTAMP_DIR_NAME}/${URL_FILE_NAME}"
		;;
	kali)
		URL_FILE_NAME="rootfs.tar.xz"
		TIMESTAMP_DIR_NAME="20240309_17:14"
		LINUX_URL_PATH="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/kali/current/${LINUX_ARCH_NAME}/default/${TIMESTAMP_DIR_NAME}/${URL_FILE_NAME}"
		;;
	fedora)
		LINUX_SYS_VERSION=39
		
		URL_FILE_NAME="rootfs.tar.xz"
		TIMESTAMP_DIR_NAME="20240309_20:33"
		LINUX_URL_PATH="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/fedora/${LINUX_SYS_VERSION}/${LINUX_ARCH_NAME}/default/${TIMESTAMP_DIR_NAME}/${URL_FILE_NAME}"
		;;
	*)
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m unknown system :- ${ver}\n"
		return 1
		;;
	esac
	
	if [ -z ${LINUX_URL_PATH} ]; then
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m the ${ver} system rootfs URL not provided, please check!\n"
		return 1
	fi
	
	return 0
}

# 下载linux安装包
downloadPackages()
{
	ver=$1
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m downloading the ${ver} system rootfs, please wait...\n"
	
	# 获取linux下载URL
	getLinuxUrl ${ver} || return 0
	
	# 解析文件下载路径
	if [ -n "${URL_FILE_NAME}" ]; then
		if [[ "${URL_FILE_NAME: -3}" == ".gz" ]]; then
			LINUX_FILE_PATH="${LINUX_PACKAGE_PATH}/${LINUX_FILE_NAME}.tar.gz"
		elif [[ "${URL_FILE_NAME: -3}" == ".xz" ]]; then
			LINUX_FILE_PATH="${LINUX_PACKAGE_PATH}/${LINUX_FILE_NAME}.tar.xz"
		fi
	fi
	
	if [ -z "${LINUX_FILE_PATH}" ] || ! wget -c "${LINUX_URL_PATH}" -O "${LINUX_FILE_PATH}"; then
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m the ${ver} system rootfs download failed, please check!\n"
		return 1
	fi
	
	fileSize=$(stat -c %s "${LINUX_FILE_PATH}")
	if [ "$fileSize" -eq 0 ]; then
		rm -f "${LINUX_FILE_PATH}"
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m the ${ver} system rootfs is invalid, please check!\n"
		return 1
	fi
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m the ${ver} system rootfs download complete!\n"
	return 0
}

# 设置linux配置
setLinuxConf()
{
	ver=$1
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m the ${ver} system rootfs is being configured, please wait...\n"
	
	# resolv.conf
	if [ -f "${LINUX_VERSION_PATH}/etc/resolv.conf" ]; then
		> "${LINUX_VERSION_PATH}/etc/resolv.conf"	#清空原有的resolv.conf内容
		
		ipAddress=("8.8.8.8" "8.8.4.4")
		for ip in "${ipAddress[@]}"; do
			printf "nameserver %s\n" "$ip" >> "${LINUX_VERSION_PATH}/etc/resolv.conf"
		done
	fi
	
	# .bashrc
	if [ -f "${LINUX_VERSION_PATH}/root/.bashrc" ]; then
		timeZone="export TZ='Asia/Shanghai'"
		if [ -z "$(sed -n "\#^${timeZone}#p" ${LINUX_VERSION_PATH}/root/.bashrc)" ]; then
			printf "%s\n" "$timeZone" >> "${LINUX_VERSION_PATH}/root/.bashrc"
		fi
	fi
	
	# groups
	stubs=()
	if [ -f "${LINUX_VERSION_PATH}/usr/bin/groups" ]; then
		stubs+=("${LINUX_VERSION_PATH}/usr/bin/groups")
	fi
	
	for file in ${stubs[@]}; do
		echo -e "#!/bin/sh\nexit" > "${file}"
	done
	
	# linux运行脚本
	verStartFile="${SCRIPT_CUR_PATH}/start${ver}.sh"
	if [ ! -f "${verStartFile}" ]; then
		cat > $verStartFile <<- EOM
			#!/bin/bash
			cd \$(dirname \$0)
			
			## unset LD_PRELOAD in case termux-exec is installed
			unset LD_PRELOAD
			
			command="proot"
			command+=" --link2symlink"
			command+=" -0"
			command+=" -r ${LINUX_VERSION_PATH}"
			
			if [ -n "\$(ls -A ${LINUX_BINDS_PATH})" ]; then
			    for f in ${LINUX_BINDS_PATH}/* ;do
			        . \$f
			    done
			fi
			
			command+=" -b /dev"
			command+=" -b /proc"
			command+=" -b /sys"
			command+=" -b ${LINUX_VERSION_PATH}/tmp:/dev/shm"

			command+=" -b ${ANDROID_DATA}"
			command+=" -b ${EXTERNAL_STORAGE}"
			command+=" -b ${HOME}"
			command+=" -b /:/host-rootfs"
			command+=" -b /mnt"
			
			command+=" -w /root"
			command+=" /usr/bin/env -i"
			command+=" HOME=/root"
			command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
			command+=" TERM=\$TERM"
			command+=" LANG=C.UTF-8"
			command+=" /bin/bash --login"
			
			com="\$@"
			if [ -z "\$1" ];then
			    exec \$command
			else
			    \$command -c "\$com"
			fi	
		EOM
		
		termux-fix-shebang $verStartFile
		chmod +x $verStartFile
	fi
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m the ${ver} system rootfs configuration completed!\n"
}

installLinuxEnv()
{
	ver=$1	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m installing the ${ver} system rootfs, please wait...\n"
	
	if [ "$(ls -A $LINUX_VERSION_PATH)" ]; then
		clear
		
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;227m[WARNING]:\e[0m \x1b[38;5;87m the ${ver} system rootfs has been installed, please check!\n"
		return 1
	fi
	
	# 检索文件列表
	LINUX_FILE_NAME="${ver}-${LINUX_ARCH_NAME}"
	fileList=$(find "${LINUX_PACKAGE_PATH}" -name "${LINUX_FILE_NAME}*.tar*" | sort -s | tail -n 1)
	
	# 获取文件压缩包
	LINUX_FILE_PATH="${fileList}"
	if [ -z "${LINUX_FILE_PATH}" ]; then
		# 下载linux安装包
		downloadPackages $ver || return 1
	fi

	fileSize=$(stat -c %s "${LINUX_FILE_PATH}")
	if [ "$fileSize" -eq 0 ]; then
		clear
		rm -f "${LINUX_FILE_PATH}"
		
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m the ${ver} system rootfs is invalid, please check!\n"
		return 1
	fi
	
	if [ "$(ls -A $LINUX_VERSION_PATH)" ]; then
		rm -rf "${LINUX_VERSION_PATH}/*"
	fi
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m decompressing the ${ver} system rootfs, please wait...\n"
	#proot --link2symlink tar -xpf ${LINUX_FILE_PATH} -C ${LINUX_VERSION_PATH} --exclude='dev'||:
	
	if ! proot --link2symlink tar -xf "${LINUX_FILE_PATH}" -C "${LINUX_VERSION_PATH}" --exclude='dev'; then
		clear
		
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;203m[ERROR]:\e[0m \x1b[38;5;87m the ${ver} system rootfs decompress failed, please check!\n"
		return 1
	else
		printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m the ${ver} system rootfs have been successfully decompressed!\n"
		setLinuxConf $ver
	fi
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m the ${ver} system rootfs have been successfully installed!\n"
	return 0
}

uninstallLinuxEnv()
{
	ver=$1	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m uninstalling the ${ver} system rootfs, please wait...\n"
	
	LINUX_VERSION_PATH="${SCRIPT_CUR_PATH}/${ver}"
	if [ -d "${LINUX_VERSION_PATH}" ] ; then
		rm -rf "${LINUX_VERSION_PATH}"
	fi
	
	verStartFile="${SCRIPT_CUR_PATH}/start${ver}.sh"
	[ -f "$verStartFile" ] && rm -rf "$verStartFile"
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m ${ver} system rootfs have been successfully uninstalled!\n"
	return 0;
}

configureLinuxEnv()
{
	ver=$1
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m configuring the ${ver} system rootfs, please wait...\n"
	
	# 设置linux配置
	setLinuxConf $ver
	
	printf "\x1b[38;5;214m[${time1}]\e[0m \x1b[38;5;83m[Installer thread/INFO]:\e[0m \x1b[38;5;87m ${ver} system rootfs have been successfully configured!\n"
	return 0;
}

# 初始化linux环境
initLinuxEnv()
{
	clear
	ver=$1

	while [ 1 ]; do
		# 显示操作目录
		showExecMenu $ver | pr -1 -t
		
		# 获取用户输入
		value=`getUserIndex`
		
		# 判断输入值是否有效
		if [ $value -lt 0 ] || [ $value -gt ${#LINUX_EXEC_ARRAY[@]} ]; then
			echo -e "\033[1;43;31mNOTICE\033[0m: please input a valid command number!\n"
			continue
		fi
		
		# 退出选择列表
		[ $value -eq 0 ] && { return 0; }
		
		LINUX_VERSION_PATH="${SCRIPT_CUR_PATH}/${ver}"
		if [ ! -d "${LINUX_VERSION_PATH}" ]; then
			mkdir "${LINUX_VERSION_PATH}"
		fi
	
		LINUX_BINDS_PATH="${SCRIPT_CUR_PATH}/binds"
		if [ ! -d "${LINUX_BINDS_PATH}" ]; then
			mkdir "${LINUX_BINDS_PATH}"
		fi
		
		cmd=${LINUX_EXEC_ARRAY[$((value-1))]}
		case ${cmd} in
		install)
			installLinuxEnv $ver
			return $?
			;;
		uninstall)
			uninstallLinuxEnv $ver
			return $?
			;;
		configure)
			configureLinuxEnv $ver
			return $?
			;;
		*)
			;;
		esac
	done
	
	return 1
}

runAppLinux()
{
	clear
	setLinuxEnv

	while [ 1 ]; do
		# 显示linux版本目录
		showLinuxMenu | pr -1 -t
		
		# 获取用户输入
		value=`getUserIndex`
		
		# 判断输入值是否有效
		if [ $value -lt 0 ] || [ $value -gt ${#LINUX_VER_ARRAY[@]} ]; then
			clear
			echo -e "\033[1;43;31mNOTICE\033[0m: please input a valid linux version number!\n"
			continue
		fi
		
		# 退出选择列表
		[ $value -eq 0 ] && { break; }
		
		# 检查输入值是否为有效的索引
		if ver=${LINUX_VER_ARRAY[$((value-1))]}; then
			# 初始化linux环境
			initLinuxEnv $ver
			
			pause "press any key to continue..."
			clear
		fi
	done
}

runAppLinux