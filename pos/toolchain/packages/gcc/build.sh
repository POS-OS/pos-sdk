# The sdk compiler. The run-time libraries C and C++ programs need go to the
# gcc-runtime output, so a base system can ship them without the compiler.

pkg() {
  # The gcc source, with gmp, mpfr and mpc (meta with-sources) beside its
  # own directories, where gcc's configure builds them along with it. It
  # looks for them as gmp and mpfr; the sources are named gcc-gmp and
  # gcc-mpfr, as core-libs has sources gmp and mpfr.
  pkg_sync_src
  mv gcc-gmp gmp
  mv gcc-mpfr mpfr

  # POS is a prefix (/pos) on a root that has no /lib or /usr/include of its
  # own, so the compiler's built-in defaults must point there. --with-sysroot
  # is the wrong tool: it treats /pos as a whole root, re-roots absolute paths
  # in glibc's libc.so linker script to /pos/pos/lib, and leaves the ELF
  # interpreter at /lib64/ld-linux-x86-64.so.2. Instead, patch the target
  # header the way LFS pass 1 aims a compiler at /tools.
  hdr=gcc/config/i386/linux64.h
  sed -e '/m64=/s/lib64/lib/' -i gcc/config/i386/t-linux64
  sed -e 's@/lib64/ld-linux-x86-64.so.2@/pos/lib/ld-linux-x86-64.so.2@' -i "$hdr"
  cat >> "$hdr" <<'EOF2'

/* POS: link against /pos/lib only. */
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/pos/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""
EOF2

  # gcc's top-level configure derives CFLAGS_FOR_TARGET from CFLAGS, so the
  # flags of _pkg_flags would reach libgcc, libstdc++ and the other target
  # libraries, which choose their own (libgcc is built without the stack
  # protector). The compiler is built with the optimization and debug info
  # only, as upstream's default -g -O2; the link flags stay.
  export CFLAGS=$pos_optflags CXXFLAGS=$pos_optflags

  # The compiler's own programs (cc1, cc1plus, lto1, collect2) run under the
  # POS loader like everything else in /pos, so the ambient /pos link flags
  # from _pkg_setup stay on, but for pos-link's -L/pos/lib: the in-tree gmp,
  # mpfr, mpc and zlib are linked as -L<dir> -l<name> after LDFLAGS, and
  # /pos has its own gmp, mpfr and zlib (base stage, the build tools'
  # run-time closure). The compiler searches /pos/lib after every -L by
  # itself. The target libraries are built by the new xgcc with the
  # patched defaults.
  LDFLAGS=${LDFLAGS/-L\/pos\/lib /}
  #
  # What the compiler runs on is glibc only: gmp, mpfr and mpc from the tree,
  # gcc's bundled zlib, no zstd (LTO streams are zlib-compressed), and
  # libstdc++ and libgcc linked statically.
  # The compiler is in the sdk prefix (the project's,
  # /apps/pos-sdk/<version>) and targets pos: its headers and libraries are
  # /pos/include and /pos/lib, libgcc_s goes to /pos/lib (--with-slibdir),
  # and the loader is /pos/lib's (linux64.h above).
  # --with-as/--with-ld bake the POS binutils paths into the driver.
  # --without-isl pins the Graphite check so a change to the tools image
  # cannot change the result. libcc1 installs into the building compiler's
  # multilib directory (libcc1/configure.ac: $CXX -print-multi-os-directory),
  # which Fedora's g++ answers with ../lib64; it is gdb's compile plugin.
  mkdir build
  cd build
  pkg_autotools ../configure \
    --prefix="$prefix" \
    --libdir="${prefix}/lib" \
    --libexecdir="${prefix}/libexec" \
    --with-slibdir=/pos/lib \
    --with-local-prefix=/pos \
    --with-native-system-header-dir=/pos/include \
    --enable-languages=c,c++ \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-linker-build-id \
    --disable-multilib \
    --disable-bootstrap \
    --disable-nls \
    --disable-libstdcxx-pch \
    --disable-fixincludes \
    --disable-libcc1 \
    --with-static-standard-libraries \
    --without-zstd \
    --with-as="${prefix}/bin/as" \
    --with-ld="${prefix}/bin/ld" \
    --without-isl

  # gcc-runtime: libgcc_s, libstdc++, libatomic and libgomp, split as Fedora
  # splits them, and the target libraries Fedora packages on their own, as
  # Arch's gcc-libs has them: the sanitizers (asan, hwasan, lsan, tsan,
  # ubsan), libitm, libquadmath and libssp. The loader does not search the
  # sdk's lib, so a program built with them runs only where they are in
  # /pos/lib. The output keeps what programs load at run time (lib*.so.N)
  # and the libstdc++ gdb pretty-printers, in /pos (its meta's prefix):
  # they are pos's, not the sdk's. Everything used only when compiling or
  # linking stays with gcc, in the sdk prefix: headers, the compiler's own
  # directory (lib/gcc: crt files, libgcc.a, unwind.h, omp.h), static
  # libraries, the unversioned
  # lib*.so names the linker looks up, the .spec files, the sanitizers'
  # preinit objects and libstdc++.modules.json.
  runtime=$(pkg_output gcc-runtime)
  make DESTDIR="$runtime" install-target-libgcc install-target-libatomic \
       install-target-libstdc++-v3 install-target-libgomp \
       install-target-libsanitizer install-target-libitm \
       install-target-libquadmath install-target-libssp
  rm -rf "${runtime}${prefix}/include" "${runtime}${prefix}/lib/gcc"
  find "${runtime}${prefix}/lib" "${runtime}${pos_prefix}/lib" -maxdepth 1 ! -type d ! -name 'lib*.so.*' -delete
  mv "${runtime}${prefix}"/lib/lib*.so.* "${runtime}${pos_prefix}/lib/"
  mkdir -p "${runtime}${pos_prefix}/share"
  cp -a "${runtime}${prefix}/share/." "${runtime}${pos_prefix}/share/"
  rm -rf "${runtime}${prefix}"
  find "$runtime" -mindepth 1 -depth -type d -empty -delete
  # The pretty-printers' loader finds them from the paths it was installed
  # with.
  sed -i "s|'${prefix}/|'${pos_prefix}/|" "${runtime}${pos_prefix}"/lib/libstdc++.so.*-gdb.py
  grep -q "^pythondir = '${pos_prefix}/share/" "${runtime}${pos_prefix}"/lib/libstdc++.so.*-gdb.py ||
    { echo "gcc: libstdc++ gdb script not moved to ${pos_prefix}" >&2; exit 1; }

  # gcc keeps none of it, at either path (_pkg_finish removes the files at
  # the output's paths), and the linker names of the libraries moved, and
  # of libgcc_s, are in the sdk prefix, pointing at /pos/lib by absolute
  # path, as the sdk is in a prefix of its own. They point at
  # the soname (libstdc++.so.6), not the file (libstdc++.so.6.0.36): the sdk
  # links against the gcc-runtime of the pos it runs on, whose file may be
  # another gcc's of the same major (BUILD.md "Run-time coupling").
  (cd "${runtime}${pos_prefix}" && find . ! -type d -print0) |
    while IFS= read -r -d '' f; do
      rm -f "${dest_dir}${prefix}/${f#./}"
    done
  mv "${dest_dir}${pos_prefix}"/lib/libgcc_s.so "${dest_dir}${pos_prefix}"/lib/libgcc_s_asneeded.so \
     "${dest_dir}${prefix}/lib/"
  for f in "${dest_dir}${prefix}"/lib/lib*.so; do
    [[ -L $f && ! -e $f ]] || continue
    t=$(readlink "$f")
    [[ -e ${runtime}${pos_prefix}/lib/$t ]] ||
      { echo "gcc: $(basename "$f") points at $t, which is in neither prefix" >&2; exit 1; }
    so=$(readelf -d "${runtime}${pos_prefix}/lib/$t" | sed -n 's/.*(SONAME).*\[\(.*\)\]$/\1/p')
    [[ -n $so && -L ${runtime}${pos_prefix}/lib/$so ]] ||
      { echo "gcc: $t has no soname link in gcc-runtime (soname '$so')" >&2; exit 1; }
    ln -sfn "${pos_prefix}/lib/$so" "$f"
  done
  # libtool archives: not needed to link against the shared libraries, and
  # Fedora does not ship them.
  find "${dest_dir}${prefix}/lib" -maxdepth 1 -name '*.la' -delete

  # ar, nm and ranlib load the plugins in lib/bfd-plugins of their prefix:
  # with gcc's LTO plugin there, as Fedora links it, they read LTO objects
  # as gcc-ar, gcc-nm and gcc-ranlib do. binutils ships no bfd-plugins.
  plugin=$(cd "${dest_dir}${prefix}" && echo libexec/gcc/*/*/liblto_plugin.so)
  [[ -f ${dest_dir}${prefix}/$plugin ]] || { echo "gcc: no LTO plugin: $plugin" >&2; exit 1; }
  mkdir -p "${dest_dir}${prefix}/lib/bfd-plugins"
  ln -s "../../$plugin" "${dest_dir}${prefix}/lib/bfd-plugins/liblto_plugin.so"

  # The compiler's programs must run on glibc alone (see configure above).
  # A configure check that quietly fell back to a shared library would tie
  # the toolchain to a pos build's copy of it.
  bad=$(find "${dest_dir}${prefix}/bin" "${dest_dir}${prefix}/libexec/gcc" -type f -perm -u+x \
          -exec readelf -d {} + 2>/dev/null |
        awk '/NEEDED/ {print $NF}' | tr -d '[]' | sort -u |
        grep -v -E '^(libc|libm|ld-linux-x86-64)\.so' || true)
  if [[ -n $bad ]]; then
    echo "gcc: compiler programs need more than glibc: $(xargs <<<"$bad")" >&2
    exit 1
  fi
}
