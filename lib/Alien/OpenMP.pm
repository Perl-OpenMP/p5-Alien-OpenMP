package Alien::OpenMP;

use strict;
use warnings;
use parent 'Alien::Base';
use Config ();
use Alien::OpenMP::configure ();

our $VERSION = '0.3.9';

sub lddlflags { shift->libs }
sub openmp_version { shift->runtime_prop->{openmp_version} }

sub Inline {
  my ($self, $lang) = @_;
  my $params = $self->SUPER::Inline($lang);
  $params->{CCFLAGSEX} = delete $params->{INC};
  return {
    %$params,
    LDDLFLAGS    => join(q{ }, $Config::Config{lddlflags}, $self->lddlflags()),
    AUTO_INCLUDE => $self->runtime_prop->{auto_include},
  };
}

1;

__END__

=head1 NAME

Alien::OpenMP - Encapsulate system info for OpenMP

=head1 SYNOPSIS

    use Alien::OpenMP;
    say Alien::OpenMP->cflags;
    say Alien::OpenMP->lddlflags;
    say Alien::OpenMP->auto_include;

    use Inline C => 'DATA', with => 'Alien::OpenMP';

=head1 DESCRIPTION

Alien::OpenMP provides the compiler and linker settings needed to enable
OpenMP for the C compiler configured into the running Perl. It is intended for
Perl extensions and consumers such as C<Inline::C> that use Perl's configured C
toolchain.

The module intentionally follows Perl's C<$Config{cc}> toolchain. Perl XS and
C<Inline::C> builds normally inherit that compiler and its ABI/linker settings,
so an unrelated C<CC> environment variable is not treated as an implicit
request to switch compilers. ABI-compatible alternate compilers may be usable
by applications, but they are outside the default Alien::OpenMP toolchain
contract.

Compiler family detection is based on predefined compiler macros rather than
the compiler executable filename. This permits versioned and target-prefixed
GCC drivers such as C<gcc-16> and C<x86_64-linux-gnu-gcc> to use the same GCC
OpenMP profile.

=head2 Compilers Supported by this module

The conservative supported compiler families are:

=over 4

=item C<gcc>

GCC uses C<-fopenmp> for both compilation and runtime linkage. This includes
MinGW GCC used by Strawberry Perl and GNU GCC on macOS. GNU GCC on macOS uses
its GCC OpenMP runtime and must not be mixed with LLVM's C<-lomp> runtime.

=item C<clang> EXPERIMENTAL

Upstream LLVM Clang uses C<-fopenmp>. This includes FreeBSD's Clang toolchain
when the required OpenMP runtime is available.

Apple Clang on macOS requires a separate OpenMP runtime, normally C<libomp>.
It can be installed with L<Homebrew|https://brew.sh> or
L<MacPorts|https://www.macports.org>, for example:

    brew install libomp

The configure helper first asks Homebrew for the C<libomp> prefix, then checks
MacPorts, then falls back to conventional Homebrew locations.

=back

=head2 Note On Compiler Support

The compiler configured into the running Perl is the authoritative toolchain.
Alien::OpenMP does not silently replace it based on C<CC>.

Adding support for another compiler family should primarily require defining
its OpenMP compiler/linker profile and adding regression coverage. OpenMP is a
portable standard, but compiler flags, runtime libraries, and header locations
are not guaranteed to be portable across compiler implementations.

=head2 Capability probing

Installation performs a real compile/link/run probe. The probe verifies that
OpenMP is enabled, C<omp.h> is usable, the runtime links, and an OpenMP runtime
function can execute.

The probe deliberately does not require a particular number of OpenMP threads.
Runtime settings, containers, schedulers, or site policy may legitimately
restrict the thread count while OpenMP itself remains fully usable.

=head2 CI coverage

The CI workflows cover Linux/GCC, Linux with a Perl built by Clang, Strawberry
Perl/MinGW GCC on Windows, Apple Clang on macOS with Homebrew C<libomp>, and
FreeBSD/base Clang. Separate compiler coverage exercises the GCC and Clang
versions provided by the GitHub-hosted runner images, while Perl-version
coverage is kept separate from compiler-version coverage.

=head2 Contributing

Additional compiler and platform support is welcome, but should include enough
information to define the compiler's OpenMP flags/runtime requirements and
regression tests that demonstrate the profile. Please use the
L<GitHub issue tracker|https://github.com/Perl-OpenMP/p5-Alien-OpenMP/issues>
for unsupported toolchains when a tested patch is not practical.

=head1 METHODS

=head2 cflags

Return compiler flags used to enable OpenMP.

=head2 lddlflags

Return linker flags used to enable/link OpenMP.

=head2 openmp_version

Return the dated value advertised by the compiler's C<_OPENMP> macro.

=head2 version

Return the corresponding OpenMP specification version. This is the
specification date advertised by the compiler, not a guarantee that every
feature of that specification is implemented.

=head2 Inline

Support C<Inline::C>'s C<with =E<gt> 'Alien::OpenMP'> integration, including
OpenMP compiler/linker flags and C<#include E<lt>omp.hE<gt>>:

    use Alien::OpenMP;
    use Inline C => 'DATA', with => 'Alien::OpenMP';

=head1 AUTHOR

OODLER 577 <oodler@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by oodler577

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<PDL>, L<OpenMP::Environment>, and
L<GCC libgomp manual|https://gcc.gnu.org/onlinedocs/libgomp/index.html>.

=cut
