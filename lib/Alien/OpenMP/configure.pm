package Alien::OpenMP::configure;
use strict;
use warnings;
use Config;

our $CCNAME = $ENV{CC} || $Config::Config{ccname};
our $OS     = $^O;

my $checked   = 0;
my $supported = {
    gcc => {
        cflags        => ['-fopenmp'],
        libs          => ['-fopenmp'],
        auto_include  => join qq{\n}, ('#include <omp.h>'),
    },
    clang => {
        cflags        => [ '-Xclang', '-fopenmp' ],
        libs          => ['-lomp'],                 # this could be -Xpreprocessor
        auto_include  => join qq{\n}, ('#include <omp.h>'),
    },
};

sub auto_include {
  shift->_update_supported;
  return $supported->{$CCNAME}{auto_include} || q{};
}

sub cflags {
  shift->_update_supported;
  return join ' ', @{$supported->{$OS}{cflags} || $supported->{$CCNAME}{cflags} || []};
}

sub is_known {
  shift->_update_supported;
  return !!(exists($supported->{$OS}) || exists($supported->{$CCNAME}));
}

sub lddlflags { __PACKAGE__->libs }

sub libs {
  shift->_update_supported;
  return join ' ', @{$supported->{$OS}{libs} || $supported->{$CCNAME}{libs} || []};
}

sub unsupported {
  my ($self, $build) = (shift, shift);

  # build an array of messages
  my @msg = ("This version of $CCNAME does not support OpenMP");
  if ($CCNAME eq 'gcc' and $OS ne 'darwin') {
    push @msg, "This could be a bug, please record an issue https://github.com/Perl-OpenMP/p5-Alien-OpenMP/issues";
  }

  if ($OS eq 'darwin') {
    push @msg, "Support can be enabled by using Homebrew or Macports (https://clang-omp.github.io)";
    push @msg, "    brew install libomp (Homebrew https://brew.sh)";
    push @msg, "    port install libomp (Macports https://www.macports.org)";
  }

  # report messages using appropriate method
  if (ref($build)) {
    return if $build->install_prop->{alien_openmp_compiler_has_openmp};
    unshift @msg, "phase = @{[$build->meta->{phase}]}";
    $build->log($_) for @msg;
  }
  elsif ($build && (my $log = $build->can('log'))) {
    unshift @msg, "phase = @{[$build->meta->{phase}]}";
    $log->($_) for @msg;
  }
  else {
    warn join q{>}, __PACKAGE__, " $_\n" for @msg;
  }
  print "OS Unsupported\n";
}

sub version_from_preprocessor {
  my ($self, $lines) = @_;
  my $define_re = qr/^(?:.*_OPENMP\s)?([0-9]+)$/;
  my %runtime;
  ($runtime{openmp_version}) = map { (my $v = $_) =~ s/$define_re/$1/; $v } grep /$define_re/, split m{$/}, $lines;
  $runtime{version} = _openmp_defined($runtime{openmp_version});
  return \%runtime;
}

sub _openmp_defined {
  my $define = pop;
  # From https://github.com/jeffhammond/HPCInfo/blob/master/docs/Preprocessor-Macros.md
  my $versions = {200505 => '2.5', 200805 => '3.0', 201107 => '3.1', 201307 => '4.0', 201511 => '4.5', 201811 => '5.0'};
  return $versions->{$define || ''} || 'unknown';
}

# test support only
sub _reset { $checked = 0; }

sub _update_supported {
  return if $checked;
  # handles situation where $CCNAME is gcc as part of a path
  if ($CCNAME =~ m/\/gcc$/) {
    $CCNAME = 'gcc';
  }
  elsif ($OS eq 'darwin') {
    require File::Which;
    require Path::Tiny;

    # The issue here is that ccname=gcc and cc=cc as an interface to clang
    $supported->{darwin} = {cflags => ['-Xclang', '-fopenmp'], libs => ['-lomp'],};
    if (my $mp = File::Which::which('port')) {

      # macports /opt/local/bin/port
      my $mp_prefix = Path::Tiny->new($mp)->parent->parent;
      push @{$supported->{darwin}{cflags}}, "-I$mp_prefix/include/libomp";
      unshift @{$supported->{darwin}{libs}}, "-L$mp_prefix/lib/libomp";
    }
    else {
      # homebrew has the headers and library in /usr/local
      push @{$supported->{darwin}{cflags}}, "-I/usr/local/include";
      unshift @{$supported->{darwin}{libs}}, "-L/usr/local/lib";
    }
  }
  $checked++;
}

1;

=encoding utf8

=head1 NAME

Alien::OpenMP::configure - Install time configuration helper

=head1 SYNOPSIS

  # alienfile
  use Alien::OpenMP::configure;

  if (!Alien::OpenMP::configure->is_known) {
    Alien::OpenMP::configure->unsupported(__PACKAGE__);
    exit;
  }

  plugin 'Probe::CBuilder' => (
    cflags  => Alien::OpenMP::configure->cflags,
    libs    => Alien::OpenMP::configure->libs,
    ...
  );

=head1 DESCRIPTION

L<Alien::OpenMP::configure> is storage for the compiler flags required for multiple compilers on multiple systems and
an attempt to intelligently support them.

This module is designed to be used by the L<Alien::OpenMP::configure> authors and contributors, rather than end users.

=head1 METHODS

L<Alien::OpenMP::configure> implements the following methods.

=head2 cflags

Obtain the compiler flags for the compiler and architecture suitable for passing as C<cflags> to
L<Alien::Build::Plugin::Probe::CBuilder>.

=head2 is_known

Return a Boolean to indicate whether the compiler is known to this module.

=head2 lddlflags

A synonym for L</"libs">.

=head2 libs

Obtain the compiler flags for the compiler and architecture suitable for passing as C<libs> to
L<Alien::Build::Plugin::Probe::CBuilder>.

=head2 unsupported

Report using L<Alien::Build::Log> or L<warn|https://metacpan.org/pod/perlfunc#warn-LIST> that the compiler/architecture
combination is unsupported and provide minimal notes on any solutions. There is little to no guarding of the actual
state of support in this function.

=head2 version_from_preprocessor

Parse the output from the C preprocessor, filtering for the C<#define _OPENMP> to populate a hash with both the value
and the equivalent decimal version. The keys of the hash are C<openmp_version> and C<version>.

=cut
