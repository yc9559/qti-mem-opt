#!/system/bin/sh
# File System Cache Control Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200323

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
VDR_LIB="/vendor/lib64"
DALVIK="/data/dalvik-cache"
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
fscc_add_apk()
{
    if [ "$1" != "" ]; then
        # pm path -> "package:/system/product/priv-app/OPSystemUI/OPSystemUI.apk"
        fscc_add_obj "$(pm path "$1" | head -n 1 | cut -d: -f2)"
    fi
}

# $1:package_name
fscc_add_dex()
{
    local package_apk_path
    local apk_name

    if [ "$1" != "" ]; then
        # pm path -> "package:/system/product/priv-app/OPSystemUI/OPSystemUI.apk"
        package_apk_path="$(pm path "$1" | head -n 1 | cut -d: -f2)"
        # user app: OPSystemUI/OPSystemUI.apk -> OPSystemUI/oat
        fscc_add_obj "${package_apk_path%/*}/oat"

        # remove apk name suffix
        apk_name="${package_apk_path%/*}"
        # remove path prefix
        apk_name="${apk_name##*/}"
        # system app: get dex & vdex
        # /data/dalvik-cache/arm64/system@product@priv-app@OPSystemUI@OPSystemUI.apk@classes.dex
        for dex in $(find "$DALVIK" | grep "@$apk_name@"); do
            fscc_add_obj "$dex"
        done
   fi
}

fscc_add_app_home()
{
    # well, not working on Android 7.1
    local intent_act="android.intent.action.MAIN"
    local intent_cat="android.intent.category.HOME"
    local pkg_name
    # "  packageName=com.microsoft.launcher"
    pkg_name="$(pm resolve-activity -a "$intent_act" -c "$intent_cat" | grep packageName | head -n 1 | cut -d= -f2)"
    # /data/dalvik-cache/arm64/system@priv-app@OPLauncher2@OPLauncher2.apk@classes.dex 16M/31M  53.2%
    # /data/dalvik-cache/arm64/system@priv-app@OPLauncher2@OPLauncher2.apk@classes.vdex 120K/120K  100%
    # /system/priv-app/OPLauncher2/OPLauncher2.apk 14M/30M  46.1%
    fscc_add_apk "$pkg_name"
    fscc_add_dex "$pkg_name"
}

fscc_add_app_ime()
{
    local pkg_name
    # "      packageName=com.baidu.input_yijia"
    pkg_name="$(ime list | grep packageName | head -n 1 | cut -d= -f2)"
    # /data/dalvik-cache/arm/system@app@baidushurufa@baidushurufa.apk@classes.dex 5M/17M  33.1%
    # /data/dalvik-cache/arm/system@app@baidushurufa@baidushurufa.apk@classes.vdex 2M/7M  28.1%
    # /system/app/baidushurufa/baidushurufa.apk 1M/28M  5.71%
    # pin apk file in memory is not valuable
    fscc_add_dex "$pkg_name"
}

# $1:package_name
fscc_add_apex_lib()
{
    fscc_add_obj "$(find /apex -name "$1" | head -n 1)"
}

# after appending fscc_file_list
fscc_start()
{
    # multiple parameters, cannot be warped by ""
    "$MODULE_PATH/$FSCC_REL/$FSCC_NAME" -fdlb0 $fscc_file_list
}

fscc_stop()
{
    killall "$FSCC_NAME"
}

# return:status
fscc_status()
{
    # get the correct value after waiting for fscc loading files
    sleep 2
    if [ "$(ps -A | grep "$FSCC_NAME")" != "" ]; then
        echo "Running. $(cat /proc/meminfo | grep Mlocked | cut -d: -f2 | tr -d ' ') in cache."
    else
        echo "Not running."
    fi
}
