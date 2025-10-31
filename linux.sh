#!/bin/bash

###############################################################################
# Linux 系统管理脚本
# 
# 功能描述: 
#   本脚本用于在 Termux 环境中管理多个 Linux 发行版的安装、配置和运行。
#   支持 Ubuntu、Debian、Kali、Fedora 等系统，提供图形化菜单交互界面。
#
# 主要功能模块:
#   - 系统架构检测与环境初始化
#   - Linux 发行版下载与安装
#   - 根文件系统配置与管理
#   - 用户交互菜单系统
#   - 系统备份与恢复
#
# 作者: lysgwl
# 版本: 1.0
###############################################################################

# 脚本当前路径
SCRIPT_CUR_PATH=$(cd `dirname "$0}"` >/dev/null 2>&1; pwd)

# linux安装包路径
LINUX_PACKAGE_DIR="$SCRIPT_CUR_PATH/packages"

# PRoot绑定挂载配置目录
LINUX_BINDS_DIR="$SCRIPT_CUR_PATH/binds"

# Linux 根文件系统目录
LINUX_ROOTFS_DIR="$SCRIPT_CUR_PATH/roots"

# linux的arch名称
LINUX_ARCH_NAME=""

# linux版本数组
LINUX_VER_ARRAY=(ubuntu debian kali fedora)

# linux操作数组
LINUX_CMD_ARRAY=(安装-install 卸载-uninstall)

###############################################################################
# 用户交互模块

# 暂停脚本执行，等待用户按键
pause()
{
	read -n 1 -p "$*" inp
	
	if [ "$inp" != '' ]; then
		echo -ne '\b \n'
	fi
}

print_log()
{
	# 参数验证
	if [ "$#" -lt 2 ] || [ -z "$1" ]; then
		echo "Usage: print_log <log_level> <message> [func_type]"
		return 1
	fi
	
	local log_level="$1"
	local message="$2"
	local func_type="${3:-}"  # 可选参数
	
	# 获取当前时间
	local time1="$(date +"%Y-%m-%d %H:%M:%S")"
	
	# 初始化颜色变量
	local log_time=""
	local log_level_color=""
	local log_func=""
	local log_message=""
	
	# 时间戳格式
	if [ -n "$time1" ]; then
		log_time="\x1b[38;5;208m[${time1}]\x1b[0m"
	fi
	
	# 日志级别颜色设置
	case "$log_level" in
		"TRACE")
			log_level_color="\x1b[38;5;76m[TRACE]:\x1b[0m"        # 深绿色
			;;
		"DEBUG")
			log_level_color="\x1b[38;5;208m[DEBUG]:\x1b[0m"       # 浅橙色
			;;
		"WARNING")
			log_level_color="\033[1;43;31m[WARNING]:\x1b[0m"      # 黄色底红字
			;;
		"INFO")
			log_level_color="\x1b[38;5;76m[INFO]:\x1b[0m"         # 深绿色
			;;
		"ERROR")
			log_level_color="\x1b[38;5;196m[ERROR]:\x1b[0m"       # 深红色
			;;
		*)
			echo "Unknown log level: $log_level"
			return 1
			;;
	esac
	
	 # 功能名称
	if [ -n "$func_type" ]; then
		log_func="\x1b[38;5;210m(${func_type})\x1b[0m"
	fi
	
	# 消息内容
	if [ -n "$message" ]; then
		log_message="\x1b[38;5;87m${message}\x1b[0m"
	else
		log_message="\x1b[38;5;87m(No message)\x1b[0m"
	fi
	
	# 构建输出字符串
	local output=""
	
	# 添加时间戳
	[ -n "$log_time" ] && output="${output}${log_time} "
	
	# 添加日志级别
	output="${output}${log_level_color}"
	
	# 添加功能类型
	[ -n "$log_func" ] && output="${output} ${log_func}"
	
	# 添加消息内容
	output="${output} ${log_message}"
	
	# 输出日志
	printf "${output}\n"
}

# 获取用户输入的菜单序号
input_user_index()
{
	local value
	local result
	
	# 提示用户输入
	read -r -e -p "$(printf "\033[1;33m请输出正确的序列号:\033[0m")" value
	
	# 过滤输入，只接受数字
	if [[ "$value" =~ ^[0-9]+$ ]]; then
		result="$value"
	else
		result=-1
	fi
	
	echo "$result"
}

# 显示操作命令菜单
show_cmd_menu()
{
	local version=$1
	local -n cmd_array_ref=$2
	
	local version_path="$LINUX_ROOTFS_DIR/$version"
	printf "\033[1;33m%s\033[0m" "请选择命令序号"
	
	# 检查系统是否已安装并显示状态
	if [[ -d "$version_path" && -n "$(ls -A "$version_path" 2>/dev/null)" ]]; then
		printf "(\033[1;32m%s 已安装\033[0m):\n" "$version"
	else
		printf "(\033[1;31m%s 未安装\033[0m):\n" "$version"
	fi
	
	printf "\033[1;31m%2d. %s\033[0m\n" 0 "返回"
	
	for ((i=0; i<${#cmd_array_ref[@]}; i++)); do
		local item="${cmd_array_ref[i]}"
		local part="${item%-*}"
		
		printf "\033[1;36m%2d. %s\033[0m\n" $((i+1)) "${part}版本"
	done
}

# 显示Linux系统选择菜单
show_linux_menu()
{
	local -n linux_array_ref=$1
	
	printf "\033[1;33m%s\033[0m\n" "请选择linux类型:"
	printf "\033[1;31m%2d. %s\033[0m\n" "0" "关闭"
	
	for ((i=0; i<${#linux_array_ref[@]}; i++)) do
		local version_name="${linux_array_ref[i]}"
		local version_path="$LINUX_ROOTFS_DIR/$version_name"
		
		# 检查系统是否已安装
		if [[ -d "$version_path" && -n "$(ls -A "$version_path" 2>/dev/null)" ]]; then
			printf "\033[1;36m%2d. %s \033[1;32m✓\033[0m\n" $((i+1)) "$version_name"
		else
			printf "\033[1;36m%2d. %s \033[1;31m✗\033[0m\n" $((i+1)) "$version_name"
		fi
	done
	
	printf "\n\033[1;33m状态说明: \033[1;32m✓ 已安装 \033[1;31m✗ 未安装\033[0m\n"
}

###############################################################################
# 系统配置模块

# 设置DNS网络配置
set_dns_conf()
{
	local version="$1"
	local version_path="$2"
	
	print_log "INFO" "配置DNS服务器" >&2
	
	# resolv.conf
	if [ ! -f "$version_path/etc/resolv.conf" ]; then
		print_log "WARNING" "resolv.conf文件不存在: $version_path/etc/resolv.conf" >&2
		return 1
	fi
	
	# 清空原有的resolv.conf内容
	> "$version_path/etc/resolv.conf"
	
	# 配置DNS服务器
	local dns_servers=("8.8.8.8" "8.8.4.4" "1.1.1.1")
	
	for server  in "${dns_servers[@]}"; do
		printf "nameserver %s\n" "$server" >> "$version_path/etc/resolv.conf"
	done
	
	print_log "INFO" "DNS配置完成: ${dns_servers[*]}" >&2
	return 0
}

# 设置时区配置
set_timezone_conf()
{
	local version="$1"
	local version_path="$2"
	
	print_log "INFO" "配置系统时区" >&2
	
	# .bashrc
	local bashrc_file="$version_path/root/.bashrc"
	
	if [ ! -f "$bashrc_file" ]; then
		print_log "WARNING" ".bashrc文件不存在: $bashrc_file" >&2
		return 1
	fi
	
	# 检查是否已配置时区
	if grep -qF "export TZ=" "$bashrc_file"; then
		print_log "DEBUG" "时区配置已存在" >&2
		return 0
	fi
	
	# 添加时区配置
	cat >> "$bashrc_file" << 'EOF'

export TZ='Asia/Shanghai'
EOF
	
	print_log "INFO" "时区配置已添加: Asia/Shanghai" >&2
	return 0
}

# 设置存根配置
set_stubs_conf()
{
	local version="$1"
	local version_path="$2"
	
	print_log "INFO" "配置命令存根" >&2
	
	local stub_commands=(
		"/usr/bin/groups"
		"/usr/bin/id"
		"/usr/bin/whoami"
	)
	
	for cmd in "${stub_commands[@]}"; do
		local path="$version_path$cmd"

		if [ ! -f "$path" ]; then
			continue
		fi

		# 创建存根脚本
		cat > "$path" << 'STUB_EOF'
#!/bin/sh
# Command stub for proot environment
exit 0
STUB_EOF
		chmod +x "$path"
		print_log "INFO" "创建命令存根: $cmd" >&2
	done
	
	print_log "INFO" "命令存根配置完成" >&2
	return 0
}

# 生成启动脚本
generate_startup_script()
{
	local version="$1"
	local version_path="$2"
	
	print_log "INFO" "生成启动脚本" >&2
	
	local verStartFile="${SCRIPT_CUR_PATH}/run-${version}.sh"
	if [ -f "$verStartFile" ]; then
		print_log "DEBUG" "启动脚本已存在: $verStartFile" >&2
		return 0
	fi
	
	# 生成启动脚本
	cat > "$verStartFile" << SCRIPT_EOF
#!/bin/bash
cd \$(dirname \$0)

## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD

command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $version_path"

# Load bind mounts configuration
if [ -n "\$(ls -A ${LINUX_BINDS_DIR} 2>/dev/null)" ]; then
	for f in ${LINUX_BINDS_DIR}/* ;do
		if [ -f "\$f" ]; then
			. "\$f"
		fi
	done
fi

# Essential system binds
command+=" -b /dev" 
command+=" -b /proc"
command+=" -b /sys"
command+=" -b $version_path/tmp:/dev/shm"

# Android system binds
command+=" -b ${ANDROID_DATA}"
command+=" -b ${EXTERNAL_STORAGE}"
command+=" -b ${HOME}"
command+=" -b /:/host-rootfs"
command+=" -b /mnt"

# Environment setup
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"

# Execute command
com="\$@"
if [ -z "\$1" ]; then
	exec \$command
else
	\$command -c "\$com"
fi
SCRIPT_EOF
	
	# 修复shebang并设置执行权限
	if command -v termux-fix-shebang >/dev/null 2>&1; then
		termux-fix-shebang "$verStartFile"
		print_log "DEBUG" "修复shebang: $verStartFile" >&2
	fi
	
	chmod +x "$verStartFile"
	print_log "INFO" "启动脚本生成完成: $verStartFile" >&2
	return 0
}

# 设置linux系统配置
set_linux_conf()
{
	local version="$1"
	local version_path="$2"
	
	print_log "INFO" "正在配置 ${version} 根文件系统"
	
	if [[ ! -d "$version_path" && -z "$(ls -A "$version_path" 2>/dev/null)" ]]; then
		print_log "ERROR" "${version} 系统目录不存在, 请检查!" >&2
		return 1
	fi
	
	# 执行各个配置函数
	local config_functions=(
		"set_dns_conf"
		"set_timezone_conf" 
		"set_stubs_conf"
		"generate_startup_script"
	)
	
	for func in "${config_functions[@]}"; do
		if ! $func "$version" "$version_path"; then
			print_log "ERROR" "配置函数执行失败: $func" >&2
			return 2
		fi
	done
	
	print_log "INFO" "成功配置 ${version} 根文件系统!" >&2
	return 0;
}

# 提取文件扩展名
get_file_extension()
{
	local filename="$1"
	
	# 优先匹配常见压缩格式扩展名
	local extension=$(echo "$filename" | grep -oE '\.tar\.(gz|xz|bz2|lzma|Z)$|\.tar$|\.tgz$|\.tbz2$|\.zip$|\.gz$|\.xz$|\.bz2$')
	
	# 如果优先匹配没有找到
	if [[ -z "$extension" && "$filename" =~ \.[^./]*$  ]]; then
		extension="${BASH_REMATCH[0]}"
		
		# 避免把纯数字当作扩展名
		if [[ "$extension" =~ ^\.[0-9]+$ ]]; then
			extension=""
		fi
	fi
	
: <<'COMMENT_BLOCK'
	local base_name="" suffix=""
	if [[ "$sys_filename" =~ ^(.+)(\.[^./]+\.[^./]+)$ ]]; then
		base_name="${BASH_REMATCH[1]}"
		suffix="${BASH_REMATCH[2]}"
	elif [[ "$sys_filename" =~ ^(.+)(\.[^./]+)$ ]]; then
		base_name="${BASH_REMATCH[1]}"
		suffix="${BASH_REMATCH[2]}"
	else
		base_name="$sys_filename"
		suffix=""
	fi
COMMENT_BLOCK

	# 确保扩展名不为null
	echo "${extension:-}"
}

# 生成最终文件名
generate_filename()
{
	local default_name="$1"
	local other_name="$2"
	local file_type="${3:-rootfs}"
	
	local extension=$(get_file_extension "$other_name")
	local base_name="${default_name:-$other_name}"
	
	# 如果名称为空或特殊路径，使用默认生成名称
	if [ -z "$base_name" ] || [ "$base_name" = "/" ] || [ "$base_name" = "." ]; then
		base_name="downloaded_file_$(date +%Y%m%d_%H%M%S)"
	fi
	
	# 确定扩展名
	local final_extension=$(get_file_extension "$base_name")
	[ -z "$final_extension" ] && final_extension="$extension"
	
	# 检查是否已包含标识
	if echo "${base_name,,}" | grep -q "${file_type,,}"; then
		# 如果已包含标识，确保文件名和扩展名正确组合
		if [ -z "$final_extension" ]; then
			echo "$base_name"
		else
			local part_name="${base_name%.*}"
			echo "${part_name}${final_extension}"
		fi
		
		return
	fi
	
	# 构建带标识的文件名
	if [ -z "$final_extension" ]; then
		echo "${base_name}-${file_type}"
	else
		local part_name="${base_name%.*}"
		echo "${part_name}-${file_type}${final_extension}"
	fi
}

###############################################################################
# 下载管理模块

# 下载Linux系统根文件系统包
download_package()
{
	local download_dir="$1"
	local download_data="$2"
	
	local version=$(jq -r '.version' <<< "$download_data")
	local sys_filename=$(jq -r '.sys_filename' <<< "$download_data")
	local local_filename=$(jq -r '.local_filename' <<< "$download_data")
	local download_url=$(jq -r '.download_url' <<< "$download_data")
	
	print_log "INFO" "下载 ${version} 系统根文件系统, 请稍候..." >&2
	
	if [ -z "$download_url" ]; then
		print_log "ERROR" "下载URL参数为空,请检查!" >&2
		return 1
	fi
	
	if [ -z "$downloads_dir" ]; then
		print_log "ERROR" "下载目录参数为空,请检查!" >&2
		return 1
	fi
	
	# 生成文件名
	local filename=$(generate_filename "$local_filename" "$sys_filename")
	
	# 构建输出文件路径
	local output_file="${download_dir}/${filename}"
	
	print_log "INFO" "正在下载: $filename" >&2
	print_log "INFO" "下载URL: $download_url" >&2
	print_log "INFO" "保存文件: $output_file" >&2
	
	local response
	response=$(curl -L --fail \
		--insecure \
		--silent \
		--show-error \
		--connect-timeout 30 \
		--max-time 300 \
		--retry 3 \
		--retry-delay 5 \
		--progress-bar \
		--output "$output_file" \
		--write-out "HTTP_STATUS:%{http_code}\nSIZE_DOWNLOAD:%{size_download}\n" \
		 "$download_url" 2>&1)
		 
	local exit_code=$?
	
	# 提取HTTP状态码和下载大小
	local http_status=$(echo "$response" | awk -F: '/HTTP_STATUS:/ {print $2}' | tr -d '[:space:]')
	local download_size=$(echo "$response" | awk -F: '/SIZE_DOWNLOAD:/ {print $2}' | tr -d '[:space:]')
	
	if [ $exit_code -ne 0 ]; then
		# 显示具体的错误信息
		local error_msg=$(echo "$response" | grep -v -E '^[[:space:]]*[0-9]*#$' | grep -v -E '^(HTTP_STATUS|SIZE_DOWNLOAD)')
		
		if [ -n "$error_msg" ]; then
			print_log "ERROR" "错误详情: $(echo "$error_msg" | head -1)" >&2
		fi
		
		# 清理部分下载文件
		if [ -f "$output_file" ]; then
			rm -f "$output_file"
		fi
		
		return 2
	fi
	
	# 验证下载文件
	if [ ! -f "$output_file" ]; then
		print_log "ERROR" "文件未正确保存,请检查!" >&2
		return 3
	fi
	
	if [ ! -s "$output_file" ]; then
		print_log "ERROR" "下载的文件为空,请检查!" >&2
		rm -f "$output_file"
		return 4
	fi
	
	print_log "INFO" "下载完成: $output_file" >&2
	
	echo "$output_file"
	return 0
}

# 获取Linux系统根文件系统下载URL
get_download_url()
{
	local version="$1"
	local filename="$2"
	local sys_version sys_filename download_url
	
	print_log "INFO" "获取 ${version} 系统的下载URL" >&2

	case $version in
	ubuntu)
		# bionic(18.04) focal(20.04) jammy(22.04) lunar(23.04)
		sys_version=jammy
		sys_filename="ubuntu-${sys_version}-core-cloudimg-${LINUX_ARCH_NAME}-root.tar.gz"
		
		# https://cdimage.ubuntu.com/ubuntu-base/releases/jammy/release/ubuntu-base-22.04-base-arm64.tar.gz
		download_url="https://partner-images.canonical.com/core/${sys_version}/current/${sys_filename}"
		;;
	debian)
		# buster(10) bullseye(11) bookworm(12)
		sys_version=bookworm
		sys_filename="rootfs.tar.xz"
		
		local timestamp_dir="20251029_05:24"
		download_url="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/debian/${sys_version}/${LINUX_ARCH_NAME}/default/${timestamp_dir}/${sys_filename}"
		;;
	kali)
		sys_filename="rootfs.tar.xz"
		
		local timestamp_dir="20240309_17:14"
		download_url="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/kali/current/${LINUX_ARCH_NAME}/default/${timestamp_dir}/${sys_filename}"
		;;
	fedora)
		sys_version=39
		sys_filename="rootfs.tar.xz"
		
		local timestamp_dir="20240309_20:33"
		download_url="https://mirrors.tuna.tsinghua.edu.cn/lxc-images/images/fedora/${sys_version}/${LINUX_ARCH_NAME}/default/${timestamp_dir}/${sys_filename}"
		;;
	*)
		print_log "ERROR" "未知系统类型: ${version}" >&2
		return 1
		;;
	esac
	
	if [ -z "${download_url}" ]; then
		print_log "ERROR" "未找到 ${version} 系统的根文件系统下载地址，请检查!" >&2
		return 1
	fi
	
	# 返回 JSON 格式数据
	cat <<EOF
{
    "version": "$version",
    "sys_version": "$sys_version",
    "sys_filename": "$sys_filename",
    "local_filename": "$filename",
    "download_url": "$download_url"
}
EOF
}

###############################################################################
# 系统管理模块

# 初始化安装Linux系统根文件系统
init_linux()
{
	local version="$1"
	print_log "INFO" "正在安装 ${version} 根文件系统, 请稍候..."

	local version_path="$LINUX_ROOTFS_DIR/$version"
	mkdir -p "$version_path"

	# 检查目标目录是否已存在系统
	if [ -n "$(ls -A $version_path 2>/dev/null)" ]; then
		print_log "WARNING" "${version} 根文件系统已安装，请检查!"
		return 0
	fi
	
	local filename="$version-$LINUX_ARCH_NAME-rootfs"
	local downloads_dir="$LINUX_PACKAGE_DIR"

	local filepath
	filepath=$(find "$downloads_dir" -maxdepth 1 -type f -name "${filename}*.tar*" 2>/dev/null | \
			sort -r | tail -n 1)
	
	if [ -z "$filepath" ]; then
		local result
		result=$(get_download_url "$version" "$filename") || {
			print_log "ERROR" "获取系统 ${version} URL失败，请检查!"
			reutrn 2
		}
		
		filepath=$(download_package "$downloads_dir" "$result") && [ -n "$filepath" ] || {
			print_log "ERROR" "下载 ${version} 根文件系统失败，请检查!"
			return 3
		}
	fi
	
	print_log "INFO" "正在解压 ${version} 根文件系统, 请稍候..."

	if [ -n "$(ls -A $version_path 2>/dev/null)" ]; then
		rm -rf "${version_path}/*"
	fi
	
	if ! proot --link2symlink tar -xf "$filepath" -C "$version_path" --exclude='dev'; then
		print_log "ERROR" "解压 ${version} 根文件系统失败，请检查!"
		return 4
	fi
	
	if ! set_linux_conf "$version" "$version_path"; then
		print_log "ERROR" "配置 ${version} 根文件系统失败，请检查!"
		return 5
	fi
	
	print_log "INFO" "成功安装 ${version} 根文件系统"
	return 0
}

# 卸载已安装的linux系统
destroy_linux()
{
	local version="$1"
	print_log "INFO" "正在卸载 ${version} 根文件系统, 请稍候..."
	
	local version_path="$LINUX_ROOTFS_DIR/$version"
	if [[ ! -d "$version_path" && -z "$(ls -A "$version_path" 2>/dev/null)" ]]; then
		print_log "ERROR" "${version} 系统目录不存在, 请检查!" >&2
		return 1
	fi
	
	# 删除根文件系统目录
	rm -rf "$version_path"
	
	local verStartFile="${SCRIPT_CUR_PATH}/run-${version}.sh"
	[ -f "$verStartFile" ] && rm -rf "$verStartFile"
	
	print_log "INFO" "成功卸载 ${version} 根文件系统!" >&2
	return 0;
}

# 执行Linux系统管理命令
exe_cmd_shell()
{
	local cmd="$1"
	local version="$2"
	
	local ret=0
	
	case ${cmd} in
	install) init_linux "$version"; ret=$? ;;
	uninstall) destroy_linux "$version"; ret=$? ;;
	*) 
		print_log "ERROR""无效命令:$cmd" >&2
		return 1
		;;
	esac

	return $ret
}

###############################################################################
# 菜单管理模块

# 显示和处理命令选择菜单
set_cmd_menu()
{
	local version_name="$1"
	shift
	local cmd_array=("$@")
	
	# 初始校验
	if [ -z "$version_name" ]; then
		print_log "ERROR" "提供的数据错误,请检查!"
		return 1
	fi
	
	while [ 1 ]; do
		clear
		
		# 显示菜单
		show_cmd_menu "$version_name" cmd_array | pr -1 -t
		
		# 获取用户输入
		local index=$(input_user_index)
		
		# 输入验证
		if ! [[ "$index" =~ ^[0-9]+$ ]]; then
			print_log "WARNING" "输入无效：请输入数字!"
			pause "按任意键继续..."
			clear; continue
		fi
		
		# 判断输入值是否有效
		if (( index < 0 || index > ${#cmd_array[@]} )); then
			print_log "WARNING" "请输入正确的命令序号!"
			pause "按任意键继续..."
			clear; continue
		fi
		
		# 退出选择列表
		[ $index -eq 0 ] && { break; }
		
		local item="${cmd_array[$((index-1))]}"
		local cmd="${item#*-}"
		
		# 执行命令功能
		exe_cmd_shell "$cmd" "$version_name"
		local cmd_ret=$?
		
		if [ $cmd_ret -ne 0 ]; then
			pause "press any key to continue..."
		fi
	done
}

# 显示和处理Linux系统选择菜单
set_linux_menu()
{
	local -n name_array=$1
	local -n cmd_array=$2
	
	while [ 1 ]; do
		clear
		
		# 检查空输入
		if [ ${#name_array[@]} -eq 0 ]; then
			print_log "ERROR" "提供的数据列表错误,请检查!"
			return 1
		fi
		
		# 显示linux版本目录
		show_linux_menu name_array | pr -1 -t
		
		# 获取用户输入
		local index=$(input_user_index)
		
		# 输入验证
		if ! [[ "$index" =~ ^[0-9]+$ ]]; then
			print_log "WARNING" "输入无效：请输入数字!"
			pause "Press any key to continue..."
			clear; continue
		fi
		
		# 判断输入值是否有效
		if (( index < 0 || index > ${#name_array[@]} )); then
			print_log "WARNING" "请输入正确的命令序号!"
			pause "按任意键继续..."
			clear; continue
		fi
		
		# 退出选择列表
		[ $index -eq 0 ] && { break; }
		
		# 获取版本名称
		local version_name=${name_array[$((index-1))]}
		
		if [ -z "$version_name" ]; then
			print_log "ERROR" "获取linux版本名称有误, 请检查!"
			clear; continue
		fi
		
		# 设置命令目录
		set_cmd_menu "$version_name" "${cmd_array[@]}"
	done
}

###############################################################################
# 环境初始化模块

# 运行Linux环境管理主菜单
run_linux_env()
{
	# 设置linux交互菜单
	set_linux_menu LINUX_VER_ARRAY LINUX_CMD_ARRAY
}

# 设置Linux环境目录结构
set_linux_env()
{
	# 创建packages目录
	mkdir -p "$LINUX_PACKAGE_DIR"
	
	# 创建binds目录
	mkdir -p "$LINUX_BINDS_DIR"
	
	# 创建rootfs目录
	mkdir -p "$LINUX_ROOTFS_DIR"
}

# 更新和安装必要的依赖包
update_linux_env()
{
	# 定义需要检查的包列表
	local packages=("wget" "proot" "pulseaudio")
	
	for pkg in "${packages[@]}"; do
		if ! dpkg -l | grep -q "^ii  $pkg "; then
			 [ "$pkg" = "proot" ] && pkg install "$pkg" || apt install "$pkg" -y
		fi
	done
}

# 始化Linux环境架构检测
init_linux_env()
{
	arch=$(uname -m)
	case $arch in
		aarch64)  LINUX_ARCH_NAME=arm64 ;;
		arm)      LINUX_ARCH_NAME=armhf ;;
		x86_64|amd64) LINUX_ARCH_NAME=amd64 ;;
		i*86)     LINUX_ARCH_NAME=i386 ;;
		*) print_log "ERROR" "未知架构: $arch"; exit 1 ;;
	esac
}

# Linux环境管理主入口函数
run_app_linux()
{
	# 初始化linux环境
	init_linux_env

	# 更新linux环境
	update_linux_env
	
	# 设置linux环境
	set_linux_env
	
	# 运行linux环境
	run_linux_env
}

# # 启动Linux环境管理应用
run_app_linux
