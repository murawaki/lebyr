use strict;
use 5.008008;

use ExtUtils::MakeMaker;

our $CC = 'g++';
our $tx_prefix = '$(HOME)/local'; # bad hack

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Text::Trie::Tx',
    VERSION_FROM      => 'lib/Text/Trie/Tx.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    CC                => $CC,
    LD                => '$(CC)',
    LDDLFLAGS          => "-shared -ltx -L$tx_prefix/lib",
    LIBS              => '-ltx', # e.g., '-lm'
    # DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => "-I. -I$tx_prefix/include/tx", # e.g., '-I. -I/usr/include/other'
    XSOPT             => '-C++',
    # Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Text/Trie/Tx.pm', # retrieve abstract from module
       AUTHOR         => 'MURAWAKI Yugo <murawaki@kuee.kyoto-u.ac.jp>') : ()),
);
