# Go, built by Go (meta: the toolchain reference's, or Fedora's).

pkg() {
  # make.bash builds the toolchain in the source tree, which is then the
  # GOROOT that is installed, as Fedora's golang does: <sdk>/lib/go, with
  # bin/go and bin/gofmt linked from <sdk>/bin. The go command finds its
  # GOROOT from its own path, wherever the sdk is.
  pkg_sync_src

  # Defaults for POS. Programs Go links itself (internal linking: no cgo,
  # or cgo with -linkmode=internal) get POS' loader as their interpreter,
  # as the sdk's gcc gives its programs (gcc/build.sh): there is no
  # /lib64 on POS. The time package reads POS' zoneinfo (tzdata,
  # /pos/share/zoneinfo) before the usual places. The CA bundle needs
  # nothing: POS links /etc/ssl/certs/ca-certificates.crt, the first file
  # crypto/x509 tries.
  sed -e 's@"/lib64/ld-linux-x86-64.so.2"@"/pos/lib/ld-linux-x86-64.so.2"@' \
    -i src/cmd/link/internal/amd64/obj.go
  grep -q '"/pos/lib/ld-linux-x86-64.so.2"' src/cmd/link/internal/amd64/obj.go
  sed -e 's@^\t"/usr/share/zoneinfo/",@\t"/pos/share/zoneinfo/",\n&@' -i src/time/zoneinfo_unix.go
  grep -q '"/pos/share/zoneinfo/"' src/time/zoneinfo_unix.go
  # GOTOOLCHAIN=local: the go command builds with itself, and does not
  # download a newer toolchain where a module asks for one (as Fedora). The
  # module proxy and checksum database stay upstream's.
  sed -e 's/^GOTOOLCHAIN=auto$/GOTOOLCHAIN=local/' -i go.env
  grep -qx 'GOTOOLCHAIN=local' go.env

  # The bootstrap Go is the one on PATH (go-host's Fedora golang, or the
  # toolchain reference's go/env.sh). -B gobuildid gives the toolchain's
  # programs a GNU build ID made from their Go build ID, which
  # _pkg_finish splits their debug info by. cgo compiles with the
  # environment's gcc and flags.
  local bootstrap
  export GOCACHE=$build_dir/.gocache GOPATH=$build_dir/.gopath
  bootstrap=$(go env GOROOT)
  echo "go: bootstrap $(go version) from $bootstrap"
  (cd src &&
    GOROOT_BOOTSTRAP=$bootstrap GO_LDFLAGS="-B gobuildid" \
      CC=${CC:-gcc} CGO_CFLAGS=$CFLAGS CGO_LDFLAGS=$LDFLAGS ./make.bash)

  # The tree as a GOROOT: what the go command and the standard library
  # need, without the build's cache and objects and without the tests'
  # data (the testdata directories and test/: go test std needs them, a
  # build does not; they hold ELF files of other systems that strip would
  # not take).
  local root=${dest_dir}${prefix}/lib/go
  mkdir -p "$root"
  cp -a api bin doc lib misc pkg src go.env VERSION LICENSE PATENTS "$root/"
  rm -rf "$root/pkg/obj" "$root/pkg/bootstrap"
  find "$root/src" -depth -type d -name testdata -exec rm -rf {} +
  mkdir -p "${dest_dir}${prefix}/bin"
  ln -s ../lib/go/bin/go "${dest_dir}${prefix}/bin/go"
  ln -s ../lib/go/bin/gofmt "${dest_dir}${prefix}/bin/gofmt"
}
