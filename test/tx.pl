#!/bin/env perl
#
# tx のテスト
#
use strict;
# use warnings;
use utf8;

use blib '/home/murawaki/research/lebyr/tx/blib/lib';

use Encode qw /encode decode/;
use Getopt::Long;
use Text::Trie::Tx;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});

my $tx = Text::Trie::Tx->open ("idx") or die;

print $tx->getKeyNum, "\n";

# use Dumpvalue;
# Dumpvalue->new->dumpValue ($tx);

print decode ('utf8', $tx->prefixSearch (encode ('utf8', "あった"))), "\n";
# printf $tx->prefixSearch ('bar');

# my $result = $tx->predictiveSearchID (encode ('utf8', "あった")), "\n";
# for my $s (@$result) {
#     printf ("id: %d\n", $s);
# }

# my $result = $tx->predictiveSearch (encode ('utf8', "あった")), "\n";
# for my $s (@$result) {
#     printf ("key: %s\n", decode ('utf8', $s));
# }

my $result = $tx->commonPrefixSearchID (encode ('utf8', "あった")), "\n";
for my $s (@$result) {
    printf ("id: %d\n", $s);
}

my $result = $tx->commonPrefixSearch (encode ('utf8', "あった")), "\n";
for my $s (@$result) {
    printf ("key: %s\n", decode ('utf8', $s));
}

1;
