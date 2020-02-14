#!/system/bin/sh
# QTI memory optimization
# https://github.com/yc9559/qti-mem-opt
# Author: Matt Yang
# Version: v4 (20200214)

# Runonce after boot, to speed up the transition of power modes in powercfg

# load lib
BASEDIR="$(dirname "$0")"
. $BASEDIR/libpowercfg.sh
. $BASEDIR/libmem.sh
. $BASEDIR/libfscc.sh
. $BASEDIR/libadjshield.sh

MEM_TOTAL="$(mem_get_total_byte)"
ZRAM_ALGS="$(mem_get_available_comp_alg)"

zram_size=""
zram_alg=""
minfree=""
adj=""
efk=""
wsf=""

config_reclaim_param()
{
    # minfree: if (Cached - Unevictable) lower than threshold(unit:4KB), kill apps
    # adj: cached_adj >= 900, work with $LMK/cost to avoid kill apps too quickly
    # efk: higher to call kswapd earlier, reduces direct memory allocation
    # wsf: lower to reduce useless page swapping, large-size reclaiming induces more page re-faults

    # <= 4GB
    if [ "$MEM_TOTAL" -le 4197304 ]; then
        minfree="25600,76800,102400"
        efk="204800"
    # 6GB or 8GB
    elif [ "$MEM_TOTAL" -le 8388608 ]; then
        minfree="25600,76800,128000"
        efk="307200"
    # > 8GB
    else
        minfree="25600,76800,204800"
        efk="409600"
    fi

    adj="200,600,901"
    wsf="20"
}

# $return:value(string)
calc_zram_default_size()
{
    local value=""
    # <= 4GB
    if [ "$MEM_TOTAL" -le 4197304 ]; then
        value="1"
    # == 6GB
    elif [ "$MEM_TOTAL" -le 6291456 ]; then
        value="2"
    # == 8GB
    elif [ "$MEM_TOTAL" -le 8388608 ]; then
        value="3"
    # >= 8GB
    else
        value="0"
    fi
    echo "$value"
}

config_zram()
{
    # check whether the zram block device exists
    if [ ! -b "$ZRAM_DEV" ]; then
        zram_size="unsupported"
        zram_alg="unsupported"
        return
    fi

    # load size from file
    zram_size="$(read_cfg_value zram_size)"
    case "$zram_size" in
        0.0|0|0.5|1.0|1|1.5|2.0|2|2.5|3.0|3|4.0|4|5.0|5|6.0|6) ;;
        *) zram_size="$(calc_zram_default_size)" ;;
    esac

    # load algorithm from file, use lz4 as default
    zram_alg="$(read_cfg_value zram_alg)"
    case "$zram_alg" in
        lzo|lzo-rle|lz4|deflate|zstd|zlib|xz) ;;
        *) zram_alg="lz4" ;;
    esac

    # ~2.8x compression ratio
    # higher disksize result in larger space-inefficient SwapCache
    case "$zram_size" in
        0.0|0)  mem_stop_zram ;;
        0.5)    mem_start_zram 512M 160M "$zram_alg" ;;
        1.0|1)  mem_start_zram 1024M 360M "$zram_alg" ;;
        1.5)    mem_start_zram 1536M 540M "$zram_alg" ;;
        2.0|2)  mem_start_zram 2048M 720M "$zram_alg" ;;
        2.5)    mem_start_zram 2560M 900M "$zram_alg" ;;
        3.0|3)  mem_start_zram 3072M 1080M "$zram_alg" ;;
        4.0|4)  mem_start_zram 4096M 1440M "$zram_alg" ;;
        5.0|5)  mem_start_zram 5120M 1800M "$zram_alg" ;;
        6.0|6)  mem_start_zram 6144M 2160M "$zram_alg" ;;
    esac

    # target algorithm may be not supported
    zram_alg="$(mem_get_cur_comp_alg)"
}

save_panel()
{
    clear_panel
    write_panel ""
    write_panel "QTI memory optimization"
    write_panel "https://github.com/yc9559/qti-mem-opt"
    write_panel "Author: Matt Yang"
    write_panel "Version: v4 (20200214)"
    write_panel ""
    write_panel "[current status]"
    write_panel "Last performed: $(date '+%Y-%m-%d %H:%M:%S')"
    write_panel "ZRAM size: $zram_size"
    write_panel "ZRAM compression algorithm: $zram_alg"
    write_panel ""
    write_panel "[settings]"
    write_panel "# Available size(GB): 0 / 0.5 / 1 / 1.5 / 2 / 2.5 / 3 / 4 / 5 / 6"
    write_panel "zram_size=$zram_size"
    write_panel "# Available compression algorithm: $ZRAM_ALGS"
    write_panel "zram_alg=$zram_alg"
    write_panel "# AdjShield config file path"
    write_panel "adjshield_cfg=$adjshield_cfg"
}

# suppress stderr
(

# copy of common\system.prop
setprop ro.vendor.qti.sys.fw.bg_apps_limit 600
setprop ro.vendor.qti.sys.fw.bservice_limit 60

wait_until_login

# Xiaomi K20pro need more time
sleep 15

config_zram
config_reclaim_param

lock_val "$minfree" $LMK/minfree
lock_val "$adj" $LMK/adj
# older adaptive_lmk may have false positive vmpressure issue
lock_val "0" $LMK/enable_adaptive_lmk

lock_val "16384" $VM/min_free_kbytes
lock_val "$efk" $VM/extra_free_kbytes
lock_val "$wsf" $VM/watermark_scale_factor
lock_val "8192" $VM/admin_reserve_kbytes
lock_val "8192" $VM/user_reserve_kbytes
# more room for page cache
lock_val "100" $VM/swappiness
lock_val "120" $VM/vfs_cache_pressure

# similiar to PinnerService, Mlock(Unevictable) ~200MB
fscc_add_obj "$SYS_FRAME/framework.jar"
fscc_add_obj "$SYS_FRAME/services.jar"
fscc_add_obj "$SYS_FRAME/telephony-common.jar"
fscc_add_obj "$SYS_FRAME/QPerformance.jar"
fscc_add_obj "$SYS_FRAME/UxPerformance.jar"
fscc_add_obj "$SYS_FRAME/qcnvitems.jar"
fscc_add_obj "$SYS_FRAME/oat"
fscc_add_obj "$SYS_FRAME/arm64"
fscc_add_obj "$SYS_FRAME/arm/boot-framework.oat"
fscc_add_obj "$SYS_FRAME/arm/boot-framework.vdex"
fscc_add_obj "$SYS_FRAME/arm/boot.oat"
fscc_add_obj "$SYS_FRAME/arm/boot.vdex"
fscc_add_obj "$SYS_FRAME/arm/boot-core-libart.oat"
fscc_add_obj "$SYS_FRAME/arm/boot-core-libart.vdex"
fscc_add_obj "$SYS_LIB/libandroid_servers.so"
fscc_add_obj "$SYS_LIB/libandroid_runtime.so"
fscc_add_obj "$SYS_LIB/libandroid.so"
fscc_add_obj "$SYS_LIB/libhwui.so"
fscc_list_append "$SYS_LIB/libhidl*"
fscc_add_apex_lib "core-oj.jar"
fscc_add_apex_lib "core-libart.jar"
fscc_add_apex_lib "updatable-media.jar"
fscc_add_apex_lib "okhttp.jar"
fscc_add_apex_lib "bouncycastle.jar"
fscc_add_dex "com.android.systemui"
fscc_add_app_home
fscc_add_app_ime
fscc_start_svc

# reclaim threads do not run on prime core
mkdir /dev/cpuset/reclaim
lock_val "0-6" /dev/cpuset/reclaim/cpus
change_task_cgroup "kswapd" "reclaim" "cpuset"
change_task_cgroup "oom_reaper" "reclaim" "cpuset"
change_task_affinity "kswapd" "7f"
change_task_affinity "oom_reaper" "7f"

# disable oneplus mods which kill apps fast
lock_val "0" $LMK/batch_kill
lock_val "0" $LMK/quick_select
lock_val "0" $LMK/time_measure
lock_val "N" $LMK/trust_adj_chain
# disable memplus prefetcher which ram-boost relying on, use traditional swapping
setprop persist.vendor.sys.memplus.enable 0
lock_val "0" /sys/module/memplus_core/parameters/memory_plus_enabled
# disable oneplus kswapd modification
lock_val "0" $VM/breath_period
lock_val "-1001" $VM/breath_priority

# start adjshield
[ ! -f "$adjshield_cfg" ] && adjshield_create_default_cfg
adjshield_start

# save mode for automatic applying mode after reboot
save_panel

# suppress stderr
) 2> /dev/null
