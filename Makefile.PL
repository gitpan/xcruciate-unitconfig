use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Xcruciate::UnitConfig',
    VERSION_FROM      => 'lib/Xcruciate/UnitConfig.pm', # finds $VERSION
    PREREQ_PM         => {Xcruciate::Utils => 0.05}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Xcruciate/UnitConfig.pm', # retrieve abstract from module
       AUTHOR         => 'Mark Howe <melonman@cpan.org>') : ()),
);
