#!/bin/env perl
#
# NaiveBayes の実行の差分
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use Storable qw/retrieve nstore/;

use JumanDictionary::Static;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug','input=s');

my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $mainDictionary = JumanDictionary::Static->new ($mainDicDir);
my $fnRank = &getFamilyNameRank ($mainDictionary);
my $fnList = retrieve ($opt->{input}) or die;

my @totalRank = sort { $fnList->{$b}->[1] <=> $fnList->{$a}->[1] or $b cmp $a } (keys (%$fnList));
my @mapRank = sort { $fnList->{$b}->[2] <=> $fnList->{$a}->[2] or $b cmp $a } (keys (%$fnList));
my @evRank = sort { $fnList->{$b}->[3] <=> $fnList->{$a}->[3] or $b cmp $a } (keys (%$fnList));

print ("rank\tORIG\tCOUNT\t\tMAP\t\tEV\n");
for (my $i = 0, my $l = scalar (@mapRank); $i < $l; $i++) {
    printf ("%04d\t%s\t%s (%d)\t%s (%d)\t%s (%d)\n", $i + 1,
	    $fnRank->[$i],
	    $totalRank[$i], $fnList->{$totalRank[$i]}->[1],
	    $mapRank[$i], $fnList->{$mapRank[$i]}->[2],
	    $evRank[$i], $fnList->{$evRank[$i]}->[3]);
}

1;

sub getFamilyNameRank {
    my ($mainDictionary) = @_;

    my $rv = [];
    foreach my $me (@{$mainDictionary->getAllMorphemes}) {
	next unless ($me->{'品詞細分類'} eq '人名');
	next unless ((my $v = $me->{'意味情報'}->{'人名'}));
	next unless ($v =~ /^日本\:姓\:(\d+)/);
	my $rank = $1 - 1;
	my $midasi = (keys (%{$me->{'見出し語'}}))[0];
	# 読みの重複は無視される
	$rv->[$rank] = $midasi;
    }
    return $rv;
}
