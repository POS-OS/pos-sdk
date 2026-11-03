# Rust, built by Rust (meta: the toolchain reference's, or Fedora's), with
# x.py, the release's own build.

pkg() {
  # x.py builds in the tree it runs from (build/, and what it records of
  # the source): a copy of the source.
  pkg_sync_src

  # stage0 is the rustc and cargo on PATH. One of the same release is a
  # local rebuild: x.py skips building stage0 again with it (as Fedora's
  # rust does when it builds the release it has).
  local rustc cargo local=false
  rustc=$(command -v rustc) cargo=$(command -v cargo)
  echo "rust: stage0 $("$rustc" --version) from $rustc"
  [[ $("$rustc" --version | awk '{print $2}') != "$(awk '{print $1}' version)" ]] || local=true

  # The release's dist build (extended: the tools), installed in the sdk
  # prefix, without docs. rustc links the sdk's libLLVM (link-shared) and
  # links programs with gcc, the sdk's (default-linker), which gives them
  # POS' loader; the engine sets the runpaths (no rpath). The crates are
  # the release's vendored ones, the build offline. Debug info: line
  # tables and functions (level 1), compressed by the engine. No jemalloc
  # (glibc's malloc), no lld or LLVM tools of its own (the sdk's LLVM has
  # none to ship). llvm is built by the same toolchain build, in its
  # prefix; the sdk's bin is not on PATH, so the build compiles and links
  # with gcc's CC and CXX (gcc/env.sh), and the rustc it installs runs
  # gcc from PATH, where an installed sdk is.
  cat >bootstrap.toml <<TOML
change-id = "ignore"
profile = "dist"
build.rustc = "$rustc"
build.cargo = "$cargo"
build.local-rebuild = $local
build.build-dir = "$build_dir/build"
build.python = "python3"
build.vendor = true
build.locked-deps = true
build.docs = false
build.compiler-docs = false
build.extended = true
build.tools = ["cargo", "clippy", "rustdoc", "rustfmt", "rust-analyzer", "rust-analyzer-proc-macro-srv", "src"]
build.description = "POS"
install.prefix = "$prefix"
install.sysconfdir = "etc"
install.libdir = "lib"
llvm.link-shared = true
rust.channel = "stable"
rust.rpath = false
rust.default-linker = "gcc"
rust.debuginfo-level = 1
rust.codegen-units-std = 1
rust.jemalloc = false
rust.lld = false
rust.llvm-tools = false
rust.llvm-bitcode-linker = false
rust.deny-warnings = false
target.x86_64-unknown-linux-gnu.llvm-config = "$prefix/bin/llvm-config"
target.x86_64-unknown-linux-gnu.cc = "$CC"
target.x86_64-unknown-linux-gnu.cxx = "$CXX"
target.x86_64-unknown-linux-gnu.linker = "$CC"
TOML
  # The compilers x.py builds and runs (stage1, stage2) have no runpath;
  # they find libLLVM in the sdk's lib, where llvm is in the build, as the
  # installed ones do by the engine's ($ORIGIN/../lib).
  LD_LIBRARY_PATH=$prefix/lib DESTDIR=$dest_dir python3 x.py install -j "$nproc"

  # The installer's own records (they name the staging tree) go; cargo's
  # bash completion goes where bash-completion looks in the prefix, as
  # nothing is installed in its etc.
  local root=${dest_dir}${prefix}
  rm -f "$root"/lib/rustlib/{install.log,uninstall.sh}
  mkdir -p "$root/share/bash-completion/completions"
  mv "$root/etc/bash_completion.d/cargo" "$root/share/bash-completion/completions/cargo"
  rm -r "$root/etc"
}
