#!/bin/env perl
#
# 連濁の差戻し
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;
use Dumpvalue;

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

use MorphemeUtilities;
use Juman;
use KNP;

my $inputs = ['なわばしご', 'ほりごたつ'];
my $knp = new KNP;
my $juman = new Juman;

foreach my $input (@$inputs) {
    my $result = $juman->analysis ($input);
    # my $result = $knp->parse ($input);
    &printResult ($result);
    print ("\n");
}

sub printResult {
    my ($result) = @_;

    for my $mrph ($result->mrph) {
	printf ("%s\t%s\n", $mrph->spec);
	# printf ("%s\t%s\n", $mrph->spec, $mrph->repname);
	# printf ("before\t%s\n", $mrph->repname);
	my $mrphO = &MorphemeUtilities::revertVoicing ($mrph);
	printf ("%s\t%s\n", $mrphO->spec);
	# printf ("after\t%s\n", $mrphO->repname);
	# printf ("genkei\t%s\n", $mrphO->genkei);
    }
}

1;
