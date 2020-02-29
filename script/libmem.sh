#!/system/bin/sh
# Linux memory tunning Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200228

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

###############################
# ZRAM tool functions
###############################

mem_stop_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    if [ -b "$ZRAM_DEV" ]; then
        # swapoff all devices
        # swap devices may be not shown in blkid
        for dev in $(cat /proc/swaps | grep "^/" | awk '{print $1}'); do
            swapoff "$dev"
        done
    fi
}

# $1:disksize $2:mem_lim $3:alg
mem_start_zram()
{
    # control swap if only the kernel support ZRAM, otherwise leave swap untouched
    if [ -b "$ZRAM_DEV" ]; then
        mem_stop_zram
        mutate "1" $ZRAM/reset
        lock_val "$3" $ZRAM/comp_algorithm
        lock_val "$1" $ZRAM/disksize
        lock_val "$2" $ZRAM/mem_limit
        # holy crap, mkswap in busybox(32bit) cannot mkswap >= 4GB
        /system/bin/mkswap $ZRAM_DEV
        /vendor/bin/mkswap $ZRAM_DEV
        # swapon -p not supported by BusyBox v1.31.1-osm0sis
        # swapon $ZRAM_DEV -p 23333
        swapon $ZRAM_DEV
        # zram doesn't need much read ahead(random read)
        lock_val "0" $ZRAM/queue/read_ahead_kb
        lock_val "0" $VM/page-cluster
    fi
}

mem_get_available_comp_alg()
{
    if [ -b "$ZRAM_DEV" ]; then
        # Linux 3.x may not have comp_algorithm tunable
        if [ -f "$ZRAM/comp_algorithm" ]; then
            # "lz4 [lzo] deflate", remove '[' and ']'
            echo "$(cat $ZRAM/comp_algorithm | sed "s/\[//g" | sed "s/\]//g")"
        else
            # lzo is the default comp_algorithm since Linux 2.6
            echo "lzo"
        fi
    else
        echo "unsupported"
    fi
}

mem_get_cur_comp_alg()
{
    local str
    if [ -b "$ZRAM_DEV" ]; then
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
    else
        echo "unsupported"
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
    local swap_info
    # check whether the zram block device exists
    if [ -b "$ZRAM_DEV" ]; then
        swap_info="$(cat /proc/swaps | grep "$ZRAM_DEV")"
        if [ "$swap_info" != "" ]; then
            echo "Enabled. Size $(echo "$swap_info" | awk '{print $3}')kB, using $(mem_get_cur_comp_alg)."
        else
            echo "Disabled."
        fi
    else
        echo "ZRAM is not supported by kernel."
    fi
}
