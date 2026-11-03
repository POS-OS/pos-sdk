# LLVM and clang, from the monorepo's release archive.

pkg() {
  # clang compiles for POS, as the sdk's gcc does (gcc/build.sh): programs
  # get POS' loader, /pos/lib/ld-linux-x86-64.so.2, as their interpreter,
  # and the system headers are /pos/include (C_INCLUDE_DIRS below), not
  # /usr/include or /usr/local/include (patches/0001-pos-driver.patch). The
  # source is the unpacked, patched archive; cmake builds out of tree.

  # Debug info at -g1 (line tables and functions): full debug info of
  # LLVM is tens of GB in the build tree. The flags are otherwise the
  # engine's.
  export CFLAGS=${CFLAGS/-g /-g1 } CXXFLAGS=${CXXFLAGS/-g /-g1 }

  # The targets: the host's, the other architectures POS may run on
  # (AArch64, ARM, RISCV), WebAssembly and BPF, which Rust and C programs
  # compile for. libLLVM and libclang-cpp are shared and the tools link
  # them (LLVM_LINK_LLVM_DYLIB, CLANG_LINK_CLANG_DYLIB), which keeps the
  # install at a few hundred MB. Links of the shared libraries take GBs
  # each: two at a time. Optional libraries LLVM would find in /pos or the
  # tools image are off, but zlib and zstd, which it requires (meta), and
  # which cmake looks for in /pos first (CMAKE_PREFIX_PATH), not in the
  # tools image's /usr.
  # No tests, benchmarks, examples or docs.
  pkg_cmake -G Ninja -S "$src_dir/llvm" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
    -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV;WebAssembly;BPF" \
    -DLLVM_HOST_TRIPLE=x86_64-pc-linux-gnu \
    -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-pc-linux-gnu \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DCLANG_LINK_CLANG_DYLIB=ON \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DCMAKE_PREFIX_PATH=/pos \
    -DLLVM_ENABLE_ZLIB=FORCE_ON \
    -DLLVM_ENABLE_ZSTD=FORCE_ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LIBEDIT=OFF \
    -DLLVM_ENABLE_FFI=OFF \
    -DLLVM_ENABLE_LIBPFM=OFF \
    -DLLVM_ENABLE_CURL=OFF \
    -DLLVM_ENABLE_HTTPLIB=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_DOCS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_DOCS=OFF \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DC_INCLUDE_DIRS=/pos/include \
    -DCLANG_DEFAULT_RTLIB=libgcc \
    -DCLANG_DEFAULT_CXX_STDLIB=libstdc++ \
    -DPython3_EXECUTABLE="$(command -v python3)"

  # No static libraries: LLVM installs each component library as an
  # archive too (237, 1 GB), which the tools and rustc, linking libLLVM and
  # libclang-cpp, do not use (Fedora ships them apart, llvm-static). Their
  # targets leave the cmake exports' per-configuration files, where
  # find_package(LLVM) and find_package(Clang) would refuse a missing file;
  # the targets stay declared, and a project links the shared libraries
  # (llvm_config ... USE_SHARED, clang-cpp), as LLVM_LINK_LLVM_DYLIB and
  # CLANG_LINK_CLANG_DYLIB make LLVM's own cmake functions do.
  rm -f "${dest_dir}${prefix}"/lib/*.a
  python3 - "${dest_dir}${prefix}/lib/cmake" <<'PY'
import glob, re, sys
static = re.compile(r'IMPORTED_LOCATION_RELEASE "\$\{_IMPORT_PREFIX\}/lib/[^"]*\.a"')
for f in glob.glob(sys.argv[1] + '/*/*-release.cmake'):
    s = open(f).read()
    tail = s.index('# Commands beyond this point')
    parts = re.split(r'(?=^# Import target ")', s[:tail], flags=re.M)
    kept = [p for p in parts if not static.search(p)]
    open(f, 'w').write(''.join(kept) + s[tail:])
PY
  if grep -l '\.a"' "${dest_dir}${prefix}"/lib/cmake/*/*-release.cmake; then
    echo "llvm: cmake exports still name static libraries" >&2
    exit 1
  fi

  # clang's default configuration (x86_64-pc-linux-gnu.cfg beside it,
  # which clang, clang++ and clang-cpp read): the gcc installation is the
  # sdk's (libstdc++, libgcc, the crt files of gcc), never another clang
  # would find (Fedora's in a build container). glibc's crt files and
  # libraries are in /pos/lib, and gcc's link names (libstdc++.so,
  # libgcc_s.so: linker scripts naming /pos/lib's) in <sdk>/lib, neither
  # of which clang searches by itself (it looks in lib64 directories).
  cat >"${dest_dir}${prefix}/bin/x86_64-pc-linux-gnu.cfg" <<'CFG'
# POS: clang uses the sdk's gcc installation and links against /pos.
--gcc-toolchain=<CFGDIR>/..
-B/pos/lib
-L/pos/lib
-L<CFGDIR>/../lib
CFG
}
