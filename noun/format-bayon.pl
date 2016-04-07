#!/bin/env perl
#
# transform training data to bayon format
#
use strict;
use utf8;

use Dumpvalue;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use Storable qw/retrieve nstore/;

use ExampleList;
use Egnee::Util qw/dynamic_use/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { posWeight => 100 };
GetOptions($opt, 'debug', 'input=s', 'posWeight=i', 'compressed', 'cat2', 'fDB=s');
my $CATCLASS = ($opt->{'cat2'})? 'NounCategory2' : 'NounCategory';
dynamic_use($CATCLASS, 'getClassIDLength', 'index2classID');
my $nounCat = $CATCLASS->new;

my $fDB = retrieve($opt->{fDB}) or die;
my $id2feature = [];
foreach my $type (keys(%$fDB)) {
    my $p = $fDB->{$type};
    while ((my $key = each(%$p))) {
	$id2feature->[$p->{$key}] = "$type:$key";
    }
}
undef($fDB);

my $bias = {
    'cf:有る/ある:動:ガ格' => 10,
    'cf:居る/いる?射る/いる?鋳る/いる:動:ガ格' => 10,
    'cf:居る/いる:動:ガ格' => 10,
    'suf:ら' => 10,
    'suf:たち' => 10,
    'suf:達' => 10,
    'suf:ども' => 10,
};

# initialize
my $filepath = $opt->{input};
my $input = IO::File->new($filepath, 'r') or die;
$input->binmode(($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
my $exampleList = ExampleList->new($input);
while ((my $example = $exampleList->readNext)) {
    print($example->{name}, "\t");
    my $className = join('?', (map { $nounCat->getClassName (split(/\:/, $nounCat->index2classID($_))) } (split(/\?/, $example->{id})) ));
    printf("%s\t%s\t", $className, $opt->{posWeight}) if ($opt->{posWeight} > 0);

    my $featureString = '';
    foreach my $feature (@{$example->{featureList}}) {
	my $fname = $id2feature->[$feature->[0]];
	my $value = $bias->{$fname} || 1;
	$featureString .= "$fname\t$value\t";
    }
    chomp($featureString);
    print($featureString, "\n");
}
$exampleList->readClose;

1;
