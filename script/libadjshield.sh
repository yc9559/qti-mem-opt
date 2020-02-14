#!/system/bin/sh
# AdjSheild Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200214

# include PATH
BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# PATHs
###############################

ADJSHIELD_REL="$BIN_DIR"
ADJSHIELD_NAME="adjshield"

###############################
# AdjShield tool functions
###############################

adjshield_cfg="/sdcard/Android/panel_adjshield.txt"
adjshield_log="/sdcard/Android/log_adjshield.txt"

# $1:str
adjshield_write_cfg()
{
    echo "$1" >> "$adjshield_cfg"
}

adjshield_create_default_cfg()
{
    true > "$adjshield_cfg"
    adjshield_write_cfg "# AdjShield Config File"
    adjshield_write_cfg "# Prevent given processes from being killed by Android LMK by protecting oom_score_adj"
    adjshield_write_cfg "# List all the package names of your Apps which you want to keep alive."
    adjshield_write_cfg "com.tencent.mm"
    adjshield_write_cfg "com.tencent.mobileqq"
    adjshield_write_cfg "com.coolapk.market"
}

adjshield_start()
{
    # "u:object_r:adb_data_file:s0" != "u:r:untrusted_app:s0:c512,c768"
    setenforce 0
    # check interval: 180 seconds
    "$MODULE_PATH/$ADJSHIELD_REL/$ADJSHIELD_NAME" -t 180 -o "$adjshield_log" -c "$adjshield_cfg" &
}

adjshield_stop()
{
    killall "$ADJSHIELD_NAME"
}
