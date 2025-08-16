#!/usr/bin/env bash
#
# Cross-LFS Build Script
#

set -e
set -x

source build.config

LFS=$(pwd)
LFS_BUILD=$(gcc -dumpmachine)
LFS_TARGET="${LFS_ARCH}-lfs-linux-gnu"
LFS_PREFIX=$LFS/host
LFS_SYSROOT=$LFS/host/$LFS_TARGET/sysroot
LFS_STAGING=$LFS/target

export PATH=$LFS/host/bin:$LFS/host/usr/bin:$PATH

usage() {
  cat <<'EOF'
Usage:
  ./build.sh <config|bootstrap|clean|build-all|build> [name] [args...]

Commands:
  config              Show configuration environment vars
  bootstrap           Run the bootstrap step
  clean               Clean artifacts
  build-all           Build all configured packages
  build <name> [...]  Build package <name> and add it to the target

Examples:
  ./build.sh config
  ./build.sh bootstrap
  ./build.sh clean
  ./build.sh build-all
  ./build.sh build binutils
  ./build.sh build gcc_stage1 --some-flag
EOF
}

setup_environment () {
    CC="${LFS_TARGET}-gcc"
    CXX="${LFS_TARGET}-g++"
    AR="${LFS_TARGET}-ar"
    RANLIB="${LFS_TARGET}-ranlib"
    AS="${LFS_TARGET}-as"
    LD="${LFS_TARGET}-ld"
    
    export CC CXX AR RANLIB AS LD
}

show_config() {
    echo LFS=$LFS
    echo LFS_BUILD=$LFS_BUILD
    echo LFS_TARGET=$LFS_TARGET
    echo LFS_PREFIX=$LFS_PREFIX
    echo LFS_SYSROOT=$LFS_SYSROOT
    echo LFS_STAGING=$LFS_STAGING
}

clean() {
    rm -rf host/*
    rm -rf build/*
    rm -rf target/*
    rm staging
}

print_info() {
    # color only if stdout is a TTY and NO_COLOR is not set
    if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
        local G=$'\033[32m' R=$'\033[0m'
    else
        local G= R=
    fi
    
    printf '%s[INFO]%s %s\n' "$G" "$R" "$*"
}

print_error() {
    if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
        local R=$'\033[31m' N=$'\033[0m'  # red / reset
    else
        local R= N=
    fi
    
    printf '%s[ERROR]%s %s\n' "$R" "$N" "$*" >&2
}

#
# perform post-build actions
#
post_build() {
    print_info "=== Sanitizing ==="
    find $LFS_SYSROOT/usr/lib/ -type f -name '*.la' -print -delete
}

#
# prepare all target, staging and host directories
#
setup_dirs() {
    # create output directories
    mkdir -pv $LFS/{host,target,rootfs,build}
    
    # create staging shortcut
    ln -sfv host/${LFS_TARGET}/sysroot staging

    # keep all libraries and binaries in one place
    for d in $LFS_SYSROOT, $LFS_STAGING; do
        mkdir -pv $d/usr/lib64
        mkdir -pv $d/usr/{bin,sbin}

        ln -sfv lib64 $d/usr/lib
        ln -sfv usr/lib64 $d/lib64
        ln -sfv usr/lib $d/lib

        ln -sfv usr/bin $d/bin
        ln -sfv usr/sbin $d/sbin
    done
    
    mkdir -pv $LFS_STAGING/{boot,home,mnt,opt,srv,dev}
    mkdir -pv $LFS_STAGING/etc/{opt,sysconfig}
    mkdir -pv $LFS_STAGING/lib/firmware
    mkdir -pv $LFS_STAGING/media/{floppy,cdrom}
    mkdir -pv $LFS_STAGING/usr/{,local/}{include,src}
    mkdir -pv $LFS_STAGING/usr/lib/locale
    mkdir -pv $LFS_STAGING/usr/local/{bin,lib,sbin}
    mkdir -pv $LFS_STAGING/usr/{,local/}share/{color,dict,doc,info,locale,man}
    mkdir -pv $LFS_STAGING/usr/{,local/}share/{misc,terminfo,zoneinfo}
    mkdir -pv $LFS_STAGING/usr/{,local/}share/man/man{1..8}
    mkdir -pv $LFS_STAGING/var/{cache,local,log,mail,opt,spool}
    mkdir -pv $LFS_STAGING/var/lib/{color,misc,locate}
    mkdir -pv $LFS_STAGING/run/lock

    ln -sfv ../run $LFS_STAGING/var/run
    ln -sfv ../run/lock $LFS_STAGING/var/lock

    install -dv -m 0750 $LFS_STAGING/root
    install -dv -m 1777 $LFS_STAGING/tmp $LFS_STAGING/var/tmp
}

#
# build and install a package
#
build_package() {
    local pkg="${1}"
    local fn="build_${pkg}"

    if ! declare -F "${fn}" >/dev/null; then
        echo "error: package '${pkg}' is not defined" >&2
        exit 1
    fi

    "${fn}" "$@"
}

#
# source all package files
#
for f in packages/*; do
    source $f
done

main() {
  local cmd="${1-}"
  if [[ -z "${cmd}" || "${cmd}" == "-h" || "${cmd}" == "--help" ]]; then
    usage; exit 0
  fi

    case "$cmd" in
        config)
            show_config
            exit 0
            ;;
        bootstrap)
            setup_dirs
            build_linux_headers
            build_binutils
            build_gcc_stage1
            build_glibc
            build_gcc_stage2
            exit 0
            ;;
        build-all)
            for package in ${LFS_PACKAGES[@]}; do
                build_package $package
            done
            exit 0
            ;;
        clean)
            clean
            exit 0
            ;;
        build)
            local name="${2-}"
            if [[ -z "${name}" ]]; then
                echo "error: 'build' requires a name (e.g., build binutils)" >&2
                usage
                exit 1
            fi
      
            # Sanitize name to avoid weird function names
            [[ "${name}" =~ ^[A-Za-z0-9_]+$ ]] || {
                echo "error: invalid build name '${name}'" >&2
                exit 1
            }

            shift # drop 'build'
            local package="${1}"
            shift # drop package name

            build_package $package $@
            ;;

        *)
            echo "error: unknown command '${cmd}'" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
