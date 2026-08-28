use strict;
use warnings;
use Test::More;
use Alien::OpenMP::configure;
use Capture::Tiny qw(capture);

sub profile {
  my (%arg) = @_;
  local $Alien::OpenMP::configure::CCNAME = $arg{cc};
  local $Alien::OpenMP::configure::OS = $arg{os} || 'linux';
  local $Alien::OpenMP::configure::COMPILER_FAMILY = $arg{family};
  Alien::OpenMP::configure->_reset;
  return {
    known  => Alien::OpenMP::configure->is_known,
    family => Alien::OpenMP::configure->compiler_family,
    cflags => Alien::OpenMP::configure->cflags,
    libs   => Alien::OpenMP::configure->libs,
  };
}

subtest 'compiler macro identification' => sub {
  is Alien::OpenMP::configure::_compiler_family_from_defines("#define __GNUC__ 16\n"), 'gcc', 'GCC';
  is Alien::OpenMP::configure::_compiler_family_from_defines("#define __GNUC__ 4\n#define __clang__ 1\n"), 'clang', 'Clang wins over GCC compatibility macro';
  is Alien::OpenMP::configure::_compiler_family_from_defines("#define SOMETHING 1\n"), 'unknown', 'unknown compiler';
};

subtest 'GCC names use one capability profile' => sub {
  for my $cc (qw/gcc gcc-16 x86_64-linux-gnu-gcc aarch64-linux-gnu-gcc/) {
    my $p = profile(cc => $cc, family => 'gcc');
    ok $p->{known}, "$cc known";
    is $p->{cflags}, '-fopenmp', "$cc cflags";
    is $p->{libs}, '-fopenmp', "$cc libs";
  }
};

subtest 'GNU GCC on Darwin keeps libgomp toolchain' => sub {
  my $p = profile(cc => 'gcc-16', family => 'gcc', os => 'darwin');
  is $p->{cflags}, '-fopenmp', 'GCC compile flag';
  is $p->{libs}, '-fopenmp', 'GCC links via GCC/libgomp, not LLVM -lomp';
  unlike $p->{libs}, qr/-lomp/, 'does not mix LLVM runtime into GCC';
};

subtest 'upstream clang' => sub {
  my $p = profile(cc => 'clang', family => 'clang', os => 'linux');
  ok $p->{known}, 'clang known';
  is $p->{cflags}, '-fopenmp', 'clang cflags';
  is $p->{libs}, '-fopenmp', 'clang linker driver selects runtime';
};

subtest 'FreeBSD follows actual compiler family' => sub {
  my $gcc = profile(cc => 'gcc', family => 'gcc', os => 'freebsd');
  is $gcc->{family}, 'gcc', 'FreeBSD GCC remains GCC';
  is $gcc->{libs}, '-fopenmp', 'FreeBSD GCC uses GCC linkage';
  my $clang = profile(cc => 'cc', family => 'clang', os => 'freebsd');
  is $clang->{family}, 'clang', 'FreeBSD base cc detected as clang';
  is $clang->{cflags}, '-fopenmp', 'FreeBSD clang flag';
};

subtest 'unknown is unsupported' => sub {
  local $Alien::OpenMP::configure::CCNAME = 'xyz-cc';
  local $Alien::OpenMP::configure::OS = 'linux';
  local $Alien::OpenMP::configure::COMPILER_FAMILY = 'unknown';
  Alien::OpenMP::configure->_reset;
  ok !Alien::OpenMP::configure->is_known, 'not known';
  is(Alien::OpenMP::configure->cflags, q{}, 'empty cflags');
  is(Alien::OpenMP::configure->libs, q{}, 'empty libs');
  my ($stdout, $stderr) = capture { Alien::OpenMP::configure->unsupported };
  like $stdout, qr/^OS Unsupported/, 'MakeMaker-compatible unsupported marker';
  like $stderr, qr/xyz-cc/, 'diagnostic names compiler';
};

subtest 'preprocessor parsing' => sub {
  my $result = Alien::OpenMP::configure->version_from_preprocessor("#define _OPENMP 201811\n#define __GNUC__ 9\n");
  is_deeply $result, {openmp_version => '201811', version => '5.0'}, 'OpenMP 5.0';
  my $six = Alien::OpenMP::configure->version_from_preprocessor("# define _OPENMP 202411\n");
  is_deeply $six, {openmp_version => '202411', version => '6.0'}, 'OpenMP 6.0';
  my $unknown = Alien::OpenMP::configure->version_from_preprocessor("#define __GNUC__ 16\n");
  is_deeply $unknown, {openmp_version => undef, version => 'unknown'}, 'no _OPENMP';
};

done_testing;

