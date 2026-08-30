package Alien::OpenMP;

use strict;
use warnings;
use parent 'Alien::Base';
use Config ();
use Alien::OpenMP::configure ();

our $VERSION = '0.3.10';

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

=head1 DESCRIPTION

Alien::OpenMP provides the compiler and linker flags needed to enable OpenMP
for the C compiler configured into the running Perl.

The module intentionally follows Perl's C<$Config{cc}> toolchain.  Perl XS and
Inline::C builds normally inherit that compiler and its ABI/linker settings, so
an unrelated C<ENV{CC}> is not treated as an implicit request to switch
compilers.  ABI-compatible alternate compilers may be usable by applications,
but they are outside the default Alien::OpenMP toolchain contract.

=head2 Compilers Supported by this module

=over 4

=item C<gcc>

GCC uses C<-fopenmp> for compilation and runtime linkage.  Compiler family is
detected from predefined macros rather than the executable filename, so names
such as C<gcc-16> and target-prefixed GCC drivers are supported.

=item C<clang> EXPERIMENTAL

Upstream LLVM Clang uses C<-fopenmp>.  Apple Clang on macOS requires an
external OpenMP runtime (normally C<libomp> from Homebrew or MacPorts), for
which Alien::OpenMP adds the required include/library paths.

=back

=head2 Note On Compiler Support

The compiler configured into the running Perl is the authoritative toolchain.
A compile/link probe verifies that the selected flags, C<omp.h>, and OpenMP
runtime actually work before installation succeeds.

=head1 METHODS

=head2 cflags

Return compiler flags used to enable OpenMP.

=head2 lddlflags

Return linker flags used to enable/link OpenMP.

=head2 openmp_version

Return the dated value advertised by the compiler's C<_OPENMP> macro.

=head2 version

Return the corresponding OpenMP specification version.  This is the
specification date advertised by the compiler, not a guarantee that every
feature of that specification is implemented.

=head2 Inline

Support Inline::C's C<with =E<gt> 'Alien::OpenMP'> integration, including
OpenMP compiler/linker flags and C<#include E<lt>omp.hE<gt>>.

=head1 AUTHOR

OODLER 577 <oodler@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by oodler577

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

L<PDL>, L<OpenMP::Environment>, L<https://gcc.gnu.org/onlinedocs/libgomp/index.html>.

=cut
