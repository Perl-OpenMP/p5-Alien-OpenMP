use strict;
use warnings;
use Test::More tests => 9;

use FindBin qw/$Bin/;
use lib qq{$Bin/../lib};

use Alien::OpenMP;
use Inline (
    C           => 'DATA',
    with        => qw/Alien::OpenMP/,
);

for my $num_threads (qw/1 2 4 8 16 32 64 128 256/) {
    is test($num_threads), $num_threads, qq{Ensuring compiled OpenMP program works as expected. Threads = $num_threads};
}

__DATA__

__C__
#include <omp.h>
#include <stdio.h>
int test(int num_threads) {
  omp_set_num_threads(num_threads);
  int ans = 0;
  #pragma omp parallel
    #pragma omp master
      ans = omp_get_num_threads(); // done in parallel section, but only by master thread (0)
  return ans;
}
