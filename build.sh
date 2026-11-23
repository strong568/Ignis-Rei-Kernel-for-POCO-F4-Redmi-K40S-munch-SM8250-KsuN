#!/usr/bin/env bash
#
# Ignis-Rei Kernel Build Script for POCO F4 / Redmi K40S (munch)
# Dual Variant: AOSP (Custom ROMs) & Stock (MIUI / HyperOS)
#

set -e

KERNEL_NAME="Ignis-Rei"
DEVICE="munch"
BUILD_VARIANT="${1:-both}" # aosp, stock, both
DATE=$(date +%Y%m%d-%H%M)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"
OUT_DIR="${ROOT_DIR}/out"

# Setup Toolchain
if [ -n "$CLANG_PATH" ] && [ -d "$CLANG_PATH" ]; then
    TC_DIR="$CLANG_PATH"
elif [ -d "$HOME/toolchains/neutron" ]; then
    TC_DIR="$HOME/toolchains/neutron"
elif [ -d "/home/arun/toolchains/neutron" ]; then
    TC_DIR="/home/arun/toolchains/neutron"
elif [ -d "${ROOT_DIR}/clang" ]; then
    TC_DIR="${ROOT_DIR}/clang"
else
    echo "ERROR: Clang toolchain not found!"
    echo "Please set CLANG_PATH or install Neutron Clang in ~/toolchains/neutron"
    exit 1
fi

export PATH="${TC_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ARCH=arm64
export SUBARCH=arm64
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export HOSTCC=gcc
export HOSTCXX=g++
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

CLANG_VER=$("${TC_DIR}/bin/clang" --version | head -n 1)

echo "================================================="
echo "  Kernel Name : ${KERNEL_NAME}"
echo "  Device      : ${DEVICE} (POCO F4 / Redmi K40S)"
echo "  Variant     : ${BUILD_VARIANT}"
echo "  Compiler    : ${CLANG_VER}"
echo "  Date        : ${DATE}"
echo "================================================="

# Clean stale root artifacts
rm -f include/config/auto.conf .config

MAKE_FLAGS=(
    ARCH=arm64
    CC=clang
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    HOSTCC=gcc
    HOSTCXX=g++
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

build_kernel() {
    local variant="$1" # aosp or stock
    local out_sub="${OUT_DIR}/${variant}"
    mkdir -p "${out_sub}"

    echo ">>> Generating defconfig for [${variant}]..."
    if [ "$variant" = "stock" ]; then
        ./scripts/kconfig/merge_config.sh -m -O "${out_sub}" \
            arch/arm64/configs/vendor/kona-perf_defconfig \
            arch/arm64/configs/vendor/xiaomi/sm8250-common.config \
            arch/arm64/configs/vendor/xiaomi/munch.config \
            arch/arm64/configs/vendor/xiaomi/stock.config
    else
        ./scripts/kconfig/merge_config.sh -m -O "${out_sub}" \
            arch/arm64/configs/vendor/kona-perf_defconfig \
            arch/arm64/configs/vendor/xiaomi/sm8250-common.config \
            arch/arm64/configs/vendor/xiaomi/munch.config
    fi
    make O="${out_sub}" "${MAKE_FLAGS[@]}" olddefconfig

    echo ">>> Compiling Kernel [${variant}]..."
    make -j$(nproc --all) O="${out_sub}" "${MAKE_FLAGS[@]}" Image

    if [ ! -f "${out_sub}/arch/arm64/boot/Image" ]; then
        echo "ERROR: Kernel compilation failed for ${variant}!"
        exit 1
    fi

    echo ">>> Kernel [${variant}] compiled successfully!"
}

# Execute builds
if [ "$BUILD_VARIANT" = "aosp" ]; then
    build_kernel "aosp"
elif [ "$BUILD_VARIANT" = "stock" ]; then
    build_kernel "stock"
else
    build_kernel "aosp"
    build_kernel "stock"
fi

# AnyKernel3 Packaging
echo ">>> Packaging flashable AnyKernel3 zip..."
AK3_DIR="${OUT_DIR}/AK3"
rm -rf "${AK3_DIR}"
mkdir -p "${AK3_DIR}"

if [ -d "${ROOT_DIR}/anykernel" ]; then
    cp -r "${ROOT_DIR}/anykernel/"* "${AK3_DIR}/"
fi

# Stage kernel image as MUNCH-Image
if [ "$BUILD_VARIANT" = "stock" ]; then
    cp -f "${OUT_DIR}/stock/arch/arm64/boot/Image" "${AK3_DIR}/MUNCH-Image"
else
    cp -f "${OUT_DIR}/aosp/arch/arm64/boot/Image" "${AK3_DIR}/MUNCH-Image"
fi

# Ensure anykernel.sh is present and executable
if [ -f "${ROOT_DIR}/anykernel/anykernel.sh" ]; then
    cp -f "${ROOT_DIR}/anykernel/anykernel.sh" "${AK3_DIR}/anykernel.sh"
    chmod +x "${AK3_DIR}/anykernel.sh"
fi

# Clean loose files from staging (keep only META-INF, tools, anykernel.sh, MUNCH-Image)
rm -rf "${AK3_DIR}/kernels" "${AK3_DIR}/dtb" "${AK3_DIR}/dtbo.img" "${AK3_DIR}/Image" "${AK3_DIR}/.git" "${AK3_DIR}/README.md" "${AK3_DIR}/LICENSE" "${AK3_DIR}/modules" "${AK3_DIR}/patch" "${AK3_DIR}/ramdisk"

cd "${AK3_DIR}"
ZIP_NAME="${KERNEL_NAME}-${DEVICE}-Perf-${DATE}.zip"
zip -r9 "${OUT_DIR}/${ZIP_NAME}" *

echo "================================================="
echo "  Build Completed Successfully!"
echo "  Zip Location: ${OUT_DIR}/${ZIP_NAME}"
echo "================================================="

# Copy to Windows Desktop and Downloads if running under WSL
if [ -d "/mnt/c/Users/ARUN/Desktop" ]; then
    cp -f "${OUT_DIR}/${ZIP_NAME}" "/mnt/c/Users/ARUN/Desktop/${ZIP_NAME}"
    cp -f "${OUT_DIR}/${ZIP_NAME}" "/mnt/c/Users/ARUN/Desktop/Ignis-Rei-munch-Perf.zip"
    echo "  Copied to Desktop: C:\\Users\\ARUN\\Desktop\\${ZIP_NAME}"
fi
if [ -d "/mnt/c/Users/ARUN/Downloads" ]; then
    cp -f "${OUT_DIR}/${ZIP_NAME}" "/mnt/c/Users/ARUN/Downloads/Ignis-Rei-munch-Perf.zip"
fi
