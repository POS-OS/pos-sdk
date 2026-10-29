# Building
pos-sdk builds the POS toolchain: binutils, and gcc with gmp, mpfr and
mpc in its tree, from their upstream release archives, installed in
`/pos/sdk`. It is built by the engine of POS, `buildsys/` of a pos
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
holds what differs from pos's, as `release-dir`.

## Trees
* `pos/toolchain`: the recipes, all of the toolchain pipeline, the
  project's (`project`: `pipeline toolchain`). gmp, mpfr and mpc of gcc's
  tree are sources of their own (`gcc-gmp`, `gcc-mpfr`, `mpc`).
* `pos/build-env`: the host and profile packages, a copy of pos's: the
  Fedora compiler (`gcc-host`) a build without a toolchain reference
  uses, the host tools, and `pos-link`.

## References
A toolchain build builds on the glibc and kernel headers of a pos
reference, made by pos (`./build reference` of a pos build), and with
the toolchain of a toolchain reference, or Fedora's compiler without
one (`toolchain-reference none`). The pos packages are known from the
reference itself, by the meta each installed. Both come from the
reference store (`reference-dir`), shared with pos: `./build reference`
stores a toolchain build there as the default toolchain reference, the
one pos builds take.
