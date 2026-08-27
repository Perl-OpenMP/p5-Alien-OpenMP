use strict;
use warnings;
use Test::More;
use Test::Alien;
use Alien::OpenMP;

subtest 'syntax and interface' => sub {
  alien_ok 'Alien::OpenMP', 'public interface check for Alien::Base';
  is +Alien::OpenMP->install_type, 'system', 'no share install is possible';
};

subtest 'has options' => sub {
  like +Alien::OpenMP->cflags, qr{(?:-fopenmp|-Xclang\s+-fopenmp)}, 'OpenMP compiler switch present';
  like +Alien::OpenMP->lddlflags, qr{(?:-lomp|-fopenmp)}, 'OpenMP linker switch present';
};

subtest 'OpenMP version' => sub {
  like +Alien::OpenMP->openmp_version, qr{^[0-9]{6}$}, 'looks like a dated version';
  like +Alien::OpenMP->version, qr{^[0-9]+\.[0-9]+$}, 'looks like a decimal version';
};

done_testing;
