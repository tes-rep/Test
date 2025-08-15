#!/bin/bash

. ./scripts/INCLUDE.sh

rename_firmware() {
    echo -e "${STEPS} Renaming firmware files..."

    # Direktori firmware
    local firmware_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    if [[ ! -d "$firmware_dir" ]]; then
        error_msg "Invalid firmware directory: ${firmware_dir}"
    fi

    # Direktori output: subfolder 'mod' di firmware_dir
    local output_dir="${firmware_dir}/mod"
    mkdir -p "$output_dir"

    # Pindah ke direktori firmware
    cd "${firmware_dir}" || { error_msg "Failed to change directory to ${firmware_dir}"; }

    # Pola pencarian dan penggantian lengkap
    local search_replace_patterns=(
        # bcm27xx
        "-bcm27xx-bcm2709-rpi-2-ext4-factory|RaspberryPi_2B-Ext4_Factory"
        "-bcm27xx-bcm2709-rpi-2-ext4-sysupgrade|RaspberryPi_2B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2709-rpi-2-squashfs-factory|RaspberryPi_2B-Squashfs_Factory"
        "-bcm27xx-bcm2709-rpi-2-squashfs-sysupgrade|RaspberryPi_2B-Squashfs_Sysupgrade"

        "-bcm27xx-bcm2710-rpi-3-ext4-factory|RaspberryPi_3B-Ext4_Factory"
        "-bcm27xx-bcm2710-rpi-3-ext4-sysupgrade|RaspberryPi_3B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2710-rpi-3-squashfs-factory|RaspberryPi_3B-Squashfs_Factory"
        "-bcm27xx-bcm2710-rpi-3-squashfs-sysupgrade|RaspberryPi_3B-Squashfs_Sysupgrade"

        "-bcm27xx-bcm2711-rpi-4-ext4-factory|RaspberryPi_4B-Ext4_Factory"
        "-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade|RaspberryPi_4B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2711-rpi-4-squashfs-factory|RaspberryPi_4B-Squashfs_Factory"
        "-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade|RaspberryPi_4B-Squashfs_Sysupgrade"

        "-bcm27xx-bcm2712-rpi-5-ext4-factory|RaspberryPi_5-Ext4_Factory"
        "-bcm27xx-bcm2712-rpi-5-ext4-sysupgrade|RaspberryPi_5-Ext4_Sysupgrade"
        "-bcm27xx-bcm2712-rpi-5-squashfs-factory|RaspberryPi_5-Squashfs_Factory"
        "-bcm27xx-bcm2712-rpi-5-squashfs-sysupgrade|RaspberryPi_5-Squashfs_Sysupgrade"

        # Allwinner ULO
        "-h5-orangepi-pc2-|OrangePi_PC2"
        "-h5-orangepi-prime-|OrangePi_Prime"
        "-h5-orangepi-zeroplus-|OrangePi_ZeroPlus"
        "-h5-orangepi-zeroplus2-|OrangePi_ZeroPlus2"
        "-h6-orangepi-1plus-|OrangePi_1Plus"
        "-h6-orangepi-3-|OrangePi_3"
        "-h6-orangepi-3lts-|OrangePi_3LTS"
        "-h6-orangepi-lite2-|OrangePi_Lite2"
        "-h616-orangepi-zero2-|OrangePi_Zero2"
        "-h618-orangepi-zero2w-|OrangePi_Zero2W"
        "-h618-orangepi-zero3-|OrangePi_Zero3"

        # Rockchip ULO
        "-rk3566-orangepi-3b-|OrangePi_3B"
        "-rk3588s-orangepi-5-|OrangePi_5"
        "-firefly_roc-rk3328-cc-|Firefly-RK3328"

        # Xunlong Official
        "-xunlong_orangepi-r1-plus-lts-squashfs-sysupgrade|OrangePi-R1-Plus-LTS-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-lts-ext4-sysupgrade|OrangePi-R1-Plus-LTS-ext4-sysupgrade"
        "-xunlong_orangepi-r1-plus-squashfs-sysupgrade|OrangePi-R1-Plus-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-ext4-sysupgrade|OrangePi-R1-Plus-ext4-sysupgrade" 
        "-xunlong_orangepi-pc2-squashfs-sdcard|OrangePi-Pc2-squashfs-sdcard"
        "-xunlong_orangepi-pc2-ext4-sdcard|OrangePi-Pc2-ext4-sdcard"
        "-xunlong_orangepi-zero-plus-squashfs-sdcard|OrangePi-Zero-Plus-squashfs-sdcard"
        "-xunlong_orangepi-zero-plus-ext4-sdcard|OrangePi-Zero-Plus-ext4-sdcard"
        "-xunlong_orangepi-zero2-squashfs-sdcard|OrangePi-Zero2-squashfs-sdcard"
        "-xunlong_orangepi-zero2-ext4-sdcard|OrangePi-Zero2-ext4-sdcard"   
        "-xunlong_orangepi-zero3-squashfs-sdcard|OrangePi-Zero3-squashfs-sdcard"
        "-xunlong_orangepi-zero3-ext4-sdcard|OrangePi-Zero3-ext4-sdcard"

        # friendlyarm Official
        "-friendlyarm_nanopi-r2c-ext4-sysupgrade|Nanopi-R2C-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-ext4-sysupgrade|Nanopi-R2C-Plus-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2s-ext4-sysupgrade|Nanopi-R2S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2s-plus-ext4-sysupgrade|Nanopi-R2S-Plus-ext4-sysupgrade"
        "-friendlyarm_nanopi-r3s-ext4-sysupgrade|Nanopi-R3S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r4s-ext4-sysupgrade|Nanopi-R4S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r5s-ext4-sysupgrade|Nanopi-R5S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r6s-ext4-sysupgrade|Nanopi-R6S-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo2-ext4-sysupgrade|Nanopi-Neo2-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-ext4-sysupgrade|Nanopi-Neo-Plus2-ext4-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-ext4-sysupgrade|Nanopi-R1-H5-ext4-sysupgrade"
        "-firefly_roc-rk3328-cc-ext4-sysupgrade|Firefly_Roc-RK3328-CC-ext4-sysupgrade"

        "-firefly_roc-rk3328-cc-squashfs-sysupgrade|Firefly_Roc-RK3328-CC-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-squashfs-sysupgrade|Nanopi-R2C-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-squashfs-sysupgrade|Nanopi-R2C-Plus-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2s-squashfs-sysupgrade|Nanopi-R2S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2s-plus-squashfs-sysupgrade|Nanopi-R2S-Plus-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r3s-squashfs-sysupgrade|Nanopi-R3S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r4s-squashfs-sysupgrade|Nanopi-R4S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r5s-squashfs-sysupgrade|Nanopi-R5S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r6s-squashfs-sysupgrade|Nanopi-R6S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo2-squashfs-sysupgrade|Nanopi-Neo2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-squashfs-sysupgrade|Nanopi-Neo-Plus2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-squashfs-sysupgrade|Nanopi-R1S-H5-squashfs-sysupgrade"

        # x86_64 Official
        "x86-64-generic-ext4-combined-efi|X86_64_Generic_Ext4_Combined_EFI"
        "x86-64-generic-ext4-combined|X86_64_Generic_Ext4_Combined"
        "x86-64-generic-ext4-rootfs|X86_64_Generic_Ext4_Rootfs"
        "x86-64-generic-squashfs-combined-efi|X86_64_Generic_Squashfs_Combined_EFI"
        "x86-64-generic-squashfs-combined|X86_64_Generic_Squashfs_Combined"
        "x86-64-generic-squashfs-rootfs|X86_64_Generic_Squashfs_Rootfs"
        "x86-64-generic-rootfs|X86_64_Generic_Rootfs"
    )

    # Loop rename & pindah
    for pattern in "${search_replace_patterns[@]}"; do
        local search="${pattern%%|*}"
        local replace="${pattern##*|}"

        for ext in img.gz tar.gz; do
            for file in *"${search}"*.$ext; do
                [[ -f "$file" ]] || continue

                local kernel=""
                if [[ "$file" =~ k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)? ]]; then
                    kernel="${BASH_REMATCH[0]}"
                fi

                local new_name
                if [[ -n "$kernel" && "$ext" == "img.gz" ]]; then
                    new_name="XIDZs-${OP_BASE}-${BRANCH}-${replace}-${kernel}-${TUNNEL}-${DATE}.img.gz"
                else
                    new_name="XIDZs-${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}-${DATE}.img.gz"
                fi

                echo -e "${INFO} Renaming: $file → $new_name"
                mv "$file" "$new_name" || { echo -e "${WARN} Failed to rename $file"; continue; }

                # Pindahkan ke folder mod
                mv "$new_name" "$output_dir/" || { echo -e "${WARN} Failed to move $new_name"; continue; }
            done
        done
    done

    sync && sleep 3
    echo -e "${INFO} Rename & move operation completed. Files are in $output_dir"
}

rename_firmware
