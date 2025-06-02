#!/bin/sh

exec > /root/setup-xidzwrt.log 2>&1

# Fungsi logging dan status checking
log_status() {
    local status="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message"
}

check_status() {
    if [ $? -eq 0 ]; then
        log_status "SUCCESS" "$1"
        return 0
    else
        log_status "ERROR" "$1 failed"
        return 1
    fi
}

safe_uci() {
    local action="$1"
    shift
    
    case "$action" in
        "set")
            if uci -q get "$1" >/dev/null 2>&1 || uci set "$@"; then
                return 0
            else
                log_status "ERROR" "Failed to set UCI: $*"
                return 1
            fi
            ;;
        "delete")
            if uci -q get "$1" >/dev/null 2>&1; then
                uci delete "$@"
                return $?
            else
                log_status "INFO" "UCI path does not exist: $1"
                return 0
            fi
            ;;
        "add_list")
            uci add_list "$@"
            return $?
            ;;
        "commit")
            uci commit "$@"
            return $?
            ;;
        *)
            log_status "ERROR" "Unknown UCI action: $action"
            return 1
            ;;
    esac
}

# dont remove script !!!
log_status "INFO" "Setup XIDZs-WRT Started"
log_status "INFO" "Script By Xidz-x | Fidz"
echo "Installed Time: $(date '+%A, %d %B %Y %T')"

# Modifikasi tampilan firmware
log_status "INFO" "Modifying firmware display"
if [ -f "/www/luci-static/resources/view/status/include/10_system.js" ]; then
    sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' By Xidz_x':''),#g" /www/luci-static/resources/view/status/include/10_system.js
    check_status "Firmware display modification"
fi

if [ -f "/www/luci-static/resources/view/status/include/29_ports.js" ]; then
    sed -i -E "s|icons/port_%s.png|icons/port_%s.gif|g" /www/luci-static/resources/view/status/include/29_ports.js
    check_status "Port icons modification"
fi

# Deteksi dan setup berdasarkan distribusi
if [ -f "/etc/openwrt_release" ]; then
    if grep -q "ImmortalWrt" /etc/openwrt_release; then
        log_status "INFO" "ImmortalWrt detected"
        sed -i "s/\(DISTRIB_DESCRIPTION='ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
        if [ -f "/usr/share/luci/menu.d/luci-app-ttyd.json" ]; then
            sed -i 's|system/ttyd|services/ttyd|g' /usr/share/luci/menu.d/luci-app-ttyd.json
        fi
        echo Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
    elif grep -q "OpenWrt" /etc/openwrt_release; then
        log_status "INFO" "OpenWrt detected"
        sed -i "s/\(DISTRIB_DESCRIPTION='OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
        echo Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
    fi
fi

# Setup login root password
log_status "INFO" "Setting up root password"
if command -v passwd >/dev/null 2>&1; then
    (echo "xyyraa"; sleep 2; echo "xyyraa") | passwd > /dev/null 2>&1
    check_status "Root password setup"
fi

# Setup hostname dan timezone
log_status "INFO" "Setting up hostname and timezone"
safe_uci set system.@system[0].hostname='XIDZs-WRT'
safe_uci set system.@system[0].timezone='WIB-7'
safe_uci set system.@system[0].zonename='Asia/Jakarta'
safe_uci delete system.ntp.server
safe_uci add_list system.ntp.server="pool.ntp.org"
safe_uci add_list system.ntp.server="id.pool.ntp.org"
safe_uci add_list system.ntp.server="time.google.com"
safe_uci commit system
check_status "Hostname and timezone setup"

# Setup bahasa default
log_status "INFO" "Setting up default language"
safe_uci set luci.@core[0].lang='en'
safe_uci commit luci
check_status "Default language setup"

# Configure WAN dan LAN
log_status "INFO" "Configuring WAN and LAN"
safe_uci set network.wan=interface
safe_uci set network.wan.proto='dhcp'
safe_uci set network.wan.device='usb0'
safe_uci set network.modem=interface
safe_uci set network.modem.proto='dhcp'
safe_uci set network.modem.device='eth1'
safe_uci delete network.wan6
safe_uci commit network
check_status "Network configuration"

# Configure firewall
log_status "INFO" "Configuring firewall"
safe_uci set firewall.@defaults[0].input='ACCEPT'
safe_uci set firewall.@defaults[0].output='ACCEPT'
safe_uci set firewall.@defaults[0].forward='REJECT'
safe_uci set firewall.@zone[1].network='wan modem'
safe_uci commit firewall
check_status "Firewall configuration"

# Disable IPv6 LAN
log_status "INFO" "Disabling IPv6 LAN"
safe_uci delete dhcp.lan.dhcpv6
safe_uci delete dhcp.lan.ra
safe_uci delete dhcp.lan.ndp
safe_uci commit dhcp
check_status "IPv6 LAN disable"

# Configure wireless device
log_status "INFO" "Configuring wireless device"
if uci -q get wireless.@wifi-device[0] >/dev/null 2>&1; then
    safe_uci set wireless.@wifi-device[0].disabled='0'
    safe_uci set wireless.@wifi-iface[0].disabled='0'
    safe_uci set wireless.@wifi-device[0].country='ID'
    safe_uci set wireless.@wifi-device[0].htmode='HT20'
    safe_uci set wireless.@wifi-iface[0].mode='ap'
    safe_uci set wireless.@wifi-iface[0].encryption='none'
    safe_uci set wireless.@wifi-device[0].channel='5'
    safe_uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT'
    
    if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo && uci -q get wireless.@wifi-device[1] >/dev/null 2>&1; then
        log_status "INFO" "Configuring dual-band wireless for Raspberry Pi"
        safe_uci set wireless.@wifi-device[1].disabled='0'
        safe_uci set wireless.@wifi-iface[1].disabled='0'
        safe_uci set wireless.@wifi-device[1].country='ID'
        safe_uci set wireless.@wifi-device[1].channel='149'
        safe_uci set wireless.@wifi-device[1].htmode='VHT80'
        safe_uci set wireless.@wifi-iface[1].mode='ap'
        safe_uci set wireless.@wifi-iface[1].ssid='XIDZs-WRT_5G'
        safe_uci set wireless.@wifi-iface[1].encryption='none'
    fi
    
    safe_uci commit wireless
    check_status "Wireless configuration"
    
    # Reload wireless
    if command -v wifi >/dev/null 2>&1; then
        wifi reload
        if [ $? -ne 0 ]; then
            log_status "WARNING" "Error reloading wireless, trying individual up/down"
            wifi down
            sleep 2
            wifi up
        fi
        
        wifi reload && wifi up
        
        if command -v iw >/dev/null 2>&1 && iw dev | grep -q Interface; then
            log_status "SUCCESS" "Wireless interface detected"
            if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
                if [ -f "/etc/rc.local" ] && ! grep -q "wifi up" /etc/rc.local; then
                    sed -i '/exit 0/i # remove if you dont use wireless' /etc/rc.local
                    sed -i '/exit 0/i sleep 10 && wifi up' /etc/rc.local
                fi
                if [ -f "/etc/crontabs/root" ] && ! grep -q "wifi up" /etc/crontabs/root; then
                    echo "# remove if you dont use wireless" >> /etc/crontabs/root
                    echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root
                    if [ -f "/etc/init.d/cron" ]; then
                        /etc/init.d/cron restart
                    fi
                fi
            fi
        else
            log_status "INFO" "No wireless device detected"
        fi
    fi
else
    log_status "INFO" "No wireless configuration found"
fi

# Remove Huawei ME909S dan DW5821E USB-modeswitch
log_status "INFO" "Removing Huawei ME909S and DW5821E USB-modeswitch"
if [ -f "/etc/usb-mode.json" ]; then
    sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json
    check_status "USB-modeswitch removal"
fi

# Disable xmm-modem
log_status "INFO" "Disabling xmm-modem"
if uci -q get xmm-modem.@xmm-modem[0] >/dev/null 2>&1; then
    safe_uci set xmm-modem.@xmm-modem[0].enable='0'
    safe_uci commit xmm-modem
    check_status "XMM-modem disable"
fi

# Disable opkg signature check
log_status "INFO" "Disabling opkg signature check"
if [ -f "/etc/opkg.conf" ]; then
    sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
    check_status "OPKG signature check disable"
fi

# Add custom repository
log_status "INFO" "Adding custom repository"
if [ -f "/etc/os-release" ] && grep -q "OPENWRT_ARCH" /etc/os-release; then
    ARCH=$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')
    if [ -n "$ARCH" ]; then
        echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/${ARCH}/kiddin9" >> /etc/opkg/customfeeds.conf
        check_status "Custom repository addition"
    fi
fi

# Setup default theme
log_status "INFO" "Setting up Argon theme"
safe_uci set luci.main.mediaurlbase='/luci-static/argon'
safe_uci commit luci
check_status "Argon theme setup"

# Remove login password ttyd
log_status "INFO" "Configuring ttyd"
if uci -q get ttyd.@ttyd[0] >/dev/null 2>&1; then
    safe_uci set ttyd.@ttyd[0].command='/bin/bash --login'
    safe_uci commit ttyd
    check_status "TTYD configuration"
fi

# Symlink Tinyfm
log_status "INFO" "Setting up TinyFM symlink"
if [ -d "/www/tinyfm" ]; then
    ln -sf / /www/tinyfm/rootfs
    check_status "TinyFM symlink creation"
fi

# Setup device amlogic
log_status "INFO" "Setting up Amlogic device configuration"
if command -v opkg >/dev/null 2>&1 && opkg list-installed | grep -q luci-app-amlogic; then
    log_status "INFO" "luci-app-amlogic detected"
    [ -f "/etc/profile.d/30-sysinfo.sh" ] && rm -f /etc/profile.d/30-sysinfo.sh
    if [ -f "/etc/rc.local" ]; then
        sed -i '/exit 0/i #sleep 4 && /usr/bin/k5hgled -r' /etc/rc.local
        sed -i '/exit 0/i #sleep 4 && /usr/bin/k6hgled -r' /etc/rc.local
    fi
else
    log_status "INFO" "luci-app-amlogic not detected"
    rm -f /usr/bin/k5hgled /usr/bin/k6hgled /usr/bin/k5hgledon /usr/bin/k6hgledon
fi

# Setup misc settings and permission
log_status "INFO" "Setting up misc settings and permissions"
if [ -f "/etc/profile" ]; then
    sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' \
           -e 's/\[ -n "$FAILSAFE" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/idz/' /etc/profile
fi

# Set permissions
for dir in /sbin /usr/bin; do
    [ -d "$dir" ] && chmod -R +x "$dir"
done

[ -f "/usr/lib/ModemManager/connection.d/10-report-down" ] && chmod +x /usr/lib/ModemManager/connection.d/10-report-down
[ -f "/www/vnstati/vnstati.sh" ] && chmod +x /www/vnstati/vnstati.sh
[ -f "/root/install2.sh" ] && chmod +x /root/install2.sh && /root/install2.sh

check_status "Misc settings and permissions"

# Move jquery.min.js
log_status "INFO" "Moving jQuery library"
if [ -f "/usr/share/netdata/web/lib/jquery-3.6.0.min.js" ]; then
    mv /usr/share/netdata/web/lib/jquery-3.6.0.min.js /usr/share/netdata/web/lib/jquery-2.2.4.min.js
    check_status "jQuery library move"
fi

# Create directory vnstat
log_status "INFO" "Creating VnStat directory"
[ ! -d "/etc/vnstat" ] && mkdir -p /etc/vnstat
check_status "VnStat directory creation"

# Restart netdata and vnstat
log_status "INFO" "Restarting NetData and VnStat services"
for service in netdata vnstat; do
    if [ -f "/etc/init.d/$service" ]; then
        /etc/init.d/$service restart
        check_status "$service restart"
    fi
done

# Run vnstati.sh
log_status "INFO" "Running VnStati script"
if [ -x "/www/vnstati/vnstati.sh" ]; then
    /www/vnstati/vnstati.sh
    check_status "VnStati script execution"
fi

# Setup Auto Vnstat Database Backup
log_status "INFO" "Setting up VnStat database backup"
if [ -f "/etc/init.d/vnstat_backup" ]; then
    chmod +x /etc/init.d/vnstat_backup && /etc/init.d/vnstat_backup enable
    check_status "VnStat backup setup"
fi

# Add TTL
log_status "INFO" "Setting up TTL script"
if [ -f "/root/indowrt.sh" ]; then
    chmod +x /root/indowrt.sh && /root/indowrt.sh
    check_status "TTL script execution"
fi

# Add port board.json
log_status "INFO" "Adding port configuration"
if [ -f "/root/addport.sh" ]; then
    chmod +x /root/addport.sh && /root/addport.sh
    check_status "Port configuration"
fi

# Setup tunnel applications
log_status "INFO" "Configuring tunnel applications"
for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
    if command -v opkg >/dev/null 2>&1 && opkg list-installed | grep -qw "$pkg"; then
        log_status "INFO" "$pkg detected"
        case "$pkg" in
            luci-app-openclash)
                [ -f "/etc/openclash/core/clash_meta" ] && chmod +x /etc/openclash/core/clash_meta
                [ -f "/etc/openclash/Country.mmdb" ] && chmod +x /etc/openclash/Country.mmdb
                find /etc/openclash -name "Geo*" -type f -exec chmod +x {} \; 2>/dev/null
                
                if [ -f "/usr/bin/patchoc.sh" ]; then
                    log_status "INFO" "Patching OpenClash overview"
                    bash /usr/bin/patchoc.sh
                    if [ -f "/etc/rc.local" ]; then
                        sed -i '/exit 0/i #/usr/bin/patchoc.sh' /etc/rc.local 2>/dev/null
                    fi
                fi
                
                [ -f "/etc/openclash/history/Quenx.db" ] && ln -sf /etc/openclash/history/Quenx.db /etc/openclash/cache.db
                [ -f "/etc/openclash/core/clash_meta" ] && ln -sf /etc/openclash/core/clash_meta /etc/openclash/clash
                
                # Cleanup
                rm -f /etc/config/openclash
                rm -rf /etc/openclash/custom /etc/openclash/game_rules
                rm -f /usr/share/openclash/openclash_version.sh
                
                if [ -d "/etc/openclash/rule_provider" ]; then
                    find /etc/openclash/rule_provider -type f ! -name "*.yaml" -exec rm -f {} \;
                fi
                
                [ -f "/etc/config/openclash1" ] && mv /etc/config/openclash1 /etc/config/openclash 2>/dev/null
                ;;
            luci-app-nikki)
                rm -rf /etc/nikki/run/providers
                find /etc/nikki/run -name "Geo*" -type f -exec chmod +x {} \; 2>/dev/null
                log_status "INFO" "Symlinking Nikki to OpenClash"
                
                [ -d "/etc/openclash/proxy_provider" ] && ln -sf /etc/openclash/proxy_provider /etc/nikki/run
                [ -d "/etc/openclash/rule_provider" ] && ln -sf /etc/openclash/rule_provider /etc/nikki/run
                
                if [ -f "/etc/config/alpha" ]; then
                    sed -i '64s/Enable/Disable/' /etc/config/alpha
                fi
                if [ -f "/usr/lib/lua/luci/view/themes/argon/header.htm" ]; then
                    sed -i '171s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                fi
                ;;
            luci-app-passwall)
                if [ -f "/etc/config/alpha" ]; then
                    sed -i '88s/Enable/Disable/' /etc/config/alpha
                fi
                if [ -f "/usr/lib/lua/luci/view/themes/argon/header.htm" ]; then
                    sed -i '172s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                fi
                ;;
        esac
        check_status "$pkg configuration"
    else
        log_status "INFO" "$pkg not detected - cleaning up"
        case "$pkg" in
            luci-app-openclash)
                rm -f /etc/config/openclash1
                rm -rf /etc/openclash /usr/share/openclash /usr/lib/lua/luci/view/openclash
                if [ -f "/etc/config/alpha" ]; then
                    sed -i '104s/Enable/Disable/' /etc/config/alpha
                fi
                if [ -f "/usr/lib/lua/luci/view/themes/argon/header.htm" ]; then
                    sed -i '167s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                    sed -i '187s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                    sed -i '189s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                fi
                ;;
            luci-app-nikki)
                rm -rf /etc/config/nikki /etc/nikki
                if [ -f "/etc/config/alpha" ]; then
                    sed -i '120s/Enable/Disable/' /etc/config/alpha
                fi
                if [ -f "/usr/lib/lua/luci/view/themes/argon/header.htm" ]; then
                    sed -i '168s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                fi
                ;;
            luci-app-passwall)
                rm -f /etc/config/passwall
                if [ -f "/etc/config/alpha" ]; then
                    sed -i '136s/Enable/Disable/' /etc/config/alpha
                fi
                if [ -f "/usr/lib/lua/luci/view/themes/argon/header.htm" ]; then
                    sed -i '169s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm
                fi
                ;;
        esac
        check_status "$pkg cleanup"
    fi
done

# Setup uhttpd dan PHP8
log_status "INFO" "Setting up uhttpd and PHP8"
safe_uci set uhttpd.main.ubus_prefix='/ubus'
safe_uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
safe_uci set uhttpd.main.index_page='cgi-bin/luci'
safe_uci add_list uhttpd.main.index_page='index.html'
safe_uci add_list uhttpd.main.index_page='index.php'
safe_uci commit uhttpd

if [ -f "/etc/php.ini" ]; then
    sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 128M|g" /etc/php.ini
    sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
fi

[ -f "/usr/bin/php-cli" ] && ln -sf /usr/bin/php-cli /usr/bin/php
[ -d "/usr/lib/php8" ] && [ ! -d "/usr/lib/php" ] && ln -sf /usr/lib/php8 /usr/lib/php

if [ -f "/etc/init.d/uhttpd" ]; then
    /etc/init.d/uhttpd restart
    check_status "uhttpd and PHP8 setup"
fi

log_status "SUCCESS" "All setup completed successfully"

# Cleanup
SCRIPT_NAME=$(basename "$0")
if [ -f "/etc/uci-defaults/$SCRIPT_NAME" ]; then
    rm -rf "/etc/uci-defaults/$SCRIPT_NAME"
    log_status "INFO" "Cleanup completed"
fi

# Sync filesystem sebelum reboot
log_status "INFO" "Syncing filesystem before reboot"
sync
sleep 2

# Reboot system
log_status "INFO" "Rebooting system in 3 seconds..."
echo "System will reboot in 5 seconds to apply all changes..."
sleep 3

if command -v reboot >/dev/null 2>&1; then
    log_status "INFO" "Initiating system reboot"
    reboot
else
    log_status "ERROR" "Reboot command not found, manual reboot required"
fi

exit 0