use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config ();
use Alien::Build::MM;

my $abmm = Alien::Build::MM->new;
my $repo = 'oodler577/p5-Alien-OpenMP';
(my $dist = (my $pkg = 'Alien::OpenMP')) =~ s#::#-#g;
WriteMakefile($abmm->mm_args(
    NAME               => $pkg,
    DISTNAME           => $dist,
    AUTHOR             => q{OODLER 577 <oodler@cpan.org>},
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => '5.008009',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    TEST_REQUIRES => {
        'Test::More'      => 0,
    },
    PREREQ_PM => {
        'Test::More' => 0,
        'Alien::Base' => 0,
    },
    META_MERGE => {
        "meta-spec"    => { version => 2 },
        dynamic_config => 0,
        resources      => {
            x_IRC      => 'irc://irc.perl.org/#pdl',
            repository => {
                type => 'git',
                url  => "git\@github.com:$repo.git",
                web  => "https://github.com/$repo",
            },
            bugtracker => {
                web => "https://github.com/$repo/issues",
            },
            license => ['http://dev.perl.org/licenses/'],
        },
        prereqs => {
            develop => {
                requires => {
                    'Test::Pod::Coverage' => '1.08',
                    'Pod::Coverage'       => '0.18',
                    'Test::Pod'           => '1.00',
                    'Pod::Markdown'       => 0,
                    'Inline::C'           => 0,
                    'Dist::Zilla'         => 0,
                },
            },
            test => {
                recommends => {
                    'App::Prove' => '3.00',    # prove -j4
                },
            },
        },
    },
));

sub MY::postamble {
  $abmm->mm_postamble;
}
