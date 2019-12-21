#! /system/bin/sh
# QTI memory optimization
# https://github.com/yc9559/qti-mem-opt
# Author: Matt Yang
# Version: v2 (20191221)

# Runonce after boot, to speed up the transition of power modes in powercfg

# load lib
module_dir="/data/adb/modules/qti-mem-opt"
script_rel="./script"
. $module_dir/$script_rel/powercfg_lib.sh

MemTotalStr=`cat /proc/meminfo | grep MemTotal`
MemTotal=${MemTotalStr:16:8}
zram_size="0"

config_minfree()
{
    minfree=""
    # <= 4GB
    if [ $MemTotal -le 4197304 ]; then
        minfree="19200,25600,76800,102400,128000,153600"
    # == 6GB
    elif [ $MemTotal -le 6291456 ]; then
        minfree="19200,25600,128000,153600,179200,204800"
    # == 8GB
    elif [ $MemTotal -le 8388608 ]; then
        minfree="19200,25600,179200,204800,230400,256000"
    # > 8GB
    else
        minfree="19200,25600,256000,307200,358400,409600"
    fi

    # minfree unit(page size): 4K
    lock_val "$minfree" $lmk/minfree
}

# $return:value(string)
calc_zram_default_size()
{
    value=""
    # <= 4GB
    if [ $MemTotal -le 4197304 ]; then
        value="1"
    # == 6GB
    elif [ $MemTotal -le 6291456 ]; then
        value="1.5"
    # == 8GB
    elif [ $MemTotal -le 8388608 ]; then
        value="2.5"
    # >= 8GB
    else
        value="0"
    fi
    echo $value
}

stop_zram()
{
    # LG devices may have 2 zram block devices
    /system/bin/swapoff /dev/block/zram0
    /vendor/bin/swapoff /dev/block/zram0
    /system/bin/swapoff /dev/block/zram1
    /vendor/bin/swapoff /dev/block/zram1
    mutate "1" /sys/block/zram0/reset
    mutate "1" /sys/block/zram1/reset
    mutate "0" /sys/block/zram0/disksize
    mutate "0" /sys/block/zram0/mem_limit
    mutate "0" /sys/block/zram1/disksize
    mutate "0" /sys/block/zram1/mem_limit
}

# $1:disksize $2:mem_lim
start_zram()
{
    stop_zram
    # do not touch comp_algorithm, somebody may prefer zstd
    # usually not shipped with stock kernels
    # lock_val "lz4" /sys/block/zram0/comp_algorithm
    # bigger zram means more blocked IO caused by the zram block device swapping out
    lock_val $1 /sys/block/zram0/disksize
    lock_val $2 /sys/block/zram0/mem_limit
    # fix compatibility issues
    /system/bin/mkswap /dev/block/zram0
    /vendor/bin/mkswap /dev/block/zram0
    /system/bin/swapon /dev/block/zram0 -p 23333
    /vendor/bin/swapon /dev/block/zram0 -p 23333
    # zram doesn't need much read ahead(random read)
    lock_val "0" /sys/block/zram0/queue/read_ahead_kb
    lock_val "0" $vm/page-cluster
}

config_zram()
{
    # load size from file
    zram_size=`read_cfg_value zram_size`
    case "$zram_size" in
    "0.0"|"0"|"0.5"|"1.0"|"1"|"1.5"|"2.0"|"2"|"2.5"|"3.0"|"3"|"4.0"|"4"|"5.0"|"5"|"6.0"|"6") 
    ;;
    *) 
        zram_size=`calc_zram_default_size`
    ;;
    esac

    # ~2.8x compression ratio
    # higher disksize result in larger space-inefficient SwapCache
    case "$zram_size" in
    "0.0"|"0") 
        stop_zram
    ;;
    "0.5") 
        start_zram 512M 160M
    ;;
    "1.0"|"1") 
        start_zram 1024M 360M
    ;;
    "1.5") 
        start_zram 1536M 540M
    ;;
    "2.0"|"2") 
        start_zram 2048M 720M
    ;;
    "2.5") 
        start_zram 2560M 900M
    ;;
    "3.0"|"3") 
        start_zram 3072M 1080M
    ;;
    "4.0"|"4") 
        start_zram 4096M 1440M
    ;;
    "5.0"|"5") 
        start_zram 5120M 1800M
    ;;
    "6.0"|"6") 
        start_zram 6144M 2160M
    ;;
    esac
}

save_panel()
{
    clear_panel
    write_panel ""
    write_panel "QTI memory optimization"
    write_panel "https://github.com/yc9559/qti-mem-opt"
    write_panel "Author:   Matt Yang"
    write_panel "Version:  v2 (20191221)"
    write_panel ""
    write_panel "[current status]"
    write_panel "ZRAM size: $zram_size"
    write_panel "Last:      `date '+%Y-%m-%d %H:%M:%S'`"
    write_panel ""
    write_panel "[settings]"
    write_panel "# Available size(GB): 0 / 0.5 / 1 / 1.5 / 2 / 2.5 / 3 / 4 / 5 / 6"
    write_panel "zram_size=$zram_size"
    write_panel ""
}

# suppress stderr
(

wait_until_login

config_zram

# copy of common\system.prop
setprop ro.vendor.qti.sys.fw.bg_apps_limit 600
setprop ro.vendor.qti.sys.fw.bservice_limit 60

# config traditional LMK
config_minfree
lock_val "0,200,920,930,940,950" $lmk/adj
# disable automatic kill when vmpressure >= 90
lock_val "0" $lmk/enable_adaptive_lmk
# please kill all the processes we really don't want when vmpressure >= 90
# lock_val "960" $lmk/adj_max_shift
# shorter shrinker(LMK) calling interval
lock_val "16" $lmk/cost

# higher watermark_mid reduces direct memory allocation
# 7477M, watermark_mid - watermark_min = 124M
lock_val "32768" $vm/min_free_kbytes
lock_val "51200" $vm/extra_free_kbytes
# lower to reduce useless page swapping
lock_val "100" $vm/watermark_scale_factor
# more room for page cache
lock_val "100" $vm/swappiness
lock_val "120" $vm/vfs_cache_pressure

# save mode for automatic applying mode after reboot
save_panel

# suppress stderr
) 2> /dev/null
