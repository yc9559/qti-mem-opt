#!/system/bin/sh
# Linux memory tunning Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200317

# include PATH
BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# Abbreviations
###############################

VM="/proc/sys/vm"
LMK="/sys/module/lowmemorykiller/parameters"
ZRAM="/sys/block/zram0"
ZRAM_DEV="/dev/block/zram0"
ZRAM_CTL="/sys/class/zram-control"

###############################
# ZRAM tool functions
###############################

# return: true/false
mem_has_zram_mod()
{
    if [ -b "$ZRAM_DEV" ] || [ -d "$ZRAM_CTL" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# $1:binary $2:arg
mem_fallback()
{
    "/vendor/bin/$1" "$2"
    [ "$?" == "0" ] && return
    "/system/bin/$1" "$2"
    [ "$?" == "0" ] && return
    "$1" "$2"
}

mem_stop_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    [ "$(mem_has_zram_mod)" == "false" ] && return

    # swapoff all devices
    # swap devices may be not shown in blkid
    for dev in $(cat /proc/swaps | grep "^/" | awk '{print $1}'); do
        mem_fallback swapoff "$dev"
    done
}

# $1:disksize $2:mem_lim $3:alg
mem_start_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    [ "$(mem_has_zram_mod)" == "false" ] && return

    mem_stop_zram
    mutate "1" $ZRAM/reset
    lock_val "$3" $ZRAM/comp_algorithm
    lock_val "$1" $ZRAM/disksize
    lock_val "$2" $ZRAM/mem_limit
    # holy crap, mkswap in busybox(32bit) cannot mkswap >= 4GB
    mem_fallback mkswap $ZRAM_DEV
    # swapon -p not supported by BusyBox v1.31.1-osm0sis
    # swapon $ZRAM_DEV -p 23333
    mem_fallback swapon $ZRAM_DEV
    # zram doesn't need much read ahead(random read)
    lock_val "0" $ZRAM/queue/read_ahead_kb
    lock_val "0" $VM/page-cluster
}

mem_close_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    [ "$(mem_has_zram_mod)" == "false" ] && return

    mem_stop_zram
    for i in 0 1 2 3 4; do
        echo $i > $ZRAM_CTL/hot_remove
    done
}

mem_open_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    [ "$(mem_has_zram_mod)" == "false" ] && return

    local id
    id="$(cat $ZRAM_CTL/hot_add)"
    ZRAM="/sys/block/zram$id"
    ZRAM_DEV="/dev/block/zram$id"
}

mem_get_available_comp_alg()
{
    if [ "$(mem_has_zram_mod)" == "false" ]; then
        echo "unsupported"
        return
    fi

    # Linux 3.x may not have comp_algorithm tunable
    if [ -f "$ZRAM/comp_algorithm" ]; then
        # "lz4 [lzo] deflate", remove '[' and ']'
        echo "$(cat $ZRAM/comp_algorithm | sed "s/\[//g" | sed "s/\]//g")"
    else
        # lzo is the default comp_algorithm since Linux 2.6
        echo "lzo"
    fi
}

mem_get_cur_comp_alg()
{
    if [ "$(mem_has_zram_mod)" == "false" ]; then
        echo "unsupported"
        return
    fi

    local str
    # Linux 3.x may not have comp_algorithm tunable
    if [ -f "$ZRAM/comp_algorithm" ]; then
        # "lz4 [lzo] deflate"
        str="$(cat $ZRAM/comp_algorithm)"
        # remove "lz4 ["
        str="${str##*[}"
        # remove "] deflate"
        str="${str%%]*}"
        echo "$str"
    else
        # lzo is the default comp_algorithm since Linux 2.6
        echo "lzo"
    fi
}

mem_get_total_byte()
{
    local mem_total_str
    mem_total_str="$(cat /proc/meminfo | grep MemTotal)"
    echo "${mem_total_str:16:8}"
}

# return:status
mem_zram_status()
{
    # check whether the zram block device exists
    if [ "$(mem_has_zram_mod)" == "false" ]; then
        echo "ZRAM is not supported by kernel."
        return
    fi

    local swap_info
    swap_info="$(cat /proc/swaps | grep "$ZRAM_DEV")"
    if [ "$swap_info" != "" ]; then
        echo "Enabled. Size $(echo "$swap_info" | awk '{print $3}')kB, using $(mem_get_cur_comp_alg)."
    else
        echo "Disabled."
    fi
}
