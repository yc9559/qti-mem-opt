#!/system/bin/sh
# File System Cache Control Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200104

# include PATH
BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# PATHs
###############################

FSCC_REL="$BIN_DIR"
FSCC_NAME="fscache-ctrl"

###############################
# Abbreviations
###############################

SYS_FRAME="/system/framework"
SYS_LIB="/system/lib64"
DALVIK="/data/dalvik-cache/arm64"
APEX1="/apex/com.android.art/javalib"
APEX2="/apex/com.android.runtime/javalib"

###############################
# FSCC tool functions
###############################

fscc_file_list=""

# $1:apk_path $return:oat_path
fscc_path_apk_to_oat()
{
    # OPSystemUI/OPSystemUI.apk -> OPSystemUI/oat
    echo "${1%/*}/oat"
}

# $1:file/dir
fscc_list_append()
{
    fscc_file_list="$fscc_file_list $1"
}

# $1:file/dir
fscc_add_obj()
{
    # whether file or dir exists
    if [ -e "$1" ]; then
        fscc_list_append "$1"
    fi
}

# $1:package_name
fscc_add_apk_usr()
{
    local package_apk_path
    # pm path -> "package:/system/product/priv-app/OPSystemUI/OPSystemUI.apk"
    package_apk_path="$(pm path "$1" | cut -d: -f2)"
    fscc_add_obj "$(fscc_path_apk_to_oat "$package_apk_path")"
}

# $1:package_name
fscc_add_apk_sys()
{
    local package_apk_path
    local apk_name
    # pm path -> "package:/system/product/priv-app/OPSystemUI/OPSystemUI.apk"
    package_apk_path="$(pm path "$1" | cut -d: -f2)"
    # remove apk name suffix
    apk_name="${package_apk_path%/*}"
    # remove path prefix
    apk_name="${apk_name##*/}"
    # get dex & vdex
    for dex in $(ls "$DALVIK" | grep "$apk_name"); do
        fscc_add_obj "$DALVIK/$dex"
    done
}

fscc_add_apk_home()
{
    local intent_act="android.intent.action.MAIN"
    local intent_cat="android.intent.category.HOME"
    local ret
    # "    sourceDir=/data/app/net.oneplus.launcher-8ZzsYNYdJ8-6TM74OstKvg==/base.apk"
    ret="$(pm resolve-activity -a "$intent_act" -c "$intent_cat" | grep sourceDir | head -n 1)"
    # remove sourceDir prefix
    fscc_add_obj "$(fscc_path_apk_to_oat "${ret#*=}")"
}

# $1:package_name
fscc_add_apex_lib()
{
    fscc_add_obj "$(find /apex -name "$1" | head -n 1)"
}

# after appending fscc_file_list
fscc_start_svc()
{
    # multiple parameters, cannot be warped by ""
    "$MODULE_PATH/$FSCC_REL/$FSCC_NAME" -fdlb0 $fscc_file_list
}

fscc_stop_svc()
{
    killall "$FSCC_NAME"
}
