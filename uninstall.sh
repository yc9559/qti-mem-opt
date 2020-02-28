#!/system/bin/sh
# Additional cleanup

wait_until_login()
{
    # whether in lock screen, tested on Android 7.1 & 10.0
    # in case of other magisk module remounting /data as RW
    while [ "$(dumpsys window policy | grep mInputRestricted=true)" != "" ]; do
        sleep 2
    done
    # we doesn't have the permission to rw "/sdcard" before the user unlocks the screen
    while [ ! -d "/sdcard/Android" ]; do
        sleep 2
    done
}

wait_until_login
rm -rf "/sdcard/Android/panel_qti_mem.txt"
rm -rf "/sdcard/Android/panel_adjshield.txt"
rm -rf "/sdcard/Android/log_adjshield.txt"
