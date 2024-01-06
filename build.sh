#!/bin/bash
# =========================================
#         _____              _      
#        |  ___| __ ___  ___| |__   
#        | |_ | '__/ _ \/ __| '_ \  
#        |  _|| | |  __/\__ \ | | | 
#        |_|  |_|  \___||___/_| |_| 
#                              
# =========================================
#  
#  Minty - The kernel build script for Mint
#  The Fresh Project
#  Copyright (C) 2019-2021 TenSeventy7
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/>.
#  
#  =========================
#

# Utility directories
ORIGIN_DIR=$(pwd)
CURRENT_BUILD_USER=$(whoami)

# Toolchain options
BUILD_PREF_COMPILER='clang'
BUILD_PREF_COMPILER_VERSION='proton'

# Local toolchain directory
TOOLCHAIN=$HOME/toolchains/exynos9610_toolchains_fresh

# External toolchain directory
TOOLCHAIN_EXT=$(pwd)/toolchain

DEVICE_DB_DIR="${ORIGIN_DIR}/Documentation/device-db"

export ARCH=arm64
export SUBARCH=arm64
export ANDROID_MAJOR_VERSION=r
export PLATFORM_VERSION=11.0.0
export $ARCH

script_echo() {
	echo "  $1"
}

exit_script() {
	kill -INT $$
}

download_toolchain() {
	git clone https://gitlab.com/TenSeventy7/exynos9610_toolchains_fresh.git ${TOOLCHAIN_EXT} --single-branch -b ${BUILD_PREF_COMPILER_VERSION} --depth 1 2>&1 | sed 's/^/     /'
	verify_toolchain
}

verify_toolchain() {
	sleep 2
	script_echo " "

	if [[ -d "${TOOLCHAIN}" ]]; then
		script_echo "I: Toolchain found at default location"
		export PATH="${TOOLCHAIN}/bin:$PATH"
		export LD_LIBRARY_PATH="${TOOLCHAIN}/lib:$LD_LIBRARY_PATH"
	elif [[ -d "${TOOLCHAIN_EXT}" ]]; then

		script_echo "I: Toolchain found at repository root"

		cd ${TOOLCHAIN_EXT}
		git pull
		cd ${ORIGIN_DIR}

		export PATH="${TOOLCHAIN_EXT}/bin:$PATH"
		export LD_LIBRARY_PATH="${TOOLCHAIN_EXT}/lib:$LD_LIBRARY_PATH"

		if [[ ${BUILD_KERNEL_CI} == 'true' ]]; then
			if [[ ${BUILD_PREF_COMPILER_VERSION} == 'proton' ]]; then
				sudo mkdir -p /root/build/install/aarch64-linux-gnu
				sudo cp -r "${TOOLCHAIN_EXT}/lib" /root/build/install/aarch64-linux-gnu/

				sudo chown ${CURRENT_BUILD_USER} /root
				sudo chown ${CURRENT_BUILD_USER} /root/build
				sudo chown ${CURRENT_BUILD_USER} /root/build/install
				sudo chown ${CURRENT_BUILD_USER} /root/build/install/aarch64-linux-gnu
				sudo chown ${CURRENT_BUILD_USER} /root/build/install/aarch64-linux-gnu/lib
			fi
		fi
	else
		script_echo "I: Toolchain not found at default location or repository root"
		script_echo "   Downloading recommended toolchain at ${TOOLCHAIN_EXT}..."
		download_toolchain
	fi

	# Proton Clang 13
	# export CLANG_TRIPLE=aarch64-linux-gnu-
	export CROSS_COMPILE=aarch64-linux-gnu-
	export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
	export CC=${BUILD_PREF_COMPILER}
}

update_magisk() {
	script_echo " "
	script_echo "I: Updating Magisk..."

	if [[ "x${BUILD_KERNEL_MAGISK_BRANCH}" == "xcanary" ]]; then
		MAGISK_BRANCH="canary"
	elif [[ "x${BUILD_KERNEL_MAGISK_BRANCH}" == "xlocal" ]]; then
		MAGISK_BRANCH="local"
	else
		MAGISK_BRANCH=""
	fi

	${ORIGIN_DIR}/usr/magisk/update_magisk.sh ${MAGISK_BRANCH} 2>&1 | sed 's/^/     /'
}

fill_magisk_config() {
	MAGISK_USR_DIR="${ORIGIN_DIR}/usr/magisk/"

	script_echo " "
	script_echo "I: Configuring Magisk..."

	if [[ -f "$MAGISK_USR_DIR/backup_magisk" ]]; then
		rm "$MAGISK_USR_DIR/backup_magisk"
	fi

	echo "KEEPVERITY=true" >> "$MAGISK_USR_DIR/backup_magisk"
	echo "KEEPFORCEENCRYPT=true" >> "$MAGISK_USR_DIR/backup_magisk"
	echo "RECOVERYMODE=false" >> "$MAGISK_USR_DIR/backup_magisk"
	echo "PREINITDEVICE=userdata" >> "$MAGISK_USR_DIR/backup_magisk"

	# Create a unique random seed per-build
	script_echo "   - Generating a unique random seed for this build..."
	RANDOMSEED=$(tr -dc 'a-f0-9' < /dev/urandom | head -c 16)
	echo "RANDOMSEED=0x$RANDOMSEED" >> "$MAGISK_USR_DIR/backup_magisk"
}

show_usage() {
	script_echo "Usage: ./build.sh -d|--device <device> -v|--variant <variant> [main options]"
	script_echo " "
	script_echo "Main options:"
	script_echo "-d, --device <device>     Set build device to build the kernel for. Required."
	script_echo "-a, --android <version>   Set Android version to build the kernel for. (Default: 11)"
	script_echo "-v, --variant <variant>   Set build variant to build the kernel for. Required."
	script_echo " "
	script_echo "-n, --no-clean            Do not clean and update Magisk before build."
	script_echo "-m, --magisk [canary]     Pre-root the kernel with Magisk. Optional flag to use canary builds."
	script_echo "                          Not available for 'recovery' variant."
	script_echo "-p, --permissive          Build kernel with SELinux fully permissive. NOT RECOMMENDED!"
	script_echo " "
	script_echo "-h, --help                Show this message."
	script_echo " "
	script_echo "Variant options:"
	script_echo "    oneui: Build Mint for use with stock and One UI-based ROMs."
	script_echo "     aosp: Build Mint for use with AOSP and AOSP-based Generic System Images (GSIs)."
	script_echo " recovery: Build Mint for use with recovery device trees. Doesn't build a ZIP."
	script_echo " "
	script_echo "Supported devices:"
	script_echo "  a50 (Samsung Galaxy A50)"
	script_echo " a50s (Samsung Galaxy A50s)"
	exit_script
}

merge_config() {
	if [[ ! -e "${SUB_CONFIGS_DIR}/mint_${1}.config" ]]; then
		script_echo "E: Subconfig not found on config DB!"
		script_echo "   ${SUB_CONFIGS_DIR}/mint_${1}.config"
		script_echo "   Make sure it is in the proper directory."
		script_echo " "
		exit_script
	else
		echo "$(cat "${SUB_CONFIGS_DIR}/mint_${1}.config")" >> "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_TMP_CONFIG}"
	fi
}

set_android_version() {
	echo "CONFIG_MINT_PLATFORM_VERSION=${BUILD_ANDROID_PLATFORM}" >> "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_TMP_CONFIG}"
}

get_devicedb_info() {
	if [[ ! -e "${DEVICE_DB_DIR}/${BUILD_DEVICE_NAME}.sh" ]]; then
		script_echo "E: Device info not found from device DB!"
		script_echo "   ${DEVICE_DB_DIR}/${BUILD_DEVICE_NAME}.sh"
		script_echo "   Make sure it is in the proper directory."
		script_echo " "
		exit_script
	else
		source "${DEVICE_DB_DIR}/${BUILD_DEVICE_NAME}.sh"
	fi
}

check_defconfig() {
	if [[ ! -e "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_CONFIG}" ]]; then
		script_echo "E: Defconfig not found!"
		script_echo "   ${BUILD_CONFIG_DIR}/${BUILD_DEVICE_CONFIG}"
		script_echo "   Make sure it is in the proper directory."
		script_echo ""
		exit_script
	else
		echo "$(cat "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_CONFIG}")" > "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_TMP_CONFIG}"
	fi
}

build_kernel() {
	sleep 3
	script_echo " "

	if [[ ${BUILD_PREF_COMPILER_VERSION} == 'rui' ]]; then
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip ${BUILD_DEVICE_TMP_CONFIG} LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip -j$(nproc --all) LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
	elif [[ ${BUILD_PREF_COMPILER_VERSION} == 'proton' ]]; then
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip ${BUILD_DEVICE_TMP_CONFIG} LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip -j$(nproc --all) LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
	elif [[ ${BUILD_PREF_COMPILER_VERSION} == 'google_snowcone' ]]; then
		# google_snowcone (aka Clang 12 for Android) uses an additional 'LLVM=1' flag
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LLVM=1 AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip ${BUILD_DEVICE_TMP_CONFIG} LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LLVM=1 AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip -j$(nproc --all) LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
	elif [[ ${BUILD_PREF_COMPILER} == 'clang' ]]; then
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LLVM=1 ${BUILD_DEVICE_TMP_CONFIG} LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
		make -C $(pwd) CC=${BUILD_PREF_COMPILER} LLVM=1 -j$(nproc --all) LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
	else
		make -C $(pwd) ${BUILD_DEVICE_TMP_CONFIG} LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
		make -C $(pwd) -j$(nproc --all) LOCALVERSION="${LOCALVERSION}" 2>&1 | sed 's/^/     /'
	fi
}

build_image() {
	if [[ -e "$(pwd)/arch/arm64/boot/Image" ]]; then
		script_echo " "
		script_echo "I: Building kernel image..."
		script_echo "    Header/Page size: ${DEVICE_KERNEL_HEADER}/${DEVICE_KERNEL_PAGESIZE}"
		script_echo "      Board and base: ${DEVICE_KERNEL_BOARD}/${DEVICE_KERNEL_BASE}"
		script_echo " "
		script_echo "     Android Version: ${PLATFORM_VERSION}"
		script_echo "Security patch level: ${PLATFORM_PATCH_LEVEL}"

		${ORIGIN_DIR}/tools/make/bin/mkbootimg \
				  --kernel $(pwd)/arch/arm64/boot/Image \
				  --cmdline "androidboot.selinux=permissive androidboot.selinux=permissive loop.max_part=7" --board "$DEVICE_KERNEL_BOARD" \
				  --base $DEVICE_KERNEL_BASE --pagesize $DEVICE_KERNEL_PAGESIZE \
				  --kernel_offset $DEVICE_KERNEL_OFFSET --ramdisk_offset $DEVICE_RAMDISK_OFFSET \
				  --second_offset $DEVICE_SECOND_OFFSET --tags_offset $DEVICE_TAGS_OFFSET \
				  --os_version "$PLATFORM_VERSION" --os_patch_level "$PLATFORM_PATCH_LEVEL" \
				  --header_version $DEVICE_KERNEL_HEADER --hashtype $DEVICE_DTB_HASHTYPE \
				  -o ${ORIGIN_DIR}/tools/make/boot.img

		if [[ ! -f ${ORIGIN_DIR}/tools/make/boot.img ]]; then
			script_echo " "
			script_echo "E: Kernel image not built successfully!"
			script_echo "   Errors can be fround from above."
			sleep 3
			exit_script
		fi

	else
		script_echo "E: Image not built!"
		script_echo "   Errors can be fround from above."
		sleep 3
		exit_script
	fi
}

export_image() {
	if [[ -e "$(pwd)/arch/arm64/boot/Image" ]]; then
		script_echo " "
		script_echo "I: Exporting kernel image..."
		mv -f $(pwd)/arch/arm64/boot/Image ${BUILD_KERNEL_OUTPUT}
	else
		script_echo "E: Image not built!"
		script_echo "   Errors can be fround from above."
		sleep 3
		exit_script
	fi
}

build_dtb() {
	$(pwd)/tools/dtb/mkdtboimg cfg_create \
			--dtb-dir=$(pwd) \
			$(pwd)/tools/dtb/dtb.img \
			"$(pwd)/arch/arm64/boot/config/exynos9610-${BUILD_DEVICE_NAME}.dtb.config"
}

build_dtbo() {
	$(pwd)/tools/dtb/mkdtboimg cfg_create \
			--dtb-dir=$(pwd) \
			$(pwd)/tools/dtb/dtbo.img \
			"$(pwd)/arch/arm64/boot/config/exynos9610-${BUILD_DEVICE_NAME}.dtbo.config"
}

set_file_name() {
ZIP_ONEUI_VERSION=""

if [[ ${BUILD_KERNEL_CODE} == "oneui" ]]; then
	ZIP_ONEUI_VERSION="$((${BUILD_ANDROID_PLATFORM} - 8))"
fi

if [[ ! -z ${BUILD_KERNEL_BRANCH} ]]; then

	if [[ ${BUILD_KERNEL_BRANCH} == *"android-"* ]]; then
		BUILD_KERNEL_BRANCH='mainline'
	#!/bin/bash

	# FILEPATH: /home/mr/Downloads/build.sh

	# Function to display usage instructions
	show_usage() {
		echo "Usage: build.sh [OPTIONS]"
		echo "Options:"
		echo "  -d, --device DEVICE_NAME     Specify the device name"
		echo "  -a, --android ANDROID_VER    Specify the Android version"
		echo "  -v, --variant VARIANT        Specify the kernel variant"
		echo "  -c, --automated              Enable automated build"
		echo "  -n, --no-clean               Skip cleaning before build"
		echo "  -m, --magisk [BRANCH]        Enable Magisk support"
		echo "  -p, --permissive             Build kernel in permissive mode"
		echo "  -h, --help                   Show this help message"
		exit 1
	}

	# Function to echo messages with indentation
	script_echo() {
		echo "     $1"
	}

	# Function to set the file name based on build options
	set_file_name() {
		if [[ ${BUILD_KERNEL_BRANCH} == "mainline" ]]; then
			FILE_OUTPUT="Mint-${KERNEL_BUILD_VERSION}.A${BUILD_ANDROID_PLATFORM}_${FILE_KERNEL_CODE}${ZIP_ONEUI_VERSION}"
		else
			FILE_OUTPUT="MintBeta-${GITHUB_RUN_NUMBER}.A${BUILD_ANDROID_PLATFORM}.${FILE_KERNEL_CODE}${ZIP_ONEUI_VERSION}-${FILE_NAME_SELINUX}"
		fi

		if [[ ${BUILD_KERNEL_MAGISK} == 'true' ]]; then
			FILE_OUTPUT+="_${BUILD_DEVICE_NAME^}.zip"
		else
			FILE_OUTPUT+="-NoRoot_${BUILD_DEVICE_NAME^}.zip"
		fi
	}

	# Function to verify the toolchain
	verify_toolchain() {
		# Verify toolchain here
		script_echo "Verifying toolchain..."
		# Verification code goes here
	}

	# Function to check if the defconfig file exists
	check_defconfig() {
		if [[ ! -e "${BUILD_CONFIG_DIR}/exynos9610-${BUILD_DEVICE_NAME}_default_defconfig" ]]; then
			script_echo "E: Defconfig file not found for device: ${BUILD_DEVICE_NAME}"
			script_echo " "
			show_usage
		fi
	}

	# Function to get device information from the device database
	get_devicedb_info() {
		if [[ ! -e "${DEVICE_DB_DIR}/kernel_info.sh" ]]; then
			script_echo "E: Kernel info not found from DB!"
			script_echo "   ${DEVICE_DB_DIR}/kernel_info.sh"
			script_echo "   Make sure it is in the proper directory."
			script_echo " "
			exit 1
		else
			source "${DEVICE_DB_DIR}/kernel_info.sh"
		fi
	}

	# Function to merge config files
	merge_config() {
		config_file="${SUB_CONFIGS_DIR}/$1.config"
		if [[ -e "${config_file}" ]]; then
			script_echo "Merging config: ${config_file}"
			# Merge config code goes here
		fi
	}

	# Function to update Magisk
	update_magisk() {
		script_echo "Updating Magisk..."
		# Update Magisk code goes here
	}

	# Function to fill Magisk config
	fill_magisk_config() {
		script_echo "Filling Magisk config..."
		# Fill Magisk config code goes here
	}

	# Function to set the Android version
	set_android_version() {
		if [[ -z ${BUILD_ANDROID_PLATFORM} ]]; then
			BUILD_ANDROID_PLATFORM=11
		fi
	}

	# Function to build the kernel
	build_kernel() {
		script_echo "Building kernel..."
		# Build kernel code goes here
	}

	# Function to export the image
	export_image() {
		script_echo "Exporting image..."
		# Export image code goes here
	}

	# Function to build the image and package
	build_image_and_package() {
		script_echo "Building image and package..."
		# Build image and package code goes here
	}

	# Function to display build completion message
	build_complete() {
		TIME_NOW=$(date +%s)
		BUILD_TIME=$((TIME_NOW-BUILD_DATE))
		BUILD_TIME_STR=$(printf '%02dh:%02dm:%02ds\n' $((BUILD_TIME/3600)) $((BUILD_TIME%3600/60)) $((BUILD_TIME%60)))

		script_echo " "
		script_echo "I: Kernel build completed!"
		script_echo "   Kernel build took ${BUILD_TIME_STR}"
		script_echo "   File can be found at:"
		script_echo "   ${BUILD_KERNEL_OUTPUT}"
		rm -f "${BUILD_CONFIG_DIR}/${BUILD_DEVICE_TMP_CONFIG}"
		sleep 7
	}

	# Main script

	# Display header
	script_echo ' '
	script_echo '==============================================='
	script_echo "                       _       _               "
	script_echo "                 /\/\ (_)_ __ | |_             "
	script_echo "                /    \| | '_ \| __|            "
	script_echo "               / /\/\ \ | | | | |_             "
	script_echo "               \/    \/_|_| |_|\__|            "
	script_echo "                                               "
	script_echo '==============================================='
	script_echo '           Minty - Kernel Build Script         '
	script_echo '            Part of The Fresh Project          '
	script_echo '       by TenSeventy7 - Licensed in GPLv3      '
	script_echo '                                               '
	script_echo '       Originally built for Project ShadowX    '
	script_echo '==============================================='
	script_echo ' '

	# Set default values
	BUILD_KERNEL_CI='false'
	BUILD_KERNEL_DIRTY='false'
	BUILD_KERNEL_MAGISK='false'
	BUILD_KERNEL_PERMISSIVE='false'
	SCRIPT_SHOW_HELP='false'

	# Parse command line options
	while [[ $# -gt 0 ]]; do
		key="$1"

		case $key in
			-d|--device)
				BUILD_DEVICE_NAME=`echo ${2} | tr 'A-Z' 'a-z'`
				shift; shift # past value
				;;
			-a|--android)
				BUILD_ANDROID_PLATFORM=`echo ${2} | tr 'A-Z' 'a-z'`

				if [[ ! ${BUILD_ANDROID_PLATFORM} =~ ^[0-9]+$ ]]; then
					script_echo "E: Wrong Android version syntax!"
					script_echo " "
					show_usage
				fi

				shift; shift # past value
				;;
			-v|--variant)
				BUILD_KERNEL_CODE=`echo ${2} | tr 'A-Z' 'a-z'`
				shift; shift # past value
				;;
			-c|--automated)
				BUILD_KERNEL_CI='true'
				shift
				;;
			-n|--no-clean)
				BUILD_KERNEL_DIRTY='true'
				shift
				;;
			-m|--magisk)
				BUILD_KERNEL_MAGISK='true'
				BUILD_KERNEL_MAGISK_BRANCH=`echo ${2} | tr 'A-Z' 'a-z'`

				# Shift twice if asking for canary or local builds. Otherwise, shift only once.
				if [[ "x${BUILD_KERNEL_MAGISK_BRANCH}" == "xcanary" ]]; then
					shift
				elif [[ "x${BUILD_KERNEL_MAGISK_BRANCH}" == "xlocal" ]]; then
					shift
				fi

				shift # past value
				;;
			-p|--permissive)
				BUILD_KERNEL_PERMISSIVE='true'
				shift
				;;
			-h|--help)
				SCRIPT_SHOW_HELP='true'
				shift
				;;
			--default)
				DEFAULT=YES
				shift # past value
				;;
			*)    # unknown option
				POSITIONAL+=("$1") # save it in an array for later
				shift # past argument
				;;
		esac
	done

	set -- "${POSITIONAL[@]}" # restore positional parameters

	# Show help if requested
	if [[ ${SCRIPT_SHOW_HELP} == 'true' ]]; then
		show_usage
	fi

	# Set build variables
	VERSION=$(grep -m 1 VERSION "$(pwd)/Makefile" | sed 's/^.*= //g')
	PATCHLEVEL=$(grep -m 1 PATCHLEVEL "$(pwd)/Makefile" | sed 's/^.*= //g')
	SUBLEVEL=$(grep -m 1 SUBLEVEL "$(pwd)/Makefile" | sed 's/^.*= //g')

	BUILD_KERNEL_BRANCH=${GITHUB_REF##*/}
	BUILD_DATE=$(date +%s)
	BUILD_CONFIG_DIR=$(pwd)/arch/arm64/configs
	SUB_CONFIGS_DIR=${ORIGIN_DIR}/kernel/configs
	BUILD_OUTPUT_DIR=$(pwd)/output

	# Retrofit: 'fresh' variant now points to 'oneui'
	if [[ ${BUILD_KERNEL_CODE} == "fresh" ]]; then
		BUILD_KERNEL_CODE='oneui'
	fi

	# Check if variant is specified
	if [[ -z ${BUILD_KERNEL_CODE} ]]; then
		script_echo "E: No variant selected!"
		script_echo " "
		show_usage
	else
		if [[ ! -e "${SUB_CONFIGS_DIR}/mint_variant_${BUILD_KERNEL_CODE}.config" ]]; then
			script_echo "E: Variant is not valid!"
			script_echo " "
			show_usage
		fi
	fi

	# Set default values if not specified
	if [[ -z ${BUILD_KERNEL_MAGISK} ]]; then
		BUILD_KERNEL_MAGISK='false'
	fi

	# Set device-specific variables
	BUILD_DEVICE_CONFIG="exynos9610-${BUILD_DEVICE_NAME}_core_defconfig"
	BUILD_DEVICE_TMP_CONFIG="tmp_exynos9610-${BUILD_DEVICE_NAME}_${BUILD_KERNEL_CODE}_defconfig"
	export KCONFIG_BUILTINCONFIG="${BUILD_CONFIG_DIR}/exynos9610-${BUILD_DEVICE_NAME}_default_defconfig"
	BUILD_DEVICE_OUTPUT="${BUILD_OUTPUT_DIR}/${BUILD_DEVICE_NAME}"

	# Check if defconfig file exists
	check_defconfig

	# Get device information from the device database
	get_devicedb_info

	# Set Android version
	set_android_version

	# Verify toolchain
	verify_toolchain

	# Clean build if not specified
	if [[ ${BUILD_KERNEL_DIRTY} == 'false' ]]; then
		script_echo " "
		script_echo "I: Clean build!"
		make CC=${BUILD_PREF_COMPILER} clean 2>&1 | sed 's/^/     /'
		make CC=${BUILD_PREF_COMPILER} mrproper 2>&1 | sed 's/^/     /'
	else
		script_echo " "
		script_echo "I: Dirty build!"
	fi

	# Merge config files
	merge_config partial-deknox-${BUILD_ANDROID_PLATFORM}
	merge_config mali-${BUILD_ANDROID_PLATFORM}
	merge_config variant_${BUILD_KERNEL_CODE}

	# Set permissive mode if specified
	if [[ ${BUILD_KERNEL_PERMISSIVE} == 'true' ]]; then
		script_echo "WARNING! You're building this kernel in permissive mode!"
		script_echo "         This is insecure and may make your device vulnerable"
		script_echo "         This kernel has NO RESPONSIBILITY on whatever happens next."
		merge_config selinux-permissive
	fi

	# Enable Magisk support if specified
	if [[ ${BUILD_KERNEL_MAGISK} == 'true' ]]; then
		if [[ ${BUILD_KERNEL_CODE} == 'recovery' ]]; then
			script_echo " "
			script_echo "I: Recovery variant selected."
			script_echo "   Magisk is not available to allow recovery to boot."
			script_echo "   Patch the image using Magisk manually to get root."
			merge_config non-root
			sleep 3
		else
			merge_config pre-root

			if [[ ${BUILD_KERNEL_DIRTY} == 'false' ]]; then
				update_magisk
			fi

			fill_magisk_config
		fi
	else
		merge_config non-root
	fi

	# Use no-product Exynos DTB when building AOSP
	if [[ ${BUILD_KERNEL_CODE} == "aosp" ]]; then
		script_echo "I: Copying no-product DTB file for use with AOSP ROMs."
		cp -f $(pwd)/arch/arm64/boot/dts/exynos/aosp/exynos9610.dts $(pwd)/arch/arm64/boot/dts/exynos/
	fi

	# Build the kernel
	build_kernel

	# Export the image or build the image and package
	if [[ ${BUILD_KERNEL_CODE} == 'recovery' ]]; then
		export_image
	else
		build_image_and_package
	fi

	# Display build completion message
	build_complete
