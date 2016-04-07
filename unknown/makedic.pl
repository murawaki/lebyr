#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Getopt::Long;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'debug', 'inputdir=s', 'outputdir=s');

use JumanDictionary::Static;

unless ( -d $opt->{inputdir} && -d $opt->{outputdir} ) {
    die ("invalid argument.\n");
}

my $mainDictionary = JumanDictionary::Static->makeDB($opt->{outputdir}, $opt->{inputdir}, { debug => $opt->{debug} } );

1;
