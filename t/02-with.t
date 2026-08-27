BEGIN {
  $ENV{LIBOMP_USE_HIDDEN_HELPER_TASK} = $ENV{LIBOMP_NUM_HIDDEN_HELPER_THREADS} = 0 if $^O eq 'darwin';
}
use strict;
use warnings;
use Test::More;
use Test::Needs 'Inline::C';
use Alien::OpenMP;
use File::Temp ();

Inline->import(
  C           => do { local $/ = undef; <DATA> },
  filters     => [ sub { (my $filt = $_[0]) =~ s/^__C__$//mg; $filt } ],
  with        => q/Alien::OpenMP/,
  directory   => (my $tmp = File::Temp::tempdir()),
  build_noisy => !!$ENV{HARNESS_IS_VERBOSE},
);

# Exercise real parallel execution without demanding very large thread counts
# that may be prohibited by CI containers, schedulers, or site policy.
for my $num_threads (qw/1 2 4/) {
  is test($num_threads), $num_threads, "compiled OpenMP program works with $num_threads thread(s)";
}

my $config_ref = Alien::OpenMP->Inline('C');
like $config_ref->{CCFLAGSEX}, qr/(?:-fopenmp|-Xclang\s+-fopenmp)/, 'Inline CCFLAGSEX';
like $config_ref->{LDDLFLAGS}, qr/(?:-lomp|-fopenmp)/, 'Inline LDDLFLAGS';
is $config_ref->{AUTO_INCLUDE}, q{#include <omp.h>}, 'Inline AUTO_INCLUDE';

done_testing;

__DATA__
__C__
#include <stdio.h>
int test(int num_threads) {
  omp_set_dynamic(0);
  omp_set_num_threads(num_threads);
  int ans = 0;
  #pragma omp parallel
  {
    #pragma omp master
    ans = omp_get_num_threads();
  }
  return ans;
}
