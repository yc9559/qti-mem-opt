#!/system/bin/sh
# Linux memory tunning Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200214

# include PATH
BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# Abbreviations
###############################

VM="/proc/sys/vm"
LMK="/sys/module/lowmemorykiller/parameters"
ZRAM0="/sys/block/zram0"
ZRAM1="/sys/block/zram1"
ZRAM_DEV="/dev/block/zram0"

###############################
# ZRAM tool functions
###############################

mem_stop_zram()
{
    # LG devices may have 2 zram block devices
    swapoff $ZRAM_DEV
    swapoff /dev/block/zram1
    mutate "1" $ZRAM0/reset
    mutate "1" $ZRAM1/reset
    mutate "0" $ZRAM0/disksize
    mutate "0" $ZRAM0/mem_limit
    mutate "0" $ZRAM1/disksize
    mutate "0" $ZRAM1/mem_limit
}

# $1:disksize $2:mem_lim $3:alg
mem_start_zram()
{
    mem_stop_zram
    lock_val "$3" $ZRAM0/comp_algorithm
    # bigger zram means more blocked IO caused by the zram block device swapping out
    lock_val "$1" $ZRAM0/disksize
    lock_val "$2" $ZRAM0/mem_limit
    mkswap $ZRAM_DEV
    swapon $ZRAM_DEV -p 23333
    # zram doesn't need much read ahead(random read)
    lock_val "0" $ZRAM0/queue/read_ahead_kb
    lock_val "0" $VM/page-cluster
}

mem_get_available_comp_alg()
{
    # "lz4 [lzo] deflate"
    # remove '[' and ']'
    echo "$(cat $ZRAM0/comp_algorithm | sed "s/\[//g" | sed "s/\]//g")"
}

mem_get_cur_comp_alg()
{
    local str
    # "lz4 [lzo] deflate"
    str="$(cat $ZRAM0/comp_algorithm)"
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
