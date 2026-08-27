package Alien::OpenMP::configure;
use strict;
use warnings;
use Config;

# Alien::OpenMP describes the extension toolchain of the running Perl.
# Do not silently let ENV{CC} select a compiler different from Config{cc};
# downstream XS/Inline tooling normally returns to Perl's configured compiler.
our $CCNAME = $Config::Config{cc};
our $OS     = $^O;

# Test hook.  Production code leaves this undefined and detects the compiler
# from its predefined macros.
our $COMPILER_FAMILY;

my $checked = 0;
my $profile;

sub auto_include {
  shift->_update_supported;
  return $profile->{auto_include} || q{};
}

sub cflags {
  shift->_update_supported;
  return join ' ', @{$profile->{cflags} || []};
}

sub is_known {
  shift->_update_supported;
  return !!$profile->{known};
}

sub lddlflags { __PACKAGE__->libs }

sub libs {
  shift->_update_supported;
  return join ' ', @{$profile->{libs} || []};
}

sub compiler_family {
  shift->_update_supported;
  return $profile->{family};
}

sub unsupported {
  my ($self, $build) = (shift, shift);
  my $family = eval { $self->compiler_family } || 'unknown';
  my @msg = ("Compiler '$CCNAME' ($family) does not have a supported OpenMP configuration");

  if ($OS eq 'darwin' && $family eq 'clang') {
    push @msg, 'Apple Clang requires an OpenMP runtime such as Homebrew or MacPorts libomp';
    push @msg, '    brew install libomp';
    push @msg, '    port install libomp';
  }

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
  my ($define) = $lines =~ /^\s*#\s*define\s+_OPENMP\s+([0-9]+)\b/m;
  return {
    openmp_version => $define,
    version        => _openmp_defined($define),
  };
}

sub _openmp_defined {
  my $define = pop;
  my $versions = {
    200505 => '2.5',
    200805 => '3.0',
    201107 => '3.1',
    201307 => '4.0',
    201511 => '4.5',
    201811 => '5.0',
    202011 => '5.1',
    202111 => '5.2',
    202411 => '6.0',
  };
  return $versions->{$define || ''} || 'unknown';
}

sub _reset {
  $checked = 0;
  $profile = undef;
}

sub _update_supported {
  return if $checked;
  require File::Basename;

  my $command = $CCNAME || q{};
  my $basename = File::Basename::basename($command);
  my $family = $COMPILER_FAMILY || _compiler_flavour();

  $profile = {
    known        => 0,
    family       => $family,
    cflags       => [],
    libs         => [],
    auto_include => '#include <omp.h>',
  };

  if ($family eq 'gcc') {
    # GCC has used -fopenmp to enable compilation and runtime linkage since
    # its original OpenMP support.  This is also correct for GNU GCC on macOS.
    $profile->{known}  = 1;
    $profile->{cflags} = ['-fopenmp'];
    $profile->{libs}   = ['-fopenmp'];
  }
  elsif ($family eq 'clang') {
    $profile->{known} = 1;
    if ($OS eq 'darwin') {
      $profile->{cflags} = [ '-Xclang', '-fopenmp' ];
      $profile->{libs}   = ['-lomp'];
      _add_darwin_libomp_paths($profile);
    }
    else {
      # Upstream LLVM Clang accepts -fopenmp directly.  Probe::CBuilder is the
      # final authority and will reject installations lacking headers/runtime.
      $profile->{cflags} = ['-fopenmp'];
      $profile->{libs}   = ['-fopenmp'];
    }
  }

  # Keep basename available for diagnostics without using it as the primary
  # compiler-family detector.  This supports gcc-16, target-prefixed gcc, etc.
  $CCNAME = $command;
  $checked++;
}

sub _add_darwin_libomp_paths {
  my ($p) = @_;
  require File::Which;
  require Path::Tiny;

  if (my $brew = File::Which::which('brew')) {
    my $prefix = qx{$brew --prefix libomp 2>/dev/null};
    chomp $prefix;
    if ($prefix) {
      push @{$p->{cflags}}, "-I$prefix/include";
      unshift @{$p->{libs}}, "-L$prefix/lib";
      return;
    }
  }

  if (my $port = File::Which::which('port')) {
    my $prefix = Path::Tiny->new($port)->parent->parent;
    push @{$p->{cflags}}, "-I$prefix/include/libomp";
    unshift @{$p->{libs}}, "-L$prefix/lib/libomp";
    return;
  }

  # Conservative fallbacks for conventional Intel/Apple-Silicon Homebrew.
  push @{$p->{cflags}}, '-I/usr/local/opt/libomp/include', '-I/opt/homebrew/opt/libomp/include';
  unshift @{$p->{libs}}, '-L/usr/local/opt/libomp/lib', '-L/opt/homebrew/opt/libomp/lib';
}

sub _compiler_flavour {
  my $defines = _compiler_defines();
  return _compiler_family_from_defines($defines);
}

sub _compiler_family_from_defines {
  my ($defines) = @_;
  return 'clang' if $defines =~ /^\s*#\s*define\s+__clang__\b/m;
  return 'gcc'   if $defines =~ /^\s*#\s*define\s+__GNUC__\b/m;
  return 'unknown';
}

sub _openmp_defines {
  my ($self) = @_;
  require Text::ParseWords;
  my @flags = Text::ParseWords::shellwords($self->cflags || q{});
  return _compiler_defines(@flags);
}

sub _compiler_defines {
  my @extra = @_;

  require File::Temp;
  require IPC::Open3;
  require Text::ParseWords;

  my @cc = Text::ParseWords::shellwords($CCNAME || q{});
  return q{} unless @cc;

  # Do not drive the preprocessor through stdin.  Strawberry Perl/MinGW GCC
  # can hang when gcc's stdin/stdout/stderr are all connected to open3 pipes.
  # Use a real temporary C file and direct stdout/stderr to temporary files.
  # Passing already-open output handles to open3 avoids pipe-buffer deadlocks.
  my ($source_fh, $source) = File::Temp::tempfile(SUFFIX => '.c', UNLINK => 0);
  print {$source_fh} "\n";
  close $source_fh;

  my ($out_fh, $out_name) = File::Temp::tempfile(UNLINK => 1);
  my ($err_fh, $err_name) = File::Temp::tempfile(UNLINK => 1);

  my $in;
  my $out = '>&' . fileno($out_fh);
  my $err = '>&' . fileno($err_fh);
  my $pid = eval {
    IPC::Open3::open3(
      $in,
      $out,
      $err,
      @cc,
      @extra,
      qw(-dM -E),
      $source,
    );
  };
  unless ($pid) {
    unlink $source;
    close $out_fh;
    close $err_fh;
    return q{};
  }

  close $in if $in;
  waitpid $pid, 0;
  my $status = $?;
  unlink $source;

  seek $out_fh, 0, 0 or return q{};
  local $/;
  my $defines = <$out_fh> || q{};

  close $out_fh;
  close $err_fh;

  return $status == 0 ? $defines : q{};
}

1;

=encoding utf8

=head1 NAME

Alien::OpenMP::configure - Install time configuration helper

=head1 DESCRIPTION

Internal helper for identifying the C compiler configured into the running
Perl and supplying the OpenMP flags used by Alien::OpenMP.  Compiler family
is detected from predefined compiler macros rather than executable names, so
versioned and target-prefixed GCC drivers are handled without special cases.

The running Perl's C<$Config{cc}> is authoritative.  C<ENV{CC}> is deliberately
not used to switch toolchains because normal XS and Inline::C builds inherit
Perl's configured compiler and ABI settings.

=head1 METHODS

=head2 auto_include

Return the OpenMP include inserted for Inline::C.

=head2 cflags

Return compiler flags that enable OpenMP.

=head2 compiler_family

Return C<gcc>, C<clang>, or C<unknown> for the configured compiler.

=head2 is_known

Return true when this compiler/platform has a known OpenMP configuration.
The subsequent compile/link probe remains the final capability check.

=head2 lddlflags

A synonym for L</libs>.

=head2 libs

Return link flags needed for the OpenMP runtime.

=head2 unsupported

Report an unsupported compiler/platform combination.

=head2 version_from_preprocessor

Parse C<#define _OPENMP> from preprocessor output and return both its dated
value and the corresponding OpenMP specification version.  This indicates the
specification date advertised by the compiler; it is not a guarantee that every
feature in that specification is implemented.

=cut
