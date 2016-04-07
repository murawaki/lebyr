#!/bin/env perl
#
# NaiveBayes の実行の差分
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use NaiveBayes;
# use NaiveBayes2D;
use NounCategory;
use ExampleList;

use JumanDictionary::Static;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'compressed', 'nb=s', 'fDB=s', 'output=s');

my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $mainDictionary = JumanDictionary::Static->new ($mainDicDir);
my $fnList = &getFamilyNameList ($mainDictionary);

my $PN_ID = 1;

my $nb = retrieve ($opt->{'nb'}) or die;
# my $fDB = retrieve ($opt->{fDB}) or die;
# my $id2feature = [];
# foreach my $type (keys (%$fDB)) {
#     my $p = $fDB->{$type};
#     while ((my $key = each (%$p))) {
# 	$id2feature->[$p->{$key}] = "$type:$key";
#     }
# }
# undef ($fDB);

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);

# my $count = {}; # name -> 0 := MAP value, name -> 1 := expectation value
while ((my $example = $exampleList->readNext)) {
    my $name = $example->{name};
    next unless ($fnList->{$name});

    my $fCount = scalar (@{$example->{featureList}});
    $fnList->{$name}->[0]++; # example count
    $fnList->{$name}->[1] += $fCount; # feature count

    my $logProb = $nb->classify ($example);
    my $maxID = $nb->getMax ($logProb);
    if ($maxID == $PN_ID) {
	$fnList->{$name}->[2] += $fCount; # MAP
    }

    my $massList = [];
    my $sum = 0;
    my $base = int (-1 * $logProb->[0]);
    foreach my $l (@$logProb) {
	# a * C == exp (log (a * C)) == exp (log (a) + log (C))
	my $n = exp ($l + $base);
	$sum += $n;
	push (@$massList, $n);
    }
    $fnList->{$name}->[3] += $fCount * ($massList->[$PN_ID] / $sum);
}
$exampleList->readClose;

nstore ($fnList, $opt->{output}) or die;

1;

sub getFamilyNameList {
    my ($mainDictionary) = @_;

    my $rv = {};
    foreach my $me (@{$mainDictionary->getAllMorphemes}) {
	next unless ($me->{'品詞細分類'} eq '人名');
	next unless ((my $v = $me->{'意味情報'}->{'人名'}));
	next unless ($v =~ /^日本\:姓\:/);

	foreach my $midasi (keys (%{$me->{'見出し語'}})) {
	    $rv->{$midasi} = [0, 0, 0, 0];
	}
    }
    return $rv;
}
