#!/bin/env perl
#
# 素性の所属割合を調査
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use ExampleList;
use NounCategorySpec;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'debug', 'verbose=i', 'input=s', 'fDB=s', 'compressed');

my $fDB = retrieve ($opt->{fDB}) or die;
my $id2type = [];
foreach my $type (keys (%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each (%$p))) {
	$id2type->[$p->{$key}] = $type;
    }
}
undef ($fDB);

my $list = {};
my $sum = 0;

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new ($input);
while ((my $example = $exampleList->readNext)) {
    foreach my $f (@{$example->{featureList}}) {
	my ($id, $v) = @$f;
	my $type = $id2type->[$id];
	$list->{$type}++;
	$sum++;
    }
}
$exampleList->readClose;

map {
    printf ("%s: %f\n", $_, $list->{$_} /  $sum);
} (keys (%$list));


1;
