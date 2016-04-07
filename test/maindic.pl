#!/usr/bin/env perl

use strict;
use utf8;
use Getopt::Long;
use Encode qw/decode/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'mixed', 'debug', 'inputdir=s', 'outputdir=s');

use Dumpvalue;
use JumanDictionary::Static;
use JumanDictionary::Mixed;

my $dicList = ['/home/murawaki/research/lebyr/data/dic',
	       '/home/murawaki/research/lebyr/data/wikipediadic'];
my $mainDictionary;
if ($opt->{mixed}) {
    $mainDictionary = JumanDictionary::Mixed->new;
    foreach my $dic (@$dicList) {
	$mainDictionary->add(JumanDictionary::Static->new($dic));
    }
} else {
    $mainDictionary = JumanDictionary::Static->new($dicList->[0]);
}
Dumpvalue->new->dumpValue($mainDictionary->getMorpheme('共起'));

my $meList = $mainDictionary->getAllMorphemes;
my $nounCount = 0;
foreach my $me (@$meList) {
    next unless ($me->{'品詞'} eq '名詞');
    my $flag = 0;
    if ($me->{'品詞細分類'} eq '人名'
	|| $me->{'品詞細分類'} eq '地名'
	|| $me->{'品詞細分類'} eq '組織名'
	|| $me->{'品詞細分類'} eq '固有名詞'
	|| defined($me->{'意味情報'}->{'カテゴリ'})) {
	$nounCount += keys(%{$me->{'見出し語'}})
    }
    # next unless ($me->{'品詞'} eq '動詞');
    # my $yomi = $me->{'読み'};
    # my $stem = substr($yomi, 0, length ($yomi) - 1);

    # if ($stem =~ /っ$/) {
    # 	Dumpvalue->new->dumpValue($me);
    # }
    # if ($stem =~ /ん$/) {
    # 	Dumpvalue->new->dumpValue($me);
    # }
    # if ($stem =~ /ー$/) {
    # 	Dumpvalue->new->dumpValue($me);
    # }
}
printf STDERR ("%d nouns has semantic labels\n", $nounCount);

# $meList = $mainDictionary->getMorpheme('かう');
# Dumpvalue->new->dumpValue($meList);

# while ((my $midasi = each(%{$mainDictionary->{midasiDB}}))) {
#     my $mes = $mainDictionary->{midasiDB}->{$midasi};
#     my @tmp = unpack("(LS)*", $mes);
#     $midasi = decode('utf8', $midasi);
#     print("$midasi\n") if (scalar(@tmp) > 2);
# }

1;
