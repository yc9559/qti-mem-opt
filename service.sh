#!/system/bin/sh
# Please don't hardcode /magisk/modname/... ; instead, please use $MODDIR/...
# This will make your scripts compatible even if Magisk change its mount point in the future
MODDIR=${0%/*}
SCRIPT_DIR="$MODDIR/script"

if [ "$(cat $SCRIPT_DIR/pathinfo.sh | grep "$PATH")" == "" ]; then
    echo "" >> $SCRIPT_DIR/pathinfo.sh
    echo "# prefer to use busybox provided by magisk" >> $SCRIPT_DIR/pathinfo.sh
    echo "PATH=$PATH" >> $SCRIPT_DIR/pathinfo.sh
fi

# not relying on executable permissions
sh $SCRIPT_DIR/mem_opt_main.sh
