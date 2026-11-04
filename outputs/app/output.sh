# The sdk's bin on PATH. Programs it compiles link the gcc-runtime of its
# gcc, which pos ships: the system needs that version or a newer one
# (BUILD.md "Run-time coupling").
output() {
  local gcc
  gcc=$(app_version gcc-runtime) || exit 1
  app_make "path bin" "requires gcc-runtime >= $gcc"
}
