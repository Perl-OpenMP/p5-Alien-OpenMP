# NAME

Alien::OpenMP - Encapsulate system info for OpenMP

# SYNOPSIS

    use Alien::OpenMP;
    say Alien::OpenMP->cflags; # e.g. -fopenmp if GCC
    say Alien::OpenMP->lddlflags; # e.g. -fopenmp if GCC

# DESCRIPTION

Encapsulates knowledge of per-compiler or per-environment information
so consuming modules don't need to know. Won't install if no OpenMP
environment available.

# AUTHOR

OODLER 577 <oodler@cpan.org>

# SEE ALSO

[PDL](https://metacpan.org/pod/PDL), [OpenMP::Environment](https://metacpan.org/pod/OpenMP%3A%3AEnvironment).
