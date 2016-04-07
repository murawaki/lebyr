#!/bin/env perl

use strict;
use utf8;

use Encode;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'debug');


use KNP;
use Analyzer::Juman;
my $knpResult = KNP->new->parse("京都の殺しをみた。");
my $jumanResult = Analyzer::Juman->knp2juman($knpResult);
print $jumanResult->spec;

1;
