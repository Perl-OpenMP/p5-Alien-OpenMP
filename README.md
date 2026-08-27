# Alien::OpenMP

`Alien::OpenMP` encapsulates the compiler and linker settings needed to use OpenMP from Perl extensions and `Inline::C`.

## Supported compiler families

The conservative supported set remains:

- GCC, including MinGW GCC used by Strawberry Perl
- LLVM Clang (experimental)
- Apple Clang on macOS with an installed `libomp`
- FreeBSD's Clang toolchain

The running Perl's configured C compiler (`$Config{cc}`) is authoritative. `Alien::OpenMP` does not silently switch toolchains based on `CC`, because XS and Inline::C normally return to Perl's configured compiler and ABI settings.

Compiler family detection is based on predefined compiler macros rather than the executable filename. This allows versioned and target-prefixed GCC names such as `gcc-16`, `x86_64-linux-gnu-gcc`, and similar drivers to use the same GCC OpenMP profile.

## GCC

GCC uses `-fopenmp` for both compilation and runtime linkage. This applies to GNU GCC on macOS as well; it must not be mixed with LLVM's `-lomp` runtime.

## Clang

Upstream LLVM Clang uses `-fopenmp`.

Apple Clang requires a separate OpenMP runtime. Install one with Homebrew or MacPorts, for example:

    brew install libomp

The configure helper first asks Homebrew for `libomp`'s prefix, then checks MacPorts, then falls back to conventional Homebrew locations.

## Capability probing

Installation performs a real compile/link/run probe that verifies OpenMP is enabled, `omp.h` is usable, the runtime links, and an OpenMP runtime function can execute. The probe intentionally does not demand a particular thread count because runtime/site policy may legitimately limit threads.

## CI coverage

The workflows cover Linux/GCC, Linux with a Perl built by Clang, Strawberry Windows/MinGW GCC, Apple Clang/macOS with Homebrew libomp, and FreeBSD/base Clang. A separate compiler sweep builds Perl with GCC 10 through GCC 16.

## Inline::C

    use Alien::OpenMP;
    use Inline C => 'DATA', with => 'Alien::OpenMP';

`Alien::OpenMP` supplies the OpenMP compiler/linker flags and automatically includes `omp.h`.
