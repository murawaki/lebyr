#!/bin/env perl
#
# DocumentPool::Tsubaki のテスト
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;

use DocumentPool::Tsubaki;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

print ("new request\n");

my $tsubaki = new DocumentPool::Tsubaki ({ query => '"ツンデレ"', results => 10 }, { 
    debug => 1 });
# workingDirectory => '/home/murawaki/tmp/tsundere2',
# cacheData => 1, saveData => 1, debug => 1 });

use Dumpvalue;
Dumpvalue->new->dumpValue ($tsubaki);

print ("here we get one document\n");

# exit;

my $document;
while (($document = $tsubaki->get)) {
    print $document->getAnnotation ('documentID'), "\n";
    # Dumpvalue->new->dumpValue ($document->getAnalysis ('raw'));
}
# Dumpvalue->new->dumpValue ($document);


1;
