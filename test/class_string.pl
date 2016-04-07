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

my $input = "県";
my $knp = new KNP;
my $result = $knp->parse ($input);
my $mrph = $result->mrph (0);
print $mrph->spec;
print &getClassString ($mrph), "\n";


sub getClassString {
    my ($mrph) = @_;

    my $cat = '';
    my $bunrui = $mrph->bunrui;
    my $genkei = $mrph->genkei;

    if ($mrph->imis =~ /カテゴリ\:([^\s\"]+)/) {
	$cat = $1;
    }
    my $class = "$genkei:$bunrui:$cat";
    my $classList = { $class => 1 };

    if ($mrph->{doukei}) {
	my @doukeiList;
	for (my $i = 0; $i < scalar (@{$mrph->{doukei}}); $i++) {
	    my $mrph2 = $mrph->{doukei}->[$i];
	    my $bunrui .= $mrph2->bunrui;
	    my $genkei .= $mrph2->genkei;
	    my $cat = '';
	    if ($mrph2->imis =~ /カテゴリ\:([^\s\"]+)/) {
		$cat = $1;
	    }
	    my $class = "$genkei:$bunrui:$cat";
	    $classList->{$class} = 1;
	}
    }
    return join ('?', keys (%$classList));
}


1;
