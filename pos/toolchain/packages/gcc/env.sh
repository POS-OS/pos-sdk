# Sourced by _pkg_setup for builds where gcc is installed.
#
# It searches /pos only. glibc and gcc's target libraries use it too: glibc
# overrides the part of its search that would be circular (it passes
# -nostdinc and -nostdlib); the target libraries are built by the new
# xgcc, not by this CC.
export CC=${sdk_prefix}/bin/gcc
export CXX=${sdk_prefix}/bin/g++
export LD=${sdk_prefix}/bin/ld
# The archive tools are binutils' too, which writes archives with zero
# dates (--enable-deterministic-archives); the build container's write the
# time, and gcc's executable_checksum, an md5 over its own archives, then
# differs between builds.
export AR=${sdk_prefix}/bin/ar
export RANLIB=${sdk_prefix}/bin/ranlib
export NM=${sdk_prefix}/bin/nm
