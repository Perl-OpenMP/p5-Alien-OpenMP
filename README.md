# NAME

Alien::OpenMP - Encapsulate system info for OpenMP

# SYNOPSIS

    use Alien::OpenMP;
    say Alien::OpenMP->cflags;
    say Alien::OpenMP->lddlflags;
    say Alien::OpenMP->auto_include;

    use Inline C => 'DATA', with => 'Alien::OpenMP';

# DESCRIPTION

`Alien::OpenMP` provides the compiler and linker settings needed to enable
OpenMP for the C compiler configured into the running Perl. It is intended for
Perl extensions and consumers such as `Inline::C` that use Perl's configured C
toolchain.

The module intentionally follows Perl's `$Config{cc}` toolchain. Perl XS and
`Inline::C` builds normally inherit that compiler and its ABI/linker settings,
so an unrelated `CC` environment variable is not treated as an implicit
request to switch compilers. ABI-compatible alternate compilers may be usable
by applications, but they are outside the default `Alien::OpenMP` toolchain
contract.

Compiler family detection is based on predefined compiler macros rather than
the compiler executable filename. This permits versioned and target-prefixed
GCC drivers such as `gcc-16` and `x86_64-linux-gnu-gcc` to use the same GCC
OpenMP profile.

## Compilers Supported by this module

The conservative supported compiler families are:

- `gcc`

    GCC uses `-fopenmp` for both compilation and runtime linkage. This includes
    MinGW GCC used by Strawberry Perl and GNU GCC on macOS. GNU GCC on macOS
    uses its GCC OpenMP runtime and must not be mixed with LLVM's `-lomp`
    runtime.

- `clang` EXPERIMENTAL

    Upstream LLVM Clang uses `-fopenmp`. This includes FreeBSD's Clang
    toolchain when the required OpenMP runtime is available.

    Apple Clang on macOS requires a separate OpenMP runtime, normally `libomp`.
    It can be installed with [Homebrew](https://brew.sh) or
    [MacPorts](https://www.macports.org), for example:

        brew install libomp

    The configure helper first asks Homebrew for the `libomp` prefix, then
    checks MacPorts, then falls back to conventional Homebrew locations.

## Note On Compiler Support

The compiler configured into the running Perl is the authoritative toolchain.
`Alien::OpenMP` does not silently replace it based on `CC`.

Adding support for another compiler family should primarily require defining
its OpenMP compiler/linker profile and adding regression coverage. OpenMP is a
portable standard, but compiler flags, runtime libraries, and header locations
are not guaranteed to be portable across compiler implementations.

## Capability probing

Installation performs a real compile/link/run probe. The probe verifies that
OpenMP is enabled, `omp.h` is usable, the runtime links, and an OpenMP runtime
function can execute.

The probe deliberately does not require a particular number of OpenMP threads.
Runtime settings, containers, schedulers, or site policy may legitimately
restrict the thread count while OpenMP itself remains fully usable.

## CI coverage

The CI workflows cover Linux/GCC, Linux with a Perl built by Clang, Strawberry
Perl/MinGW GCC on Windows, Apple Clang on macOS with Homebrew `libomp`, and
FreeBSD/base Clang. Separate compiler coverage exercises the GCC and Clang
versions provided by the GitHub-hosted runner images, while Perl-version
coverage is kept separate from compiler-version coverage.

## Contributing

Additional compiler and platform support is welcome, but should include enough
information to define the compiler's OpenMP flags/runtime requirements and
regression tests that demonstrate the profile. Please use the
[GitHub issue tracker](https://github.com/Perl-OpenMP/p5-Alien-OpenMP/issues)
for unsupported toolchains when a tested patch is not practical.

# METHODS

## cflags

Return compiler flags used to enable OpenMP.

## lddlflags

Return linker flags used to enable/link OpenMP.

## openmp_version

Return the dated value advertised by the compiler's `_OPENMP` macro.

## version

Return the corresponding OpenMP specification version. This is the
specification date advertised by the compiler, not a guarantee that every
feature of that specification is implemented.

## Inline

Support `Inline::C`'s `with => 'Alien::OpenMP'` integration, including OpenMP
compiler/linker flags and `#include <omp.h>`:

    use Alien::OpenMP;
    use Inline C => 'DATA', with => 'Alien::OpenMP';

# AUTHOR

OODLER 577 <oodler@cpan.org>

# COPYRIGHT AND LICENSE

Copyright (C) 2021 by oodler577

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

[PDL](https://metacpan.org/pod/PDL),
[OpenMP::Environment](https://metacpan.org/pod/OpenMP%3A%3AEnvironment), and the
[GCC libgomp manual](https://gcc.gnu.org/onlinedocs/libgomp/index.html).
