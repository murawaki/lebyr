#!/bin/env perl
#
# MorphemeGrammar のテスト
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;
use Dumpvalue;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});

use MorphemeGrammar;

# my $stem = "あー";
# my $stem = "リー";
# my $stem = "げげげ";
# my $stem = "あああ";
my $stem = "り患し";

my $status = &MorphemeGrammar::isVowelVerb ($stem);
print $status, "\n";

1;
