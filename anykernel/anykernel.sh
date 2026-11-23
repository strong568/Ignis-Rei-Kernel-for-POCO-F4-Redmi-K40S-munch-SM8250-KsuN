### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Ignis-Rei for POCO F4 / Redmi K40S (munch)

properties() { '
kernel.string=Ignis-Rei Kernel | munch
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=munch
device.name2=munchin
'; }

BLOCK=/dev/block/bootdevice/by-name/boot;
block=/dev/block/bootdevice/by-name/boot;
for testpath in /dev/block/bootdevice/by-name /dev/block/by-name /dev/block/mapper; do
  if [ -e "$testpath/boot_a" ] || [ -e "$testpath/boot" ]; then
    block="$testpath/boot"
    BLOCK="$testpath/boot"
    break
  fi
done

IS_SLOT_DEVICE=auto;
is_slot_device=auto;
RAMDISK_COMPRESSION=auto;
ramdisk_compression=auto;
PATCH_VBMETA_FLAG=auto;
patch_vbmeta_flag=auto;
NO_BLOCK_DISPLAY=1;
no_block_display=1;

. tools/ak3-core.sh;

AKHOME="${AKHOME:-${home:-$PWD}}";
home="$AKHOME";

ui_print " ";
ui_print "  ===========================================";
ui_print "  |    Ignis-Rei Kernel | munch [PERF]      |";
ui_print "  |      Extreme Gaming / OC Edition        |";
ui_print "  |          Android 11 - 17                |";
ui_print "  ===========================================";
ui_print " ";

mv *-Image $home/Image 2>/dev/null || true
[ -f "$home/Image" ] || abort "  ! Kernel Image not found in $home";

IS_MIUI=0;
IS_AOSP=0;
IS_OPLUS=0;
ROM_TYPE="";
ROM_DETAIL="";

# 1. Manual override flags
if [ -f /tmp/aosp ] || [ -f /sdcard/aosp ] || [ -f /data/aosp ]; then
    IS_AOSP=1;
    ROM_TYPE="AOSP (Manual Override)";
elif [ -f /tmp/miui ] || [ -f /sdcard/miui ] || [ -f /data/miui ] || [ -f /tmp/hyperos ] || [ -f /sdcard/hyperos ]; then
    IS_MIUI=1;
    ROM_TYPE="MIUI / HyperOS (Manual Override)";
elif [ -f /tmp/oplus ] || [ -f /sdcard/oplus ] || [ -f /data/oplus ] || \
     [ -f /tmp/oos ] || [ -f /sdcard/oos ] || [ -f /data/oos ] || \
     [ -f /tmp/coloros ] || [ -f /sdcard/coloros ] || [ -f /data/coloros ] || \
     [ -f /tmp/realme ] || [ -f /sdcard/realme ] || [ -f /data/realme ] || \
     [ -f /tmp/realmeui ] || [ -f /sdcard/realmeui ] || [ -f /data/realmeui ]; then
    IS_OPLUS=1;
    ROM_TYPE="ColorOS / OxygenOS / RealmeUI Port (Manual Override)";
fi;

# 2. Live getprop (when flashed from booted Android)
if [ "$IS_AOSP" -eq 0 ] && [ "$IS_MIUI" -eq 0 ] && [ "$IS_OPLUS" -eq 0 ] && [ "$BOOTMODE" = "true" ]; then
    if command -v getprop >/dev/null 2>&1; then
        OPLUS_PROP=$(getprop ro.build.version.oplusrom 2>/dev/null);
        [ -z "$OPLUS_PROP" ] && OPLUS_PROP=$(getprop ro.coloros.version 2>/dev/null);
        [ -z "$OPLUS_PROP" ] && OPLUS_PROP=$(getprop ro.oxygen.version 2>/dev/null);
        [ -z "$OPLUS_PROP" ] && OPLUS_PROP=$(getprop ro.build.version.opporom 2>/dev/null);
        [ -z "$OPLUS_PROP" ] && OPLUS_PROP=$(getprop ro.realme.version 2>/dev/null);
        [ -z "$OPLUS_PROP" ] && OPLUS_PROP=$(getprop ro.oplus.image.my_product.version 2>/dev/null);

        BRAND=$(getprop ro.product.system.brand 2>/dev/null);
        [ -z "$BRAND" ] && BRAND=$(getprop ro.product.brand 2>/dev/null);
        DISP_ID=$(getprop ro.build.display.id 2>/dev/null);

        OS_NAME=$(getprop ro.mi.os.version.name 2>/dev/null);
        MIUI_NAME=$(getprop ro.miui.ui.version.name 2>/dev/null);
        BUILD_INC=$(getprop ro.build.version.incremental 2>/dev/null);

        if [ -n "$OPLUS_PROP" ] || echo "$BRAND $DISP_ID" | grep -i -q -E "oneplus|oppo|realme|coloros|oxygenos|realmeui"; then
            IS_OPLUS=1;
            ROM_TYPE="OPlus Port (ColorOS / OxygenOS / RealmeUI)";
            ROM_DETAIL="${OPLUS_PROP:-$BRAND}";
        elif [ -n "$OS_NAME" ] || echo "$BUILD_INC" | grep -q -E "^([0-9]+)?OS[0-9]"; then
            IS_MIUI=1;
            ROM_TYPE="Xiaomi HyperOS";
            ROM_DETAIL="${OS_NAME:-$BUILD_INC}";
        elif [ -n "$MIUI_NAME" ] || echo "$BUILD_INC" | grep -q -E "^V[0-9]"; then
            IS_MIUI=1;
            ROM_TYPE="Xiaomi MIUI";
            ROM_DETAIL="${MIUI_NAME:-$BUILD_INC}";
        fi;
    fi;
fi;

# 3. Recovery filesystem inspection
if [ "$IS_AOSP" -eq 0 ] && [ "$IS_MIUI" -eq 0 ] && [ "$IS_OPLUS" -eq 0 ]; then
    SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null);
    [ -z "$SLOT" ] && SLOT=$(grep -o "androidboot\.slot_suffix=[^ ]*" /proc/cmdline 2>/dev/null | cut -d= -f2);

    SYSTEM_MOUNTED=0;
    if [ ! -f /system/build.prop ] && [ ! -f /system/system/build.prop ] && [ ! -f /system_root/system/build.prop ]; then
        mkdir -p /s_chk 2>/dev/null;
        for dev in "/dev/block/mapper/system$SLOT" "/dev/block/mapper/system" \
                   "/dev/block/bootdevice/by-name/system$SLOT" "/dev/block/bootdevice/by-name/system"; do
            if [ -b "$dev" ]; then
                mount -o ro "$dev" /s_chk 2>/dev/null && { SYSTEM_MOUNTED=1; break; };
            fi;
        done;
    fi;

    OPLUS_INDICATORS="/my_product/build.prop /m_chk/build.prop \
                      /s_chk/my_product /s_chk/system/my_product \
                      /s_chk/system/framework/oplus-framework.jar \
                      /system/framework/oplus-framework.jar \
                      /s_chk/system/priv-app/OplusSystemUI \
                      /system/priv-app/OplusSystemUI \
                      /s_chk/system/priv-app/ColorOSSystemUI \
                      /system/priv-app/ColorOSSystemUI \
                      /s_chk/system/etc/oplusVersion /system/etc/oplusVersion";

    for f in $OPLUS_INDICATORS; do
        if [ -e "$f" ]; then
            IS_OPLUS=1;
            ROM_TYPE="OPlus Port (ColorOS / OxygenOS / RealmeUI)";
            ROM_DETAIL="$(basename "$f")";
            break;
        fi;
    done;

    PROP_LIST="/system_root/system/build.prop /system/system/build.prop /system/build.prop /system/etc/build.prop \
               /s_chk/system/build.prop /s_chk/build.prop /s_chk/etc/build.prop /vendor/build.prop";

    if [ "$IS_OPLUS" -eq 0 ]; then
        for prop in $PROP_LIST; do
            if [ -f "$prop" ]; then
                OPLUS_FIND=$(grep -E "^(ro\.build\.version\.(oplus|oppo)rom|ro\.(coloros|oxygen|realme)\.version)=" "$prop" 2>/dev/null | head -n 1 | cut -d= -f2);
                if [ -n "$OPLUS_FIND" ]; then
                    IS_OPLUS=1;
                    ROM_TYPE="OPlus Port (ColorOS / OxygenOS / RealmeUI)";
                    ROM_DETAIL="$OPLUS_FIND";
                    break;
                fi;
                if grep -E "^ro\.product\.(system\.)?(brand|manufacturer)=(OnePlus|OPPO|realme)" "$prop" 2>/dev/null | grep -q "="; then
                    IS_OPLUS=1;
                    ROM_TYPE="OPlus Port (ColorOS / OxygenOS / RealmeUI)";
                    break;
                fi;
            fi;
        done;
    fi;

    if [ "$IS_OPLUS" -eq 0 ] && [ "$IS_MIUI" -eq 0 ]; then
        for prop in $PROP_LIST; do
            if [ -f "$prop" ]; then
                HOS_VAL=$(grep -E "^ro\.mi\.os\.version\.name=" "$prop" 2>/dev/null | head -n 1 | cut -d= -f2);
                MIUI_VAL=$(grep -E "^ro\.miui\.ui\.version\.name=" "$prop" 2>/dev/null | head -n 1 | cut -d= -f2);
                if [ -n "$HOS_VAL" ]; then
                    IS_MIUI=1;
                    ROM_TYPE="Xiaomi HyperOS";
                    ROM_DETAIL="$HOS_VAL";
                    break;
                elif [ -n "$MIUI_VAL" ]; then
                    IS_MIUI=1;
                    ROM_TYPE="Xiaomi MIUI";
                    ROM_DETAIL="$MIUI_VAL";
                    break;
                fi;
            fi;
        done;
    fi;

    [ "$SYSTEM_MOUNTED" -eq 1 ] && { umount /s_chk 2>/dev/null; rm -rf /s_chk 2>/dev/null; };
fi;

ui_print "--------------------------------------";
if [ "$IS_OPLUS" -eq 1 ]; then
    rom_arg="rom_port";
    ui_print "  -> ROM Detected : ${ROM_TYPE:-ColorOS / OxygenOS Port}";
    [ -n "$ROM_DETAIL" ] && ui_print "  -> Details      : $ROM_DETAIL";
    ui_print "  -> Mode         : Universal OPlus Port Mode (rom_port)";
    ui_print "  -> Stub Drivers : OPlus Charging, Batt & Daemons Active";
elif [ "$IS_MIUI" -eq 1 ]; then
    rom_arg="rom_oem";
    ui_print "  -> ROM Detected : ${ROM_TYPE:-Xiaomi MIUI / HyperOS}";
    [ -n "$ROM_DETAIL" ] && ui_print "  -> Details      : $ROM_DETAIL";
    ui_print "  -> Mode         : Stock Mode (rom_oem)";
else
    rom_arg="rom_aosp";
    ui_print "  -> ROM Detected : ${ROM_TYPE:-AOSP / Custom ROM}";
    ui_print "  -> Mode         : AOSP Mode (rom_aosp)";
fi;
ui_print "--------------------------------------";

ui_print "- Flashing kernel...";
split_boot;
patch_cmdline "e404_args" "e404_args=${rom_arg:-rom_aosp},dtbo_oem,dtb_def,batt_def";
flash_boot;

chmod 644 /proc/oplusVersion/* 2>/dev/null
chmod 644 /proc/oplus_charger/* 2>/dev/null
chmod 666 /proc/theiaPwkReport 2>/dev/null
chmod 666 /proc/bootprof 2>/dev/null
chmod 666 /proc/storage/buf_log 2>/dev/null
chmod 666 /proc/oplus_storage/io_metrics/forever/* 2>/dev/null
chmod 666 /proc/oplus_scheduler/sched_assist/* 2>/dev/null
chmod 666 /proc/oplus_scheduler/sched_assist/audio/* 2>/dev/null
chmod 666 /proc/oplus_frame_boost/* 2>/dev/null
chmod 666 /proc/oplus_binder/* 2>/dev/null
chmod 666 /proc/sys/fbg/* 2>/dev/null
chmod 666 /proc/oplus_afs_config/afs_config 2>/dev/null
chmod 666 /proc/oplus_mem/memory_monitor 2>/dev/null
chmod 666 /proc/devinfo/lcd* 2>/dev/null
chmod 666 /sys/class/oplus_chg/*/* 2>/dev/null

ui_print " ";
ui_print "  ===========================================";
ui_print "  |       Ignis-Rei flashed successfully!   |";
ui_print "  ===========================================";
ui_print " ";
