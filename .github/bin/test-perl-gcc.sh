#!/usr/bin/env bash
#
# Run one Alien::OpenMP compatibility test inside an official GCC image.
#
# Inputs:
#   PERL_VERSION  exact Perl release, e.g. 5.12.5
#   GCC_VERSION   GCC image tag, e.g. 4.8 or 16
#   JOBS          optional make parallelism, defaults to 2
#
set -eu

: "${PERL_VERSION:?PERL_VERSION is required}"
: "${GCC_VERSION:?GCC_VERSION is required}"

JOBS="${JOBS:-2}"
PERL_PREFIX="/opt/perl-${PERL_VERSION}"
PERL_SOURCE="/tmp/perl-${PERL_VERSION}"
WORKDIR="/tmp/p5-Alien-OpenMP"
HOME="/tmp/alien-openmp-ci-home"

export HOME
export PERL_MM_USE_DEFAULT=1

group_start() {
  printf '::group::%s\n' "$1"
}

group_end() {
  printf '::endgroup::\n'
}

group_start "Compiler"
gcc --version
group_end

group_start "Build Perl ${PERL_VERSION} with GCC ${GCC_VERSION}"
rm -rf "$PERL_SOURCE" "$PERL_PREFIX"
tar -xzf "/ci/perl-${PERL_VERSION}.tar.gz" -C /tmp
cd "$PERL_SOURCE"

./Configure \
  -des \
  -Dprefix="$PERL_PREFIX" \
  -Dcc=gcc \
  -Dld=gcc

make -j"$JOBS"
make install

"$PERL_PREFIX/bin/perl" -V:version -V:cc -V:gccversion -V:archname
group_end

export PATH="$PERL_PREFIX/bin:$PATH"

group_start "Install Alien::OpenMP CI dependencies"
#
# Use an HTTP CPAN mirror deliberately.  The cpanm client itself was downloaded
# by the modern GitHub runner, so old Perls do not need a modern TLS stack just
# to bootstrap their test dependencies.
#
"$PERL_PREFIX/bin/perl" /ci/cpanm \
  -n \
  --mirror http://www.cpan.org \
  --mirror-only \
  Alien::Build \
  Inline::C \
  Test::Alien \
  Test::Needs \
  Capture::Tiny \
  File::Which \
  Path::Tiny
group_end

group_start "Prepare Alien::OpenMP source"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
cp -a /src/. "$WORKDIR/"
cd "$WORKDIR"
cp .github/Makefile.PL.ci Makefile.PL
group_end

group_start "Build and test Alien::OpenMP"
"$PERL_PREFIX/bin/perl" Makefile.PL
make -j"$JOBS"
make test TEST_VERBOSE=1
group_end
