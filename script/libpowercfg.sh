#!/system/bin/sh
# Powercfg Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20200216

BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh
. $BASEDIR/libcommon.sh

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

# $1:cluster_0_id $2:cluster_0_freq
# $3:cluster_1_id $4:cluster_1_freq
# $5:cluster_2_id $6:cluster_2_freq
set_min_freq()
{
    mutate "$2" $CPUFREQ/policy$1/scaling_min_freq
    mutate "$4" $CPUFREQ/policy$3/scaling_min_freq
    mutate "$6" $CPUFREQ/policy$5/scaling_min_freq
}

# $1:cluster_0_id $2:cluster_0_freq
# $3:cluster_1_id $4:cluster_1_freq
# $5:cluster_2_id $6:cluster_2_freq
set_max_freq()
{
    mutate "$2" $CPUFREQ/policy$1/scaling_max_freq
    mutate "$4" $CPUFREQ/policy$3/scaling_max_freq
    mutate "$6" $CPUFREQ/policy$5/scaling_max_freq
}

# $1:cluster_0_id $2:cluster_0_mincpu
# $3:cluster_1_id $4:cluster_1_mincpu
# $5:cluster_2_id $6:cluster_2_mincpu
set_min_cpus()
{
    mutate "$2" $CPU_DEV/cpu$1/core_ctl/min_cpus
    mutate "$4" $CPU_DEV/cpu$3/core_ctl/min_cpus
    mutate "$6" $CPU_DEV/cpu$5/core_ctl/min_cpus
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
