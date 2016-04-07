#!/bin/env perl
# -*- Mode: perl; tab-width: 4; indent-tabs-mode: nil; -*-
#
# jumanDiffSeq の結果をうけて評価する
#
use strict;
use utf8;

use Switch;
use Storable qw/retrieve/;

my $struct = retrieve ($ARGV[0]) or die;
die unless (defined ($struct->{result}));

my ($ccS, $ceS, $ecS, $eeS) = (0, 0, 0, 0);
my ($ccT, $ceT, $ecT, $eeT) = (0, 0, 0, 0);
foreach my $tmp (@{$struct->{result}}) {
    switch ($tmp->{seg}) {
	case 0 { $ccS++ }
	case 1 { $ceS++ }
	case 2 { $ecS++ }
	case 3 { $eeS++ }
	else { die }
    }
    switch ($tmp->{tag}) {
	case 0 { $ccT++ }
	case 1 { $ceT++ }
	case 2 { $ecT++ }
	case 3 { $eeT++ }
	else { die }
    }
}
printf ("total\t%d\n", $ccS + $ceS + $ecS + $eeS);
# printf ("seg\t%d\t%d\t%d\t%d\n", $ccS, $ceS, $ecS, $eeS);
# printf ("tag\t%d\t%d\t%d\t%d\n", $ccT, $ceT, $ecT, $eeT);
print ("\teC\tcC\teE\tcE\n");
printf ("seg\t%d\t%d\t%d\t%d\n", $ecS, $ccS, $eeS, $ceS);
printf ("tag\t%d\t%d\t%d\t%d\n", $ecT, $ccT, $eeT, $ceT);
