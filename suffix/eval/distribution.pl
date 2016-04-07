#!/bin/env perl
#
# 品詞ごとに活用形の分布をカウントする
#

use strict;
use utf8;

# use Encode;
use Getopt::Long;
use KNP::Result; # Storable のために自分で load
use KNP::Morpheme;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');

use Storable qw (nstore);

my $suffixListFile = "/home/murawaki/research/lebyr/data/suffixThres";
my $distributionFile = "/home/murawaki/research/lebyr/data/distribution.storable";

my $distribution = {};

open (my $file, "<:utf8", $suffixListFile) or die;
while (<$file>) {
    chomp;

    if ($_ =~ /^\t(.+)/) {
	my ($posS, $katuyou2, $count) = split (/\t/, $1);
	$distribution->{$posS}->{$katuyou2} += $count;
    }
}
close ($file);

nstore ($distribution, $distributionFile) or die;

1;
