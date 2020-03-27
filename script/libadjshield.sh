#!/system/bin/sh
# AdjSheild Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200316

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
    # clear log file
    true > "$adjshield_log"
    # check interval: 120 seconds - Deprecated, use event driven instead
    "$MODULE_PATH/$ADJSHIELD_REL/$ADJSHIELD_NAME" -o "$adjshield_log" -c "$adjshield_cfg" &
}

adjshield_stop()
{
    killall "$ADJSHIELD_NAME"
}

# return:status
adjshield_status()
{
    local err
    if [ "$(ps -A | grep "$ADJSHIELD_NAME")" != "" ]; then
        echo "Running. See $adjshield_log for details."
    else
        # "Error: Log file not found"
        err="$(cat "$adjshield_log" | grep Error | head -n 1 | cut -d: -f2)"
        if [ "$err" != "" ]; then
            echo "Not running.$err."
        else
            echo "Not running. Unknown reason."
        fi
    fi
}
