#!/bin/env perl
#
# 品詞変更差戻しの検証
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
use KNP;

my $inputs = ['ある日', '空白だ', '空白を', '吐いた', '吐き', 'たき', '巻き卵'];
my $knp = new KNP;

foreach my $input (@$inputs) {
    my $result = $knp->parse ($input);
    &printResult ($result);
    print ("\n");
}

$inputs = ['ほりごたつ', 'なわばしご'];
foreach my $input (@$inputs) {
    my $result = $knp->parse ($input);
    for my $mrph ($result->mrph) {
	my $mrphO = &MorphemeUtilities::getOriginalMrph ($mrph, { revertVoicing => 1 });
	print $mrphO->spec;
    }
    print ("\n");
}

sub printResult {
    my ($result) = @_;

    for my $mrph ($result->mrph) {
	# printf ("%s\t%s\n", $mrph->spec, $mrph->repname);
	printf ("before\t%s\n", $mrph->repname);
	my $mrphO = &MorphemeUtilities::getOriginalMrph ($mrph);
	printf ("after\t%s\n", $mrphO->repname);
	printf ("genkei\t%s\n", $mrphO->genkei);

	if ($mrph->{doukei}) {
	    for (my $i = 0; $i < scalar (@{$mrph->{doukei}}); $i++) {
		my $mrph2 = $mrph->{doukei}->[$i];
		printf ("doukei before\t%s\n", $mrph->repname);
		printf ("doukei after\t%s\n", $mrphO->repname);
	    }
	}
    }
}

1;
