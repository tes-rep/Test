#!/bin/bash

. ./scripts/INCLUDE.sh

#==============================
# Fungsi Repack Firmware
#==============================
repackwrt() {
    local builder_type=""
    local target_board=""
    local target_kernel=""
    local tunnel_type=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ophub|--ulo)
                builder_type="$1"
                shift
                ;;
            -t|--target)
                target_board="$2"
                shift 2
                ;;
            -k|--kernel)
                target_kernel="$2"
                shift 2
                ;;
            -tn|--tunnel)
                tunnel_type="$2"
                shift 2
                ;;
            *)
                error_msg "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validasi parameter
    [[ -z "$builder_type" ]] && { error_msg "Builder type required"; exit 1; }
    [[ -z "$target_board" ]] && { error_msg "Target board required"; exit 1; }
    [[ -z "$target_kernel" ]] && { error_msg "Target kernel required"; exit 1; }
    [[ -z "$tunnel_type" ]] && { error_msg "Tunnel type required"; exit 1; }

    # Direktori kerja
    local readonly OPHUB_REPO="https://github.com/tes-rep/amlogic-s9xxx-openwrt/archive/refs/heads/main.zip"
    local readonly ULO_REPO="https://github.com/xidz-repo/ULO-Builder/archive/refs/heads/main.zip"
    local readonly work_dir="$GITHUB_WORKSPACE/$WORKING_DIR"

    local builder_dir output_dir repo_url
    if [[ "$builder_type" == "--ophub" ]]; then
        builder_dir="${work_dir}/amlogic-s9xxx-openwrt-main"
        repo_url="${OPHUB_REPO}"
        log "STEPS" "Starting firmware repackaging with Ophub..."
    else
        builder_dir="${work_dir}/ULO-Builder-main"
        repo_url="${ULO_REPO}"
        log "STEPS" "Starting firmware repackaging with UloBuilder..."
    fi

    output_dir="${work_dir}/compiled_images"
    mkdir -p "$output_dir"

    cd "${work_dir}" || { error_msg "Failed to access working directory"; exit 1; }

    # Download & extract builder
    ariadl "${repo_url}" "main.zip" || { error_msg "Failed download builder"; exit 1; }
    unzip -q main.zip || { error_msg "Failed extract"; rm -f main.zip; exit 1; }
    rm -f main.zip

    # Prepare builder folder
    [[ "$builder_type" == "--ophub" ]] && mkdir -p "${builder_dir}/openwrt-armsr" || mkdir -p "${builder_dir}/rootfs"

    # Rootfs file
    local rootfs_files=("${work_dir}/compiled_images/"*"_${tunnel_type}-rootfs.tar.gz")
    [[ ${#rootfs_files[@]} -ne 1 ]] && { error_msg "Expected 1 rootfs file, found ${#rootfs_files[@]}"; exit 1; }
    local rootfs_file="${rootfs_files[0]}"

    # Copy rootfs
    local target_path
    [[ "$builder_type" == "--ophub" ]] && target_path="${builder_dir}/openwrt-armsr/${BASE}-armsr-armv8-generic-rootfs.tar.gz" \
        || target_path="${builder_dir}/rootfs/${BASE}-armsr-armv8-generic-rootfs.tar.gz"

    cp -f "${rootfs_file}" "${target_path}" || { error_msg "Failed copy rootfs"; exit 1; }

    cd "${builder_dir}" || { error_msg "Failed access builder dir"; exit 1; }

    # Jalankan builder
    local device_output_dir
    if [[ "$builder_type" == "--ophub" ]]; then
        log "INFO" "Running OphubBuilder..."
        sudo ./remake -b "${target_board}" -k "${target_kernel}" -s 512 || { error_msg "OphubBuilder failed"; exit 1; }
        device_output_dir="./openwrt/out"
    else
        log "INFO" "Running UloBuilder..."
        [[ -f "./.github/workflows/ULO_Workflow.patch" ]] && patch -p1 < ./.github/workflows/ULO_Workflow.patch
        local rootfs_basename=$(basename "${target_path}")
        sudo ./ulo -y -m "${target_board}" -r "${rootfs_basename}" -k "${target_kernel}" -s 1024 || { error_msg "UloBuilder failed"; exit 1; }
        device_output_dir="./out/${target_board}"
    fi

    # Copy hasil build ke output
    [[ ! -d "${device_output_dir}" ]] && { error_msg "Builder output not found"; exit 1; }
    cp -rf "${device_output_dir}"/* "${output_dir}/" || { error_msg "Failed copy firmware"; exit 1; }

    # Cleanup
    [[ -d "${builder_dir}" && "${builder_dir}" != "/" ]] && sudo rm -rf "${builder_dir}"

    sync && sleep 3
    ls -lh "${output_dir}"/*
    log "SUCCESS" "Firmware repacking completed!"
}

#==============================
# Fungsi Rename & Move Firmware
#==============================
rename_firmware() {
    echo -e "${STEPS} Renaming firmware files..."

    local firmware_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    [[ ! -d "$firmware_dir" ]] && { error_msg "Invalid firmware directory"; exit 1; }
    cd "$firmware_dir" || exit 1

    local mod_dir="${firmware_dir}/mod"
    mkdir -p "$mod_dir"

    local search_replace_patterns=(
        "-bcm27xx-bcm2709-rpi-2-ext4-factory|RaspberryPi_2B-Ext4_Factory"
        # ... semua pola lainnya sama seperti sebelumnya ...
        "x86-64-generic-rootfs|X86_64_Generic_Rootfs"
    )

    for pattern in "${search_replace_patterns[@]}"; do
        local search="${pattern%%|*}"
        local replace="${pattern##*|}"

        for file in *"${search}"*; do
            [[ ! -f "$file" ]] && continue

            local kernel=""
            [[ "$file" =~ k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)? ]] && kernel="${BASH_REMATCH[0]}"

            local new_name
            new_name="HJ-${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}-${DATE}.img.gz"
            [[ -n "$kernel" ]] && new_name="HJ-${OP_BASE}-${BRANCH}-${replace}-${kernel}-${TUNNEL}-${DATE}.img.gz"

            echo -e "${INFO} Renaming: $file → $new_name"
            mv "$file" "$new_name" || echo -e "${WARN} Failed rename $file"
        done
    done

    sync && sleep 3
    echo -e "${INFO} Rename & move completed. Files are in $mod_dir"
}

#==============================
# Panggil Fungsi
#==============================
# Contoh pemanggilan:
# ./script.sh ophub amlogic-s912 6.1 wireguard
# repackwrt --"$1" -t "$2" -k "$3" -tn "$4"
rename_firmware
