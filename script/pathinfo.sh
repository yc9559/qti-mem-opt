#!/system/bin/sh
# Module Path Header
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200216

MODULE_NAME="qti-mem-opt"
MODULE_PATH="/data/adb/modules/$MODULE_NAME"
SCRIPT_DIR="./script"
BIN_DIR="./bin"
PANEL_FILE="/sdcard/Android/panel_qti_mem.txt"

# fix compatibility issues, do not use magisk busybox
PATH="/sbin:/system/sbin:/product/bin:/apex/com.android.runtime/bin:/system/bin:/system/xbin:/odm/bin:/vendor/bin:/vendor/xbin"
