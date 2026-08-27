# Contributing

Please report bugs and feature requests at the project issue tracker and include `perl -V`, the compiler command from `$Config{cc}`, compiler version output, operating system, and the Alien::OpenMP test output.

Changes should include regression tests. Compiler support should be based on compiler-family/capability detection rather than executable-name special cases where practical.

Use Dist::Zilla for development and release preparation. Run the normal test suite and, where applicable, the platform/compiler CI workflows before release.
