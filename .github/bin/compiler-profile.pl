#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Alien::OpenMP::configure ();

my ($cc) = @ARGV;
die "usage: $0 COMPILER\n" if !defined($cc) || $cc eq q{};

{
  no warnings 'once';
  local $Alien::OpenMP::configure::CCNAME = $cc;
  local $Alien::OpenMP::configure::COMPILER_FAMILY;
  Alien::OpenMP::configure->_reset;

  print join(
    "\t",
    Alien::OpenMP::configure->compiler_family,
    Alien::OpenMP::configure->cflags,
    Alien::OpenMP::configure->libs,
  ), "\n";
}
