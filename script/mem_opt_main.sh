#!/system/bin/sh
# QTI memory optimization
# https://github.com/yc9559/qti-mem-opt
# Author: Matt Yang
# Version: v7.1 (20200328)

# Runonce after boot, to speed up the transition of power modes in powercfg

# load lib
BASEDIR="$(dirname "$0")"
. $BASEDIR/libcommon.sh
. $BASEDIR/libmem.sh
. $BASEDIR/libfscc.sh
. $BASEDIR/libadjshield.sh

TMEM="$(mem_get_total_byte)"
ZRAM_ALGS="$(mem_get_available_comp_alg)"
[ "$ZRAM_ALGS" == "unsupported" ] && ZRAM_ALGS="<unsupported>"

zram_size=""
zram_alg=""
minfree=""
efk=""

config_reclaim_param()
{
    # minfree: if (Cached - Unevictable) lower than threshold(unit:4KB), kill apps
    # efk: higher to call kswapd earlier, reduces direct memory allocation
    # wsf: lower to reduce useless page swapping, large-size reclaiming induces more page re-faults
    [ "$TMEM" -gt 8388608 ] && minfree="25600,38400,51200,64000,256000,307200" && efk="204800"
    [ "$TMEM" -le 8388608 ] && minfree="25600,38400,51200,64000,153600,179200" && efk="128000"
    [ "$TMEM" -le 6291456 ] && minfree="25600,38400,51200,64000,102400,128000" && efk="102400"
    [ "$TMEM" -le 4197304 ] && minfree="12800,19200,25600,32000,76800,102400"  && efk="76800"
    [ "$TMEM" -le 3145728 ] && minfree="12800,19200,25600,32000,51200,76800"   && efk="51200"
    [ "$TMEM" -le 2098652 ] && minfree="12800,19200,25600,32000,38400,51200"   && efk="25600"
    [ "$TMEM" -le 1049326 ] && minfree="5120,10240,12800,15360,25600,38400"    && efk="19200"
}

# $return:value(string)
calc_zram_default_size()
{
    local val
    [ "$TMEM" -gt 8388608 ] && val="0"
    [ "$TMEM" -le 8388608 ] && val="4"
    [ "$TMEM" -le 4197304 ] && val="2"
    [ "$TMEM" -le 2098652 ] && val="1"
    echo "$val"
}

config_zram()
{
    # load size from file
    zram_size="$(read_cfg_value zram_size)"
    case "$zram_size" in
        0.0|0|0.5|1.0|1|1.5|2.0|2|2.5|3.0|3|4.0|4|5.0|5|6.0|6) ;;
        *) zram_size="$(calc_zram_default_size)" ;;
    esac

    # load algorithm from file, use lz4 as default
    zram_alg="$(read_cfg_value zram_alg)"
    [ "$zram_alg" == "" ] && zram_alg="lz4"

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
    write_panel "Version: v7.1 (20200328)"
    write_panel "Last performed: $(date '+%Y-%m-%d %H:%M:%S')"
    write_panel ""
    write_panel "[ZRAM status]"
    write_panel "$(mem_zram_status)"
    write_panel ""
    write_panel "[FSCC status]"
    write_panel "$(fscc_status)"
    write_panel ""
    write_panel "[AdjShield status]"
    write_panel "$(adjshield_status)"
    write_panel ""
    write_panel "[Settings]"
    write_panel "# Available size(GB): 0 / 0.5 / 1 / 1.5 / 2 / 2.5 / 3 / 4 / 5 / 6"
    write_panel "zram_size=$zram_size"
    write_panel "# Available compression algorithm: $ZRAM_ALGS"
    write_panel "zram_alg=$zram_alg"
    write_panel "# AdjShield config file path"
    write_panel "adjshield_cfg=$adjshield_cfg"
}

# copy of common\system.prop
setprop ro.vendor.qti.sys.fw.bg_apps_limit 600
setprop ro.vendor.qti.sys.fw.bservice_limit 60
# disable memplus prefetcher which ram-boost relying on, use traditional swapping
setprop persist.vendor.sys.memplus.enable "false"
lock_val "0" /sys/module/memplus_core/parameters/memory_plus_enabled
lock_val "0" /proc/sys/vm/memory_plus

# we don't know when system will init ZRAM
mem_stop_zram
wait_until_login
mem_stop_zram

# disable oneplus mods which kill apps fast
lock_val "0" $LMK/batch_kill
lock_val "0" $LMK/quick_select
lock_val "0" $LMK/time_measure
lock_val "N" $LMK/trust_adj_chain
# disable memplus prefetcher which ram-boost relying on, use traditional swapping
setprop persist.vendor.sys.memplus.enable "false"
lock_val "0" /sys/module/memplus_core/parameters/memory_plus_enabled
lock_val "0" /proc/sys/vm/memory_plus
# disable oneplus kswapd modification
lock_val "0" $VM/breath_period
lock_val "-1001" $VM/breath_priority
# disable Qualcomm per process reclaim for low-tier or mid-tier devices
lock_val "0" /sys/module/process_reclaim/parameters/enable_process_reclaim

# Xiaomi K20pro need more time
sleep 15

config_zram
config_reclaim_param

# older adaptive_lmk may have false positive vmpressure issue
lock_val "0" $LMK/enable_adaptive_lmk
# almk will take no action if CACHED_APP_MAX_ADJ == 906
# lock_val "960" $LMK/adj_max_shift
# just unify param
lock_val "$minfree" $LMK/minfree
# HUUUGE shrinker(LMK) calling interval
lock_val "4096" $LMK/cost

# reclaim memory earlier
lock_val "$efk" $VM/extra_free_kbytes
# considering old platforms doesn't have this knob
lock_val "30" $VM/watermark_scale_factor
# it will be better if swappiness can be set above 100
[ "$(cat $VM/swappiness)" -le 100 ] && lock_val "100" $VM/swappiness
# drop a little more inode cache
lock_val "120" $VM/vfs_cache_pressure

# kernel reclaim threads run on more power-efficient cores
change_task_nice "kswapd" "-2"
change_task_nice "oom_reaper" "-2"
change_task_affinity "kswapd" "7f"
change_task_affinity "oom_reaper" "7f"

# similiar to PinnerService, Mlock(Unevictable) 200~350MB
fscc_add_obj "$SYS_FRAME/framework.jar"
fscc_add_obj "$SYS_FRAME/services.jar"
fscc_add_obj "$SYS_FRAME/ext.jar"
fscc_add_obj "$SYS_FRAME/telephony-common.jar"
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
fscc_add_obj "$SYS_LIB/libandroidfw.so"
fscc_add_obj "$SYS_LIB/libandroid.so"
fscc_add_obj "$SYS_LIB/libhwui.so"
fscc_add_obj "$SYS_LIB/libjpeg.so"
fscc_add_obj "$VDR_LIB/libssc.so"
fscc_add_obj "$VDR_LIB/libgsl.so"
fscc_add_obj "$VDR_LIB/sensors.ssc.so"
fscc_add_apex_lib "core-oj.jar"
fscc_add_apex_lib "core-libart.jar"
fscc_add_apex_lib "updatable-media.jar"
fscc_add_apex_lib "okhttp.jar"
fscc_add_apex_lib "bouncycastle.jar"
# do not pin too many files on low memory devices
[ "$TMEM" -gt 2098652 ] && fscc_add_apk "com.android.systemui"
[ "$TMEM" -gt 2098652 ] && fscc_add_dex "com.android.systemui"
[ "$TMEM" -gt 4197304 ] && fscc_add_app_home
[ "$TMEM" -gt 4197304 ] && fscc_add_app_ime
fscc_stop
fscc_start

# start adjshield
[ ! -f "$adjshield_cfg" ] && adjshield_create_default_cfg
adjshield_stop
adjshield_start

# save mode for automatic applying mode after reboot
save_panel

exit 0
