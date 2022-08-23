#!/usr/bin/env bash

# Copyright (C) 2020 Abubakar Yagoub (Blacksuan19)
# Copyright (C) 2022 Prajwal (PrajjuS)

BOT=$BOT_API
CHAT=$CHAT_ID
KERNEL_IMG=$PWD/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR=$CIRRUS_WORKING_DIR/Zipper
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
THREAD=-j$(nproc --all)
DEVICE="vince"
CONFIG="vince_defconfig"

# Setup dependencies
function setup_dependencies() {
	git clone https://github.com/kdrag0n/aarch64-elf-gcc.git $CIRRUS_WORKING_DIR/toolchains/aarch64
	git clone https://github.com/kdrag0n/arm-eabi-gcc.git $CIRRUS_WORKING_DIR/toolchains/aarch32
	git clone https://github.com/PrajjuS/kernel_mugen_vince.git --single-branch -b AnyKernel3 $CIRRUS_WORKING_DIR/Zipper
        pwd
}

# Send text message
function tg_sendmsg() {
	curl -s "https://api.telegram.org/bot$BOT/sendMessage" \
		-d "parse_mode=HTML" \
		-d text="${1}" \
		-d chat_id=$CHAT \
		-d "disable_web_page_preview=true"
}

# Send document
function tg_senddoc() {
	curl -F document=@"${1}" "https://api.telegram.org/bot$BOT/sendDocument" \
		-F "parse_mode=HTML" \
		-F chat_id=$CHAT \
		-F caption="${2}"
}

# Finished without errors
function tg_finished() {
	tg_sendmsg "$(echo "Build Finished in <code>$(($DIFF / 60))</code> minute(s) and <code>$(($DIFF % 60))</code> seconds.")"
}

# Finished with error
function tg_error() {
	tg_senddoc "$CIRRUS_WORKING_DIR/build.log" "Reep build Failed, Check log for more info."
	exit 1
}

# Send build details
function tg_sendbuildinfo() {
	generate_changelog
	tg_sendmsg "<b>New Kernel Build for $DEVICE</b>
    <b>Started on:</b> <code>$KBUILD_BUILD_HOST</code>
    <b>Branch:</b> <code>$BRANCH</code>
    <b>Changelog:</b> <a href='$CHANGE_URL'>Click Here</a>
    <b>Date:</b> <code>$(date +%A\ %B\ %d\ %Y\ %H:%M:%S)</code>"
}

# Upload zip to channel
function tg_pushzip() {
	JIP=$ZIP_DIR/$ZIP
	tg_senddoc "$JIP" "MD5: <code>$(md5sum $ZIP_DIR/$ZIP | awk '{print $1}')</code>"
}

# Build the kernel
function build_kernel() {
	DATE=$(date)
	BUILD_START=$(date +"%s")

	# Cleaup first
	pwd
	make clean && make mrproper

	# Building
	make O=out $CONFIG $THREAD

	# Use GCC
	pwd
	make O=out $THREAD \
		CROSS_COMPILE="$CIRRUS_WORKING_DIR/toolchains/aarch64/bin/aarch64-elf-" \
		CROSS_COMPILE_ARM32="$CIRRUS_WORKING_DIR/toolchains/aarch32/bin/arm-eabi-" |&
		tee -a $CIRRUS_WORKING_DIR/build.log

	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))

	if ! [ -a $KERNEL_IMG ]; then
		tg_error
		exit 1
	fi
}

# Make flashable zip
function make_flashable() {
	cd $ZIP_DIR
	pwd
	ls
	make clean &>/dev/null
	cp $KERNEL_IMG $ZIP_DIR/zImage
	if [ $BRANCH == "yoru" ]; then
		make stable &>/dev/null
	else
		make beta &>/dev/null
	fi
	echo "Flashable zip generated under $ZIP_DIR."
	ZIP=$(ls | grep *.zip)
	tg_pushzip
	cd -
	tg_finished
}

# Generate changelog
function generate_changelog() {
	logs=$(git log --after=$(date +%Y-%m-01) --pretty=format:'- %s')
	export CHANGE_URL=$(echo "$logs" | curl -F 'clbin=<-' https://clbin.com)
}

# Export
export TZ="Asia/Kolkata"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="PrajjuS"
export KBUILD_BUILD_HOST="Kurayami"
export LINUX_VERSION=$(awk '/SUBLEVEL/ {print $3}' Makefile | head -1 | sed 's/[^0-9]*//g')

# Setup dependencies
setup_dependencies

# Send start message to telegram
tg_sendbuildinfo

# Build start
build_kernel

# Make zip
make_flashable
