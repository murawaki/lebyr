#!/bin/env perl
#
# 素性データを表示
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use MultiClassPerceptron;
use MultiClassPerceptron2D;
use Egnee::Util qw/dynamic_use/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $CF_LENGTH = 50;
my $opt = { base => 1, contrast => 7, verbose => 1 };
GetOptions($opt, 'base=i', 'contrast=i', 'debug', 'verbose=i', 'model=s', 'fDB=s', 'normal', 'cat2', 'cat3');
my $CATCLASS = ($opt->{'cat3'})? 'NounCategory3' : (($opt->{'cat2'})? 'NounCategory2' : 'NounCategory');
dynamic_use($CATCLASS, 'getClassIDLength', 'index2classID');
my $nounCat = $CATCLASS->new;
my $CLASSID_LENGTH = $nounCat->classIDLength;
my $CATEGORY_LENGTH = $CLASSID_LENGTH / 2;

my $fDB = retrieve($opt->{fDB}) or die;
my $id2feature = [];
foreach my $type (keys(%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each(%$p))) {
	$id2feature->[$p->{$key}] = "$type:$key";
    }
}
undef($fDB);

my $size = scalar(@$id2feature);
my $mp = retrieve($opt->{model}) or die;
my $weightList = $mp->{weightList};
my $base = $opt->{base};
my $contrast = $opt->{contrast};
 outer:
    for (my $i = 0; $i < $size; $i++) {
	my $baseV = $weightList->[$base]->[$i];
	for (my $j = 0; $j < $CLASSID_LENGTH; $j++) {
	    my $v = $weightList->[$j]->[$i] || 0;
	    next outer if ($j != $base && $baseV <= $v);
	}
	my $contrastV = $weightList->[$contrast]->[$i] || 0;

	my $str = $id2feature->[$i];
	my $length;
	{
	    use bytes;
	    use Encode qw/encode/;
	    $length = length(encode ('euc-jp', $str));
	};
	for (my $j = $length; $j < $CF_LENGTH; $j++) {
	    $str .= ' ';
	}
	printf("$str\t%d\n", $baseV - $contrastV);
    }

1;
