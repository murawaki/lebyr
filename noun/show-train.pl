#!/bin/env perl
#
# 名詞ごとに格フレームを集約
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use NounCategorySpec;
use ExampleList;
require 'common.pl';

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1 };
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'fDB=s', 'compressed', 'length=i');

my $nounCat = NounCategorySpec->new;
unless ($opt->{length}) {
    $opt->{length} = $nounCat->LENGTH;
}

my $fDB = retrieve ($opt->{fDB}) or die;
my $id2feature = [];
foreach my $type (keys (%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each (%$p))) {
	$id2feature->[$p->{$key}] = "$type:$key";
    }
}
undef ($fDB);

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);
while ((my $example = $exampleList->readNext)) {
    printf ("%s\t%s\t%s\t%s\n\n",
	    $example->{name},
	    join ('?', map { $nounCat->getClassFromID ($_) }
		           (split (/\?/, $example->{id})) ),
	    $example->{from},
	    join ("\t", (map { $id2feature->[$_->[0]] } (@{$example->{featureList}}) )) );
}
$exampleList->readClose;

1;
