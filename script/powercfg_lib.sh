#!/system/bin/sh
# Powercfg Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200104

# include PATH
BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh

###############################
# PATHs
###############################

PERFCFG_REL="./system/vendor/etc/perf"

###############################
# Abbreviations
###############################

SCHED="/proc/sys/kernel"
CPUFREQ="/sys/devices/system/cpu/cpufreq"
CPU_BOOST="/sys/module/cpu_boost/parameters"
CPU_DEV="/sys/devices/system/cpu"
KSGL="/sys/class/kgsl/kgsl-3d0"
DEVFREQ="/sys/class/devfreq"
LPM="/sys/module/lpm_levels/parameters"
VM="/proc/sys/vm"
LMK="/sys/module/lowmemorykiller/parameters"
ZRAM0="/sys/block/zram0"
ZRAM1="/sys/block/zram1"
ZRAM_DEV="/dev/block/zram0"

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

# $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
change_task_cgroup()
{
    for temp_pid in $(ps -Ao pid,args | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            echo "$temp_tid" > "/dev/$3/$2/tasks"
        done
    done
}

# $1:task_name $2:hex_mask(0x00000003 is CPU0 and CPU1)
change_task_affinity()
{
    for temp_pid in $(ps -Ao pid,args | grep "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            taskset -p "$2" "$temp_tid"
        done
    done
}

get_total_mem_byte()
{
    local mem_total_str
    mem_total_str="$(cat /proc/meminfo | grep MemTotal)"
    echo "${mem_total_str:16:8}"
}

###############################
# Config File Operator
###############################

# $1:key $return:value(string)
read_cfg_value()
{
    local value=""
    if [ -f "$PANEL_FILE" ]; then
        value="$(grep "^$1=" "$PANEL_FILE" | tr -d ' ' | cut -d= -f2)"
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
    # we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
    while [ ! -f "$PANEL_FILE" ]; do
        touch "$PANEL_FILE"
        sleep 2
    done
}

###############################
# ZRAM
###############################

stop_zram()
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
start_zram()
{
    stop_zram
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

get_available_comp_alg()
{
    # "lz4 [lzo] deflate"
    # remove '[' and ']'
    echo "$(cat $ZRAM0/comp_algorithm | sed "s/\[//g" | sed "s/\]//g")"
}

get_cur_comp_alg()
{
    local str
    # "lz4 [lzo] deflate"
    str="$(cat $ZRAM0/comp_algorithm)"
    # remove "lz4 ["
    str=${str#*[}
    # remove "] deflate"
    str=${str%]*}
    echo "$str"
}

###############################
# QTI perf framework functions
###############################

# stop before updating cfg
stop_qti_perfd()
{
    stop perf-hal-1-0
    stop perf-hal-2-0
}

# start after updating cfg
start_qti_perfd()
{
    start perf-hal-1-0
    start perf-hal-2-0
}

# $1:mode(such as balance)
update_qti_perfd()
{
    rm /data/vendor/perfd/default_values
    cp -af "$MODULE_PATH/$PERFCFG_REL/perfd_profiles/$1/*" "$MODULE_PATH/$PERFCFG_REL/"
}
