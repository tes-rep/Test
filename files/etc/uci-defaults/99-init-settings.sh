#!/bin/sh

# Setup logging
LOG_FILE="/root/setup-hj_wrt.log"
exec > "$LOG_FILE" 2>&1

# Fungsi untuk logging dengan status
log_status() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$status" in
        "INFO")
            echo "[$timestamp] [INFO] $message"
            ;;
        "SUCCESS")
            echo "[$timestamp] [SUCCESS] ✓ $message"
            ;;
        "ERROR")
            echo "[$timestamp] [ERROR] ✗ $message"
            ;;
        "WARNING")
            echo "[$timestamp] [WARNING] ⚠ $message"
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
}

# Fungsi untuk check status command
check_status() {
    local command="$1"
    local description="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        log_status "SUCCESS" "$description"
        return 0
    else
        log_status "ERROR" "$description - Command failed: $command"
        return 1
    fi
}

# Header log
log_status "INFO" "========================================="
log_status "INFO" "HJ-WRT Setup Script Started"
log_status "INFO" "Script Setup By HOUJIE | HJ"
log_status "INFO" "Installed Time: $(date '+%A, %d %B %Y %T')"
log_status "INFO" "========================================="

# dont remove script !!!
log_status "INFO" "Modifying firmware display..."
check_status "sed -i -E 's|icons/port_%s.png|icons/port_%s.gif|g' /www/luci-static/resources/view/status/include/29_ports.js" "Port icons changed from PNG to GIF"

# Check system release
log_status "INFO" "Checking system release..."
if grep -q "ImmortalWrt" /etc/openwrt_release; then
    log_status "INFO" "ImmortalWrt detected"
    check_status "sed -i 's/\(DISTRIB_DESCRIPTION='\''ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release" "ImmortalWrt release description cleaned"
    check_status "sed -i 's|system/ttyd|services/ttyd|g' /usr/share/luci/menu.d/luci-app-ttyd.json" "TTYD menu moved to services"
    BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
    log_status "INFO" "Branch version: $BRANCH_VERSION"
elif grep -q "OpenWrt" /etc/openwrt_release; then
    log_status "INFO" "OpenWrt detected"
    check_status "sed -i 's/\(DISTRIB_DESCRIPTION='\''OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'\''/\1'\''/g' /etc/openwrt_release" "OpenWrt release description cleaned"
    BRANCH_VERSION=$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')
    log_status "INFO" "Branch version: $BRANCH_VERSION"
else
    log_status "WARNING" "Unknown system release"
fi

# setup login root password
log_status "INFO" "Setting up root password..."
if (echo "sijitekowolu"; sleep 2; echo "sijitekowolu") | passwd > /dev/null 2>&1; then
    log_status "SUCCESS" "Root password configured"
else
    log_status "ERROR" "Failed to set root password"
fi

# setup hostname and timezone
log_status "INFO" "Configuring hostname and timezone to Asia/Jakarta..."
check_status "uci set system.@system[0].hostname='HOUJIE-WRT'" "Hostname set to XIDZs-WRT"
check_status "uci set system.@system[0].timezone='WIB-7'" "Timezone set to WIB-7"
check_status "uci set system.@system[0].zonename='Asia/Jakarta'" "Zone name set to Asia/Jakarta"
check_status "uci delete system.ntp.server" "Existing NTP servers cleared"
check_status "uci add_list system.ntp.server='pool.ntp.org'" "Added pool.ntp.org NTP server"
check_status "uci add_list system.ntp.server='id.pool.ntp.org'" "Added id.pool.ntp.org NTP server"
check_status "uci add_list system.ntp.server='time.google.com'" "Added time.google.com NTP server"
check_status "uci commit system" "System configuration committed"

# setup bahasa default
log_status "INFO" "Setting up default language to English..."
check_status "uci set luci.@core[0].lang='en'" "Language set to English"
check_status "uci commit luci" "LuCI language configuration committed"

# configure wan and lan
log_status "INFO" "Configuring WAN and LAN interfaces..."
check_status "uci set network.tethering=interface" "Tethering interface created"
check_status "uci set network.tethering.proto='dhcp'" "Tethering protocol set to DHCP"
check_status "uci set network.tethering.device='usb0'" "Tethering device set to usb0"
check_status "uci set network.modem=interface" "Modem interface created"
check_status "uci set network.modem.proto='dhcp'" "Modem protocol set to DHCP"
check_status "uci set network.modem.device='eth1'" "Modem device set to eth1"
check_status "uci delete network.wan6" "delete wan6"
check_status "uci commit network" "Network configuration committed"

log_status "INFO" "Configuring firewall..."
check_status "uci set firewall.@zone[1].network='tethering modem'" "Firewall zone configured for TETHERING and MODEM"
check_status "uci commit firewall" "Firewall configuration committed"

# disable ipv6 lan
log_status "INFO" "Disabling IPv6 on LAN..."
check_status "uci delete dhcp.lan.dhcpv6" "DHCPv6 disabled on LAN"
check_status "uci delete dhcp.lan.ra" "Router Advertisement disabled on LAN"
check_status "uci delete dhcp.lan.ndp" "NDP disabled on LAN"
check_status "uci commit dhcp" "DHCP configuration committed"

# configure wireless device
log_status "INFO" "Configuring wireless devices..."
check_status "uci set wireless.@wifi-device[0].disabled='0'" "WiFi device 0 enabled"
check_status "uci set wireless.@wifi-iface[0].disabled='0'" "WiFi interface 0 enabled"
check_status "uci set wireless.@wifi-device[0].country='ID'" "WiFi country set to Indonesia"
check_status "uci set wireless.@wifi-iface[0].mode='ap'" "WiFi mode set to Access Point"
check_status "uci set wireless.@wifi-iface[0].encryption='none'" "WiFi encryption disabled"

# Check for Raspberry Pi
if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
    log_status "INFO" "Raspberry Pi 3/4 detected, configuring 5GHz WiFi..."
    check_status "uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT_5G'" "5GHz WiFi SSID set to XIDZs-WRT_5G"
    check_status "uci set wireless.@wifi-device[0].channel='149'" "5GHz WiFi channel set to 149"
    check_status "uci set wireless.@wifi-device[0].htmode='VHT80'" "5GHz WiFi HT mode set to VHT80"
else
    check_status "uci set wireless.@wifi-iface[0].ssid='XIDZs-WRT'" "WiFi SSID set to XIDZs-WRT"
    check_status "uci set wireless.@wifi-device[0].channel='1'" "WiFi channel set to 1"
    check_status "uci set wireless.@wifi-device[0].htmode='HT20'" "WiFi HT mode set to HT20"
    log_status "INFO" "Raspberry Pi 3/4 not detected, skipping 5GHz configuration"
fi

check_status "uci commit wireless" "Wireless configuration committed"
check_status "wifi reload && wifi up" "WiFi reloaded and started"

# Check wireless interface
if iw dev | grep -q Interface; then
    log_status "SUCCESS" "Wireless interface detected"
    if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
        if ! grep -q "wifi up" /etc/rc.local; then
            check_status "sed -i '/exit 0/i # remove if you dont use wireless' /etc/rc.local" "Added WiFi comment to rc.local"
            check_status "sed -i '/exit 0/i sleep 10 && wifi up' /etc/rc.local" "Added WiFi startup command to rc.local"
        fi
        if ! grep -q "wifi up" /etc/crontabs/root; then
            if echo "# remove if you dont use wireless" >> /etc/crontabs/root && echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root; then
                log_status "SUCCESS" "WiFi cron job added"
                check_status "/etc/init.d/cron restart" "Cron service restarted"
            else
                log_status "ERROR" "Failed to add WiFi cron job"
            fi
        fi
    fi
else
    log_status "WARNING" "No wireless device detected"
fi

# remove huawei me909s and dw5821e usb-modeswitch
log_status "INFO" "Removing Huawei ME909S and DW5821E USB modeswitch entries..."
check_status "sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json" "USB modeswitch entries removed"

# create file konfigurasi xmm-modem
log_status "INFO" "Disabling XMM-Modem using UCI"
check_status "uci set xmm-modem.@xmm-modem[0].enable='0'" "Disable xmm-modem"
check_status "uci commit xmm-modem" "disable xmm-modem commited"

# setup default theme
log_status "INFO" "Setting up Argon theme as default..."
check_status "uci set luci.main.mediaurlbase='/luci-static/hj'" "hj theme set as default"
check_status "uci commit luci" "LuCI theme configuration committed"

# remove login password ttyd
log_status "INFO" "Configuring TTYD without login password..."
check_status "uci set ttyd.@ttyd[0].command='/bin/bash --login'" "TTYD login password removed"
check_status "uci commit ttyd" "TTYD configuration committed"

# symlink Tinyfm
log_status "INFO" "Creating TinyFM symlink..."
check_status "ln -s / /www/tinyfm/rootfs" "TinyFM rootfs symlink created"

# setup misc settings and permission
log_status "INFO" "Setting up miscellaneous settings and permissions..."
#check_status "sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' -e 's/\[ -n \"\$FAILSAFE\" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/idz/' /etc/profile" "Profile banner configuration modified"
check_status "chmod +x /usr/lib/ModemManager/connection.d/10-report-down" "ModemManager script permissions set"
check_status "chmod -R +x /sbin /usr/bin" "Binary directories permissions set"
check_status "chmod +x /www/vnstati/vnstati.sh" "VnStati script permissions set"

if [ -f /root/install2.sh ]; then
    check_status "chmod +x /root/install2.sh && /root/install2.sh" "Secondary installation script executed"
else
    log_status "WARNING" "install2.sh not found, skipping"
fi

# move jquery.min.js
log_status "INFO" "Moving jQuery library..."
check_status "mv /usr/share/netdata/web/lib/jquery-3.6.0.min.js /usr/share/netdata/web/lib/jquery-2.2.4.min.js" "jQuery library version changed"

# restart netdata and vnstat
log_status "INFO" "Restarting Netdata and VnStat services..."
#check_status "/etc/init.d/netdata restart" "Netdata service restarted"
check_status "/etc/init.d/vnstat restart" "VnStat service restarted"

# run vnstati.sh
log_status "INFO" "Running VnStati script..."
check_status "/www/vnstati/vnstati.sh" "VnStati script executed"


# add TTL
log_status "INFO" "Adding and running TTL script..."
if [ -f /root/indowrt.sh ]; then
    check_status "chmod +x /root/indowrt.sh && /root/indowrt.sh" "TTL script executed"
else
    log_status "WARNING" "indowrt.sh not found, skipping TTL configuration"
fi

# add port board.json
log_status "INFO" "Adding port configuration..."
if [ -f /root/addport.sh ]; then
    check_status "chmod +x /root/addport.sh && /root/addport.sh" "Port configuration script executed"
else
    log_status "WARNING" "addport.sh not found, skipping port configuration"
fi

# setup tunnel installed
log_status "INFO" "Checking for tunnel applications..."
for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
    if opkg list-installed | grep -qw "$pkg"; then
        log_status "INFO" "$pkg detected"
        case "$pkg" in
            luci-app-openclash)
                check_status "chmod +x /etc/openclash/core/clash_meta" "OpenClash core permissions set"
                check_status "chmod +x /etc/openclash/Country.mmdb" "OpenClash Country.mmdb permissions set"
                check_status "chmod +x /etc/openclash/Geo* 2>/dev/null || true" "OpenClash Geo files permissions set"
                
                log_status "INFO" "Patching OpenClash overview..."
                if [ -f /usr/bin/patchoc.sh ]; then
                    check_status "bash /usr/bin/patchoc.sh" "OpenClash overview patched"
                    check_status "sed -i '/exit 0/i #/usr/bin/patchoc.sh' /etc/rc.local 2>/dev/null || true" "OpenClash patch added to rc.local"
                else
                    log_status "WARNING" "patchoc.sh not found"
                fi
                
                check_status "ln -sf /etc/openclash/history/Quenx.db /etc/openclash/cache.db" "OpenClash cache database symlink created"
                check_status "ln -sf /etc/openclash/core/clash_meta /etc/openclash/clash" "OpenClash binary symlink created"
                check_status "rm -f /etc/config/openclash" "Old OpenClash config removed"
                check_status "rm -rf /etc/openclash/custom /etc/openclash/game_rules" "OpenClash custom and game rules removed"
                check_status "rm -f /usr/share/openclash/openclash_version.sh" "OpenClash version script removed"
                check_status "find /etc/openclash/rule_provider -type f ! -name '*.yaml' -exec rm -f {} \;" "Non-YAML rule files removed"
                check_status "mv /etc/config/openclash1 /etc/config/openclash 2>/dev/null || true" "OpenClash configuration restored"
                ;;
            luci-app-nikki)
                check_status "rm -rf /etc/nikki/run/providers" "Nikki providers directory removed"
                check_status "chmod +x /etc/nikki/run/Geo* 2>/dev/null || true" "Nikki Geo files permissions set"
                log_status "INFO" "Creating symlinks from OpenClash to Nikki..."
                check_status "ln -sf /etc/openclash/proxy_provider /etc/nikki/run" "Nikki proxy provider symlink created"
                check_status "ln -sf /etc/openclash/rule_provider /etc/nikki/run" "Nikki rule provider symlink created"
                check_status "sed -i '64s/Enable/Disable/' /etc/config/alpha" "Alpha config updated for Nikki"
                check_status "sed -i '171s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header updated for Nikki"
                ;;
            luci-app-passwall)
                check_status "sed -i '88s/Enable/Disable/' /etc/config/alpha" "Alpha config updated for Passwall"
                check_status "sed -i '172s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header updated for Passwall"
                ;;
        esac
    else
        log_status "INFO" "$pkg not detected, cleaning up..."
        case "$pkg" in
            luci-app-openclash)
                check_status "rm -f /etc/config/openclash1" "OpenClash backup config removed"
                check_status "rm -rf /etc/openclash /usr/share/openclash /usr/lib/lua/luci/view/openclash" "OpenClash files and directories removed"
                check_status "sed -i '104s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (OpenClash disabled)"
                check_status "sed -i '167s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 167 removed"
                check_status "sed -i '187s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 187 removed"
                check_status "sed -i '189s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 189 removed"
                ;;
            luci-app-nikki)
                check_status "rm -rf /etc/config/nikki /etc/nikki" "Nikki config and directories removed"
                check_status "sed -i '120s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (Nikki disabled)"
                check_status "sed -i '168s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 168 removed"
                ;;
            luci-app-passwall)
                check_status "rm -f /etc/config/passwall" "Passwall config removed"
                check_status "sed -i '136s/Enable/Disable/' /etc/config/alpha" "Alpha config updated (Passwall disabled)"
                check_status "sed -i '169s#.*#<!-- & -->#' /usr/lib/lua/luci/view/themes/argon/header.htm" "Argon header line 169 removed"
                ;;
        esac
    fi
done

# Setup uhttpd and PHP8
log_status "INFO" "Configuring uhttpd and PHP8..."
check_status "uci set uhttpd.main.ubus_prefix='/ubus'" "uhttpd ubus prefix set"
check_status "uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'" "uhttpd PHP interpreter configured"
check_status "uci set uhttpd.main.index_page='cgi-bin/luci'" "uhttpd index page set to LuCI"
check_status "uci add_list uhttpd.main.index_page='index.html'" "Added index.html to uhttpd index pages"
check_status "uci add_list uhttpd.main.index_page='index.php'" "Added index.php to uhttpd index pages"
check_status "uci commit uhttpd" "uhttpd configuration committed"

check_status "sed -i -E 's|memory_limit = [0-9]+M|memory_limit = 128M|g' /etc/php.ini" "PHP memory limit set to 128M"
check_status "sed -i -E 's|display_errors = On|display_errors = Off|g' /etc/php.ini" "PHP display errors disabled"
check_status "ln -sf /usr/bin/php-cli /usr/bin/php" "PHP CLI symlink created"

if [ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ]; then
    check_status "ln -sf /usr/lib/php8 /usr/lib/php" "PHP8 library symlink created"
fi

check_status "/etc/init.d/uhttpd restart" "uhttpd service restarted"

log_status "INFO" "Configuring baner..."
check_status "rm -rf /etc/profile" "hapus progile"
check_status "rm -rf /etc/profile.d/30-sysinfo.sh" "hapus sysinfo"
check_status "mv /etc/profile1 /etc/profile" "rename profile"
check_status "mv /etc/profile.d/30-sysinfo1.sh /etc/profile.d/30-sysinfo.sh" "rename sysinfo"
check_status "chmod +x /etc/profile.d/30-sysinfo.sh" "beri ijin sysinfo"

log_status "INFO" "Configuring ipinfo..."
check_status "mv /www/luci-static/resources/view/status/include/01_ipinfo.js /www/luci-static/resources/view/status/include/11_ipinfo.js" "pindah ipinfo"

log_status "SUCCESS" "ijin"
check_status "chmod +x /etc/houjie-wrt" "Cleanup: removed script from uci-defaults"


log_status "SUCCESS" "All setup completed successfully"
check_status "rm -rf /etc/uci-defaults/$(basename $0)" "Cleanup: removed script from uci-defaults"

log_status "INFO" "========================================="
log_status "INFO" "HJ-WRT Setup Script Finished"
log_status "INFO" "Automatic system reboot"
log_status "INFO" "Check log file: $LOG_FILE"
log_status "INFO" "========================================="
check_status "sleep 5" "Waiting 5 Seconds"
check_status "reboot" "Reboot Devices"

exit 0
