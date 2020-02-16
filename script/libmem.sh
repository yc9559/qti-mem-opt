#!/system/bin/sh
# Linux memory tunning Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200216

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
    # swapoff all devices
    for dev in $(blkid | grep swap | cut -d: -f1); do
        swapoff "$dev"
    done
}

# $1:disksize $2:mem_lim $3:alg
mem_start_zram()
{
    mem_stop_zram
    mutate "1" $ZRAM/reset
    lock_val "$3" $ZRAM/comp_algorithm
    lock_val "$1" $ZRAM/disksize
    lock_val "$2" $ZRAM/mem_limit
    mkswap $ZRAM_DEV
    swapon $ZRAM_DEV -p 23333
    # zram doesn't need much read ahead(random read)
    lock_val "0" $ZRAM/queue/read_ahead_kb
    lock_val "0" $VM/page-cluster
}

mem_get_available_comp_alg()
{
    # "lz4 [lzo] deflate"
    # remove '[' and ']'
    echo "$(cat $ZRAM/comp_algorithm | sed "s/\[//g" | sed "s/\]//g")"
}

mem_get_cur_comp_alg()
{
    local str
    # "lz4 [lzo] deflate"
    str="$(cat $ZRAM/comp_algorithm)"
    # remove "lz4 ["
    str="${str##*[}"
    # remove "] deflate"
    str="${str%%]*}"
    echo "$str"
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
            echo "Enabled, size $(echo $swap_info | awk '{print $3}')kB, using $(mem_get_cur_comp_alg)."
        else
            echo "Disabled."
        fi
    else
        echo "ZRAM is not supported by kernel."
    fi
}
