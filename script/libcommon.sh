#!/system/bin/sh
# Basic Tool Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200215

BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# Basic tool functions
###############################

# $1:value $2:file path
lock_val() 
{
    if [ -f "$2" ]; then
        chmod 0666 "$2"
        echo "$1" > "$2"
        chmod 0444 "$2"
    fi
}

# $1:value $2:file path
mutate() 
{
    if [ -f "$2" ]; then
        chmod 0666 "$2"
        echo "$1" > "$2"
    fi
}

###############################
# Config File Operator
###############################

# $1:key $return:value(string)
read_cfg_value()
{
    local value=""
    if [ -f "$PANEL_FILE" ]; then
        value="$(grep "^$1=" "$PANEL_FILE" | head -n 1 | tr -d ' ' | cut -d= -f2)"
    fi
    echo "$value"
}

# $1:content
write_panel()
{
    echo "$1" >> "$PANEL_FILE"
}

clear_panel()
{
    true > "$PANEL_FILE"
}

wait_until_login()
{
    # whether in lock screen, tested on Android 7.1 & 10.0
    # in case of other magisk module remounting /data as RW
    while [ "$(dumpsys window policy | grep mInputRestricted=true)" != "" ]; do
        sleep 2
    done
    # we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
    while [ ! -f "$PANEL_FILE" ]; do
        touch "$PANEL_FILE"
        sleep 2
    done
}
