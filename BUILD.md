# Building
pos-sdk builds the POS toolchain: binutils, gcc with gmp, mpfr and
mpc in its tree, Go, and LLVM with clang, from their upstream release
archives, installed in
`/apps/pos-sdk/<version>` (`prefix` in `project`; `<version>` is
`<product version>.<revision>` of `VERSION`, 1.0.0): the sdk is the
whole prefix, its own `bin`, `lib`, `libexec`, `include` and `share`.
gcc-runtime installs in `/pos` (its meta's `prefix`), as pos ships it.
The sdk goes on a machine's `PATH` when it is installed there, not
through pos. It is built by the engine of POS, `buildsys/` of a pos
checkout; pos's BUILD.md describes the engine (builds, references,
package meta, release archives, the toolchain).

    $ echo "engine-checkout /path/to/pos" >>~/.config/pos/pos-sdk.conf
    $ ./build plan --new                # what a toolchain build builds
    $ ./build run --new                 # build the toolchain
    $ ./build reference                 # store it as the default toolchain reference

## Engine
`./build` runs the engine at the pos commit the `engine` line of
`project` pins. The engine is a clone of the pos checkout the
`engine-checkout` setting names (`POS_ENGINE_CHECKOUT`; in
`~/.config/pos/pos-sdk.conf`, or in `build.conf` beside it), in
`work/engine`, sparse (`buildsys/`) and checked out at that commit; a
new pin is fetched from the checkout. The clone shares the checkout's
objects (`git clone --shared`): a pinned commit must stay in the
checkout, as commits of its main do. `POS_ENGINE` names a pos checkout
to run as it is instead, for work on the engine. Moving to a newer
engine is a commit of the `engine` line. A build records the engine's
commit in its `info`.

The settings are pos's (`build.conf.dist` of the engine): `pos-sdk.conf`
holds what differs from pos's.

## Trees
* `pos/toolchain`: the recipes, all of the toolchain pipeline, the
  project's (`project`: `pipeline toolchain`). gmp, mpfr and mpc of gcc's
  tree are sources of their own (`gcc-gmp`, `gcc-mpfr`, `mpc`).
* `pos/build-env`: the host and profile packages, a copy of pos's: the
  Fedora compiler (`gcc-host`) a build without a toolchain reference
  uses, the host tools, and `pos-link`; Fedora's Go (`go-host`) for
  a build whose toolchain reference has no go.

## References
A toolchain build builds on the glibc and kernel headers of a pos
reference, made by pos (`./build reference` of a pos build), and with
the toolchain of a toolchain reference, or Fedora's compiler without
one (`toolchain-reference none`). The pos packages are known from the
reference itself, by the meta each installed. Both come from the
reference store (`reference-dir`), shared with pos: `./build reference`
stores a toolchain build there as the default toolchain reference, the
one pos builds take.

## Releases
pos-sdk numbers and publishes its toolchain builds as pos does its
builds, with its own `VERSION` and `main-<BUILD>` tags (the engine's
BUILD.md "Build numbers", "Releases"): `./build tag`, `./build publish`.
A release is `<release-dir>/pos-sdk/<release>` in the release library
shared with pos. It holds the toolchain packages as a reference archive
(`pos-ref-toolchain-<id>.tar.zst`: their staging trees and debug info),
the recipes and engine archives and the source archives of a build made
with `--source-archives`. The package records carry each package's
version (`version` beside `archive` in the meta).

## Run-time coupling
gcc builds both the compiler and gcc-runtime (libstdc++, libgcc_s and the
other run-time libraries), which pos ships in `/pos/lib`. The sdk links
against the gcc-runtime of the pos it runs on: its linker names
(`<sdk>/lib/libstdc++.so`, ...) point at the sonames in `/pos/lib`
(`libstdc++.so.6`), not at one gcc's files, so an sdk works on every pos
whose gcc-runtime has the symbols it needs: one of the same gcc or newer.

## Go
go is the Go toolchain, `<sdk>/lib/go` (its `GOROOT`: the compiler, the
go command and the standard library's sources), with `go` and `gofmt`
in `<sdk>/bin`; its `env.sh` puts them on a build's `PATH`. Go builds
itself: go build-requires go, which is the toolchain reference's go, or
Fedora's (`go-host`, which go obsoletes) without one (the engine's
BUILD.md "Packages"). Go 1.27 needs Go 1.24.6 or newer to build it.
The go command and the compiler run on nothing but the kernel; programs
using cgo compile with the sdk's gcc. Go is patched for POS:

* Programs Go links itself (no cgo, or `-linkmode=internal`) get POS'
  loader, `/pos/lib/ld-linux-x86-64.so.2`, as their interpreter, as gcc
  gives its programs.
* The time package reads `/pos/share/zoneinfo` (tzdata) first.
* `GOTOOLCHAIN=local` (`go.env`): the go command builds with itself and
  never downloads another toolchain. The module proxy and checksum
  database are upstream's.

The CA bundle needs no patch: POS links
`/etc/ssl/certs/ca-certificates.crt`, the first file `crypto/x509` reads.
The tests' data (`testdata` directories, `test/`) is not installed.

## LLVM and clang
llvm is LLVM with clang and clang-tools-extra (clangd, clang-tidy,
clang-format), for the X86, AArch64, ARM, RISCV, WebAssembly and BPF
targets: the LLVM rustc builds against (`llvm-config`, shared mode),
libclang for bindgen, and the C and C++ editor tools. gcc stays the
compiler POS is built with. LLVM is one shared libLLVM and clang one
libclang-cpp, which the tools link; the static component libraries LLVM
installs as well are dropped, with their targets in the cmake exports'
per-configuration files, so `find_package(LLVM)` and `find_package(Clang)`
work and a project links the shared libraries (`llvm_config(... USE_SHARED
...)`, `clang-cpp`). A program linking them is outside `/pos` and needs
its own runpath to `<sdk>/lib`, as the loader searches `/pos/lib` only.
zlib, zstd and the C++ run-time are pos'. Debug info is `-g1`.

clang compiles for POS as gcc does:

* Programs get POS' loader, `/pos/lib/ld-linux-x86-64.so.2`
  (`patches/0001-pos-driver.patch`), and the system headers are
  `/pos/include` (`C_INCLUDE_DIRS`), without `/usr/local/include`.
* `<sdk>/bin/x86_64-pc-linux-gnu.cfg`, clang's default configuration,
  names the sdk's gcc installation (`--gcc-toolchain`: libstdc++, libgcc,
  the crt files), which clang would otherwise choose among those it finds,
  Fedora's in a build container, and adds `/pos/lib` (glibc's crt files and
  libraries) and `<sdk>/lib` (gcc's link names) to the search, as clang
  looks in `lib64` directories.

