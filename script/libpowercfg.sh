#!/system/bin/sh
# Powercfg Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200214

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
MSM_PERF="/sys/module/msm_performance/parameters"
ST_TOP="/dev/stune/top-app"
ST_FORE="/dev/stune/foreground"
ST_BACK="/dev/stune/background"
SDA_Q="/sys/block/sda/queue"

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

# $1:keyword $2:nr_max_matched
get_package_name_by_keyword()
{
    echo "$(pm list package | grep "$1" | head -n "$2" | cut -d: -f2)"
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

###############################
# QTI perf framework functions
###############################

# stop before updating cfg
stop_qti_perfd()
{
    stop perf-hal-1-0
    stop perf-hal-2-0
    usleep 500
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
    cp -af "$MODULE_PATH/$PERFCFG_REL/perfd_profiles/$1"/* "$MODULE_PATH/$PERFCFG_REL/"
}
