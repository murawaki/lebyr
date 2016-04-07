#!/bin/env perl
# -*- Mode: perl; tab-width: 4; indent-tabs-mode: nil; -*-
#
# jumanDiffSeq の結果をうけて評価する
#
use strict;
use utf8;

use Switch;
use Storable qw/retrieve/;

my $struct1 = retrieve ($ARGV[0]) or die;
die unless (defined ($struct1->{result}));
my $struct2 = retrieve ($ARGV[1]) or die;
die unless (defined ($struct2->{result}));

my $type = 'seg';

my $total1 = [];
my $total2 = [];

my $total = scalar (@{$struct1->{result}});
my $matrix = [];
for (my $i = 0; $i < $total; $i++) {
    my $s1 = $struct1->{result}->[$i]->{$type};
    my $s2 = $struct2->{result}->[$i]->{$type};

    $total1->[$s1]++;
    $total2->[$s2]++;
    $matrix->[$s1]->[$s2]++;
}

my $actual = 0;
my $expected = 0;
for my $i (0..3) {
    $actual += $matrix->[$i]->[$i];
    $expected += ($total1->[$i] * $total2->[$i]) / $total;
}

my $kappa = ($actual - $expected) / ($total - $expected);
printf ("kappa: %f\n", $kappa);


# my ($ccS, $ceS, $ecS, $eeS) = (0, 0, 0, 0);
# my ($ccT, $ceT, $ecT, $eeT) = (0, 0, 0, 0);
# foreach my $tmp (@{$struct->{result}}) {
#     switch ($tmp->{seg}) {
# 	case 0 { $ccS++ }
# 	case 1 { $ceS++ }
# 	case 2 { $ecS++ }
# 	case 3 { $eeS++ }
# 	else { die }
#     }
#     switch ($tmp->{tag}) {
# 	case 0 { $ccT++ }
# 	case 1 { $ceT++ }
# 	case 2 { $ecT++ }
# 	case 3 { $eeT++ }
# 	else { die }
#     }
# }
# printf ("total\t%d\n", $ccS + $ceS + $ecS + $eeS);
# printf ("seg\t%d\t%d\t%d\t%d\n", $ccS, $ceS, $ecS, $eeS);
# printf ("tag\t%d\t%d\t%d\t%d\n", $ccT, $ceT, $ecT, $eeT);
