#! /vendor/bin/sh
# QTI memory optimization
# https://github.com/yc9559/qti-mem-opt
# Author: Matt Yang
# Version: v1 (20191214)

# Runonce after boot, to speed up the transition of power modes in powercfg

# load lib
module_dir="/data/adb/modules/qti-mem-opt"
script_rel=/system/vendor/bin/qti-mem-opt
. $module_dir/$script_rel/powercfg_lib.sh

# $1:disksize $2:mem_lim
config_zram()
{
    # bigger zram means more blocked IO caused by the zram block device swapping out
    swapoff /dev/block/zram0
    lock_val "1" /sys/block/zram0/reset
    lock_val "lz4" /sys/block/zram0/comp_algorithm # usually not shipped with stock kernels
    lock_val $1 /sys/block/zram0/disksize
    lock_val $2 /sys/block/zram0/mem_limit
    mkswap /dev/block/zram0
    swapon /dev/block/zram0 -p 23333
    # zram doesn't need much read ahead(random read)
    lock_val "0" /sys/block/zram0/queue/read_ahead_kb
    lock_val "0" /proc/sys/vm/page-cluster
}

start_zram()
{
    # load size from file
    disksize="1.5"
    cfgsize=`read_cfg_value zram_size`
    if [ "$cfgsize" != "" ]; then
        disksize=$cfgsize
    fi

    # ~2.8x compression ratio
    # higher disksize result in larger space-inefficient SwapCache
    case "$disksize" in
    "0.5") 
        config_zram 512M 160M
    ;;
    "1.0"|"1") 
        config_zram 1024M 360M
    ;;
    "1.5") 
        config_zram 1536M 540M
    ;;
    "2.0"|"2") 
        config_zram 2048M 720M
    ;;
    "3.0"|"3") 
        config_zram 3072M 1080M
    ;;
    "4.0"|"4") 
        config_zram 4096M 1440M
    ;;
    "5.0"|"5") 
        config_zram 5120M 1800M
    ;;
    "6.0"|"6") 
        config_zram 6144M 2160M
    ;;
    *)
        disksize="1.5"
        swapoff /dev/block/zram0
    ;;
    esac

    # save mode for automatic applying mode after reboot
    echo ""                                                                 >  $panel_path
    echo "QTI memory optimization"                                          >> $panel_path
    echo "https://github.com/yc9559/qti-mem-opt"                            >> $panel_path
    echo "Author:   Matt Yang"                                              >> $panel_path
    echo "Version:  v1 (20191214)"                                          >> $panel_path
    echo ""                                                                 >> $panel_path
    echo "[status]"                                                         >> $panel_path
    echo "ZRAM size: $disksize"                                             >> $panel_path
    echo "Last:      `date '+%Y-%m-%d %H:%M:%S'`"                           >> $panel_path
    echo ""                                                                 >> $panel_path
    echo "[settings]"                                                       >> $panel_path
    echo "# Available size(GB): 0 / 0.5 / 1 / 1.5 / 2 / 3 / 4 / 5 / 6"      >> $panel_path
    echo "zram_size=$disksize"                                              >> $panel_path
}

# suppress stderr
(

wait_until_login

start_zram

# copy of common\system.prop
setprop ro.vendor.qti.sys.fw.bg_apps_limit 600
setprop ro.vendor.qti.sys.fw.bservice_limit 30
setprop ro.vendor.qti.sys.fw.bservice_age 86400

# minfree unit(page size): 4K
lock_val "19200,25600,51200,76800,128000,256000" /sys/module/lowmemorykiller/parameters/minfree
lock_val "0,200,920,930,940,950" /sys/module/lowmemorykiller/parameters/adj
# disable automatic kill when vmpressure >= 90
lock_val "0" /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
# please kill all the processes we really don't want when vmpressure >= 90
# lock_val "960" /sys/module/lowmemorykiller/parameters/adj_max_shift
# larger shrinker(LMK) calling interval
lock_val "48" /sys/module/lowmemorykiller/parameters/cost
# higher watermark_mid reduces direct memory allocation
# 7477M, watermark_mid - watermark_min = 187M
lock_val "32768" /proc/sys/vm/min_free_kbytes
lock_val "153600" /proc/sys/vm/extra_free_kbytes
# lower to reduce useless page swapping
lock_val "50" /proc/sys/vm/watermark_scale_factor
# more room for page cache
lock_val "100" /proc/sys/vm/swappiness
lock_val "120" /proc/sys/vm/vfs_cache_pressure

# avoid swapping latency intensive processes
mkdir /dev/memcg/lowlat
lock_val "1" /dev/memcg/memory.use_hierarchy
lock_val "1" /dev/memcg/memory.move_charge_at_immigrate
lock_val "1" /dev/memcg/lowlat/memory.move_charge_at_immigrate
lock_val "0" /dev/memcg/lowlat/memory.swappiness

# move latency intensive processes to memcg/lowlat
change_task_cgroup "system_server" "lowlat" "memcg"
change_task_cgroup "surfaceflinger" "lowlat" "memcg"
change_task_cgroup "composer" "lowlat" "memcg"
change_task_cgroup "allocator" "lowlat" "memcg"
change_task_cgroup "systemui" "lowlat" "memcg"

# wait for the Launcher & IME to start up
sleep 15
change_task_cgroup "launcher" "lowlat" "memcg"
change_task_cgroup ".input" "lowlat" "memcg"

# suppress stderr
) 2> /dev/null
