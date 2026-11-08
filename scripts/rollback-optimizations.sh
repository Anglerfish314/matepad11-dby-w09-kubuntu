#!/bin/bash
# 回退本机所有优化项（在平板上以 sudo 运行）
#   sudo bash /data/rollback-optimizations.sh <项目>
# 每一项都可单独执行，互不影响。

set -e

usage() {
    cat <<'EOF'
用法: sudo bash rollback-optimizations.sh <项目>

  data-noatime   /data 恢复 relatime
  autostart      恢复 Discover 通知和 geoclue 自启
  zram           关闭并移除 zram
  writeback      恢复默认脏页比例（20/10）
  all            全部回退
EOF
}

undo_data_noatime() {
    if [ -f /data/matepad-internal-storage.bak ]; then
        cp /data/matepad-internal-storage.bak /usr/local/sbin/matepad-internal-storage
        chmod 755 /usr/local/sbin/matepad-internal-storage
    else
        sed -i 's|mount -t ext4 -o noatime|mount -t ext4|' /usr/local/sbin/matepad-internal-storage
    fi
    mount -o remount,relatime /data 2>/dev/null || true
    grep ' /data ' /proc/mounts
    echo "[ok] /data 已恢复 relatime"
}

undo_autostart() {
    rm -f /home/matepad/.config/autostart/org.kde.discover.notifier.desktop
    rm -f /home/matepad/.config/autostart/geoclue-demo-agent.desktop
    echo "[ok] 已恢复 Discover 通知和 geoclue 自启（下次登录生效）"
}

undo_zram() {
    systemctl disable --now zramswap 2>/dev/null || true
    swapoff /dev/zram0 2>/dev/null || true
    rm -f /etc/default/zramswap
    rm -f /etc/sysctl.d/90-zram.conf
    sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
    echo "[ok] zram 已关闭（模块仍留在 /lib/modules，不影响启动）"
    swapon --show
}

undo_writeback() {
    rm -f /etc/sysctl.d/91-sd-writeback.conf
    sysctl -w vm.dirty_ratio=20 >/dev/null
    sysctl -w vm.dirty_background_ratio=10 >/dev/null
    sysctl -w vm.dirty_expire_centisecs=3000 >/dev/null
    echo "[ok] 脏页比例已恢复默认"
    sysctl vm.dirty_ratio vm.dirty_background_ratio 2>/dev/null
}

case "${1:-}" in
    data-noatime) undo_data_noatime ;;
    autostart)    undo_autostart ;;
    zram)         undo_zram ;;
    writeback)    undo_writeback ;;
    all)          undo_data_noatime; undo_autostart; undo_writeback; undo_zram ;;
    *)            usage ;;
esac
