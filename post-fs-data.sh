#!/system/bin/sh
MODDIR=${0%/*}

mod_perfconfigstore()
{
    perfconfigstore="/system/vendor/etc/perf/perfconfigstore.xml"
    if [ -f "$perfconfigstore" ]; then
        found="$(cat "$perfconfigstore" | grep "ro.vendor.qti.sys.fw.bg_apps_limit")"
        if [ "$found" != "" ]; then
            # make a copy from system
            mkdir -p "$MODDIR/system/vendor/etc/perf"
            cp -f "$perfconfigstore" "$MODDIR/system/vendor/etc/perf/"
            perfconfigstore="$MODDIR/system/vendor/etc/perf/perfconfigstore.xml"
            # replace bg_apps_limit
            re_src='Name="ro\.vendor\.qti\.sys\.fw\.bg_apps_limit" Value="[0-9]*"'
            re_dst='Name="ro\.vendor\.qti\.sys\.fw\.bg_apps_limit" Value="600"'
            sed -i "s/$re_src/$re_dst/g" "$perfconfigstore"
            # replace bservice_limit
            re_src='Name="ro\.vendor\.qti\.sys\.fw\.bservice_limit" Value="[0-9]*"'
            re_dst='Name="ro\.vendor\.qti\.sys\.fw\.bservice_limit" Value="60"'
            sed -i "s/$re_src/$re_dst/g" "$perfconfigstore"
        fi
    fi
}

# do it before magisk magic mount to get the original perfconfigstore.xml
mod_perfconfigstore
