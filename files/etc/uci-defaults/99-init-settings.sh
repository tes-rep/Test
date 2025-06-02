#!/bin/sh

exec > /root/setup-xidzwrt.log 2>&1

# Function untuk logging status
log_status() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function untuk check status command
check_status() {
    if [ $? -eq 0 ]; then
        log_status "SUCCESS: $1"
        return 0
    else
        log_status "ERROR: $1 failed"
        return 1
    fi
}

# Function untuk safe uci operations
uci_safe() {
    local action="$1"
    shift
    
    case "$action" in
        "set")
            uci set "$@" 2>/dev/null
            check_status "uci set $*"
            ;;
        "delete")
            uci -q delete "$@" 2>/dev/null
            check_status "uci delete $*"
            ;;
        "add_list")
            uci add_list "$@" 2>/dev/null
            check_status "uci add_list $*"
            ;;
        "commit")
            uci commit "$@" 2>/dev/null
            check_status "uci commit $*"
            ;;
    esac
}

# dont remove script !!!
log_status "Starting XIDZs-WRT setup script"
log_status "Installed Time: $(date '+%A, %d %B %Y %T')"

# Modify firmware version display
log_status "Modifying firmware version display"
sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' By Xidz_x':''),#g" /www/luci-static/resources/view/status/include/10_system.js
check_status "Firmware version display modification"

sed -i -E "s|icons/port_%s.png|icons/port_%s.gif|g" /www/luci-static/resources/view/status/include/29_ports.js
check_status "Port icons modification"

# Check and modify distribution info
if grep -q "ImmortalWrt" /etc/openwrt_release; then
    log_status "ImmortalWrt detected, modifying release info"
    sed -i "s/\(DISTRIB_DESCRIPTION='ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
    check_status "ImmortalWrt release info modification"
    
    sed -i 's|system/ttyd|services/ttyd|g' /usr/share/luci/menu.d/luci-app-ttyd.json
    check_status "TTYD menu modification"
    
    log_status "Branch version: $(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
elif grep -q "OpenWrt" /etc/openwrt_release; then
    log_status "OpenWrt detected, modifying release info"
    sed -i "s/\(DISTRIB_DESCRIPTION='OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
    check_status "OpenWrt release info modification"
    
    log_status "Branch version: $(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
fi

# Setup login root password
log_status "Setting up root password"
(echo "xyyraa"; sleep 2; echo "xyyraa") | passwd > /dev/null 2>&1
check_status "Root password setup"

# Setup hostname and timezone
log_status "Setting up hostname and timezone to Asia/Jakarta"
uci_safe set system.@system[0].hostname='XIDZs-WRT'
uci_safe set system.@system[0].timezone='WIB-7'
uci_safe set system.@system[0].zonename='Asia/Jakarta'
uci_safe delete system.ntp.server
uci_safe add_list system.ntp.server="pool.ntp.org"
uci_safe add_list system.ntp.server="id.pool.ntp.org"
uci_safe add_list system.ntp.server="time.google.com"
uci_safe commit system

# Setup default language
log_status "Setting up English as default language"
uci_safe set luci.@core[0].lang='en'
uci_safe commit luci

# Configure WAN and LAN
log_status "Configuring WAN and LAN interfaces"
uci_safe set network.wan=interface
uci_safe set network.wan.proto='dhcp'
uci_safe set network.wan.device='usb0'
uci_safe set network.modem=interface
uci_safe set network.modem.proto='dhcp'
uci_safe set network.modem.device='eth1'
uci_safe delete network.wan6
uci_safe commit network

# Configure firewall
log_status "Configuring firewall settings"
uci_safe set firewall.@defaults[0].input='ACCEPT'
uci_safe set firewall.@defaults[0].output='ACCEPT'
uci_safe set firewall.@defaults[0].forward='REJECT'
uci_safe set firewall.@zone[1].network='wan modem'
uci_safe commit firewall

# Disable IPv6 LAN
log_status "Disabling IPv6 LAN"
uci_safe delete dhcp.lan.dhcpv6
uci_safe delete dhcp.lan.ra
uci_safe delete dhcp.lan.ndp
uci_safe commit dhcp

# Configure wireless device
log_status "Configuring wireless device"
uci_safe set wireless.@wifi-device[0].disabled='0'
uci_safe set wireless.@wifi-iface[0].disabled='0'
uci_safe set wireless.@wifi-device[0].country='ID'
uci_safe set wireless.@wifi-device[0].htmode='HT40'
uci_safe set wireless.@wifi-iface[0].mode='ap'
uci_safe set wireless.@wifi-iface[0].encryption='none'
uci_safe set wireless.@wifi-device[0].channel='5'
uci_safe set wireless.@wifi-iface[0].ssid='XIDZs-WRT'

if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
    log_status "Raspberry Pi 4/3 detected, configuring dual-band WiFi"
    uci_safe set wireless.@wifi-device[1].disabled='0'
    uci_safe set wireless.@wifi-iface[1].disabled='0'
    uci_safe set wireless.@wifi-device[1].country='ID'
    uci_safe set wireless.@wifi-device[1].channel='149'
    uci_safe set wireless.@wifi-device[1].htmode='VHT80'
    uci_safe set wireless.@wifi-iface[1].mode='ap'
    uci_safe set wireless.@wifi-iface[1].ssid='XIDZs-WRT_5G'
    uci_safe set wireless.@wifi-iface[1].encryption='none'
fi

uci_safe commit wireless

wifi reload && wifi up
check_status "WiFi reload and activation"

if iw dev | grep -q Interface; then
    log_status "Wireless interface detected"
    if grep -q "Raspberry Pi 4\|Raspberry Pi 3" /proc/cpuinfo; then
        if ! grep -q "wifi up" /etc/rc.local; then
            sed -i '/exit 0/i # remove if you dont use wireless' /etc/rc.local
            sed -i '/exit 0/i sleep 10 && wifi up' /etc/rc.local
            check_status "WiFi startup script addition to rc.local"
        fi
        if ! grep -q "wifi up" /etc/crontabs/root; then
            echo "# remove if you dont use wireless" >> /etc/crontabs/root
            echo "0 */12 * * * wifi down && sleep 5 && wifi up" >> /etc/crontabs/root
            /etc/init.d/cron restart
            check_status "WiFi cron job setup"
        fi
    fi
else
    log_status "No wireless device detected"
fi

# Remove Huawei ME909S and DW5821E USB-modeswitch
log_status "Removing Huawei ME909S and DW5821E USB-modeswitch entries"
sed -i -e '/12d1:15c1/,+5d' -e '/413c:81d7/,+5d' /etc/usb-mode.json
check_status "USB-modeswitch entries removal"

# Disable XMM-modem
log_status "Disabling XMM-modem"
uci_safe set xmm-modem.@xmm-modem[0].enable='0'
uci_safe commit xmm-modem

# Disable opkg signature check
log_status "Disabling opkg signature check"
sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
check_status "Opkg signature check disable"

# Add custom repository
log_status "Adding custom repository"
if [ ! -f /etc/opkg/customfeeds.conf ] || ! grep -q "custom_packages" /etc/opkg/customfeeds.conf; then
    echo "src/gz custom_packages https://dl.openwrt.ai/latest/packages/$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')/kiddin9" >> /etc/opkg/customfeeds.conf
    check_status "Custom repository addition"
fi

# Setup default theme
log_status "Setting up Argon theme as default"
uci_safe set luci.main.mediaurlbase='/luci-static/argon'
uci_safe commit luci

# Remove login password for TTYD
log_status "Configuring TTYD without login password"
uci_safe set ttyd.@ttyd[0].command='/bin/bash --login'
uci_safe commit ttyd

# Symlink Tinyfm
log_status "Creating Tinyfm symlink"
if [ ! -L /www/tinyfm/rootfs ]; then
    ln -s / /www/tinyfm/rootfs
    check_status "Tinyfm symlink creation"
fi

# Setup Amlogic device
log_status "Setting up Amlogic device configuration"
if opkg list-installed | grep -q luci-app-amlogic; then
    log_status "luci-app-amlogic detected"
    rm -f /etc/profile.d/30-sysinfo.sh
    if ! grep -q "k5hgled\|k6hgled" /etc/rc.local; then
        sed -i '/exit 0/i #sleep 4 && /usr/bin/k5hgled -r' /etc/rc.local
        sed -i '/exit 0/i #sleep 4 && /usr/bin/k6hgled -r' /etc/rc.local
        check_status "Amlogic LED script addition"
    fi
else
    log_status "luci-app-amlogic not detected, cleaning up"
    rm -f /usr/bin/k5hgled /usr/bin/k6hgled /usr/bin/k5hgledon /usr/bin/k6hgledon
    check_status "Amlogic binaries cleanup"
fi

# Setup misc settings and permissions
log_status "Setting up miscellaneous settings and permissions"
sed -i -e 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' \
       -e 's/\[ -n "$FAILSAFE" \] && cat \/etc\/banner.failsafe/& || \/usr\/bin\/idz/' /etc/profile
check_status "Profile banner modification"

if [ -f /usr/lib/ModemManager/connection.d/10-report-down ]; then
    chmod +x /usr/lib/ModemManager/connection.d/10-report-down
    check_status "ModemManager script permissions"
fi

chmod -R +x /sbin /usr/bin 2>/dev/null
check_status "System binaries permissions"

if [ -f /www/vnstati/vnstati.sh ]; then
    chmod +x /www/vnstati/vnstati.sh
    check_status "vnstati script permissions"
fi

if [ -f /root/install2.sh ]; then
    chmod +x /root/install2.sh && /root/install2.sh
    check_status "install2.sh execution"
fi

# Move jQuery file
log_status "Moving jQuery file"
if [ -f /usr/share/netdata/web/lib/jquery-3.6.0.min.js ]; then
    mv /usr/share/netdata/web/lib/jquery-3.6.0.min.js /usr/share/netdata/web/lib/jquery-2.2.4.min.js
    check_status "jQuery file move"
fi

# Create vnstat directory
log_status "Creating vnstat directory"
if [ ! -d /etc/vnstat ]; then
    mkdir -p /etc/vnstat
    check_status "vnstat directory creation"
fi

# Restart services
log_status "Restarting netdata and vnstat services"
/etc/init.d/netdata restart 2>/dev/null && /etc/init.d/vnstat restart 2>/dev/null
check_status "Services restart"

# Run vnstati script
if [ -f /www/vnstati/vnstati.sh ]; then
    log_status "Running vnstati.sh"
    /www/vnstati/vnstati.sh
    check_status "vnstati.sh execution"
fi

# Setup vnstat database backup
log_status "Setting up vnstat database backup"
if [ -f /etc/init.d/vnstat_backup ]; then
    chmod +x /etc/init.d/vnstat_backup && /etc/init.d/vnstat_backup enable
    check_status "vnstat backup setup"
fi

# Add TTL script
if [ -f /root/indowrt.sh ]; then
    log_status "Adding and running TTL script"
    chmod +x /root/indowrt.sh && /root/indowrt.sh
    check_status "TTL script execution"
fi

# Add port board.json
if [ -f /root/addport.sh ]; then
    log_status "Adding port board.json"
    chmod +x /root/addport.sh && /root/addport.sh
    check_status "Port board.json addition"
fi

# Setup tunnel applications
log_status "Checking and configuring tunnel applications"
for pkg in luci-app-openclash luci-app-nikki luci-app-passwall; do
    if opkg list-installed | grep -qw "$pkg"; then
        log_status "$pkg detected, configuring..."
        case "$pkg" in
            luci-app-openclash)
                if [ -f /etc/openclash/core/clash_meta ]; then
                    chmod +x /etc/openclash/core/clash_meta
                fi
                if [ -f /etc/openclash/Country.mmdb ]; then
                    chmod +x /etc/openclash/Country.mmdb
                fi
                chmod +x /etc/openclash/Geo* 2>/dev/null
                
                log_status "Patching OpenClash overview"
                if [ -f /usr/bin/patchoc.sh ]; then
                    bash /usr/bin/patchoc.sh
                    check_status "OpenClash patch execution"
                    
                    if ! grep -q "patchoc.sh" /etc/rc.local; then
                        sed -i '/exit 0/i #/usr/bin/patchoc.sh' /etc/rc.local 2>/dev/null
                    fi
                fi
                
                if [ ! -L /etc/openclash/cache.db ] && [ -f /etc/openclash/history/Quenx.db ]; then
                    ln -s /etc/openclash/history/Quenx.db /etc/openclash/cache.db
                fi
                if [ ! -L /etc/openclash/clash ] && [ -f /etc/openclash/core/clash_meta ]; then
                    ln -s /etc/openclash/core/clash_meta /etc/openclash/clash
                fi
                
                rm -f /etc/config/openclash
                rm -rf /etc/openclash/custom /etc/openclash/game_rules
                rm -f /usr/share/openclash/openclash_version.sh
                
                if [ -d /etc/openclash/rule_provider ]; then
                    find /etc/openclash/rule_provider -type f ! -name "*.yaml" -exec rm -f {} \;
                fi
                
                if [ -f /etc/config/openclash1 ]; then
                    mv /etc/config/openclash1 /etc/config/openclash 2>/dev/null
                fi
                check_status "OpenClash configuration"
                ;;
            luci-app-nikki)
                rm -rf /etc/nikki/run/providers
                chmod +x /etc/nikki/run/Geo* 2>/dev/null
                
                log_status "Symlinking Nikki to OpenClash"
                if [ -d /etc/openclash/proxy_provider ] && [ ! -L /etc/nikki/run/proxy_provider ]; then
                    ln -s /etc/openclash/proxy_provider /etc/nikki/run
                fi
                if [ -d /etc/openclash/rule_provider ] && [ ! -L /etc/nikki/run/rule_provider ]; then
                    ln -s /etc/openclash/rule_provider /etc/nikki/run
                fi
                
                uci_safe set alpha.@alpha[0].nikki='Disable'
                uci_safe commit alpha
                
                if [ -f /usr/lib/lua/luci/view/themes/argon/header.htm ]; then
                    sed -i '170d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                fi
                check_status "Nikki configuration"
                ;;
            luci-app-passwall)
                uci_safe set alpha.@alpha[0].passwall='Disable'
                uci_safe commit alpha
                
                if [ -f /usr/lib/lua/luci/view/themes/argon/header.htm ]; then
                    sed -i '171d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                fi
                check_status "Passwall configuration"
                ;;
        esac
    else
        log_status "$pkg not detected, cleaning up..."
        case "$pkg" in
            luci-app-openclash)
                rm -f /etc/config/openclash1
                rm -rf /etc/openclash /usr/share/openclash /usr/lib/lua/luci/view/openclash
                uci_safe set alpha.@alpha[0].openclash='Disable'
                uci_safe commit alpha
                
                if [ -f /usr/lib/lua/luci/view/themes/argon/header.htm ]; then
                    sed -i '167d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                    sed -i '187,190d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                fi
                check_status "OpenClash cleanup"
                ;;
            luci-app-nikki)
                rm -rf /etc/config/nikki /etc/nikki
                uci_safe set alpha.@alpha[0].nikki='Disable'
                uci_safe commit alpha
                
                if [ -f /usr/lib/lua/luci/view/themes/argon/header.htm ]; then
                    sed -i '168d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                fi
                check_status "Nikki cleanup"
                ;;
            luci-app-passwall)
                rm -f /etc/config/passwall
                uci_safe set alpha.@alpha[0].passwall='Disable'
                uci_safe commit alpha
                
                if [ -f /usr/lib/lua/luci/view/themes/argon/header.htm ]; then
                    sed -i '169d' /usr/lib/lua/luci/view/themes/argon/header.htm 2>/dev/null
                fi
                check_status "Passwall cleanup"
                ;;
        esac
    fi
done

# Setup uhttpd and PHP8
log_status "Setting up uhttpd and PHP8"
uci_safe set uhttpd.main.ubus_prefix='/ubus'
uci_safe set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci_safe set uhttpd.main.index_page='cgi-bin/luci'
uci_safe add_list uhttpd.main.index_page='index.html'
uci_safe add_list uhttpd.main.index_page='index.php'
uci_safe commit uhttpd

if [ -f /etc/php.ini ]; then
    sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 128M|g" /etc/php.ini
    sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
    check_status "PHP configuration"
fi

if [ ! -L /usr/bin/php ] && [ -f /usr/bin/php-cli ]; then
    ln -sf /usr/bin/php-cli /usr/bin/php
    check_status "PHP CLI symlink"
fi

if [ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ]; then
    ln -sf /usr/lib/php8 /usr/lib/php
    check_status "PHP8 library symlink"
fi

/etc/init.d/uhttpd restart
check_status "uhttpd restart"

log_status "All setup completed successfully"

# Cleanup
rm -rf /etc/uci-defaults/$(basename $0)
check_status "Script cleanup"

log_status "XIDZs-WRT setup script finished"
exit 0