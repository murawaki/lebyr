#!/bin/env perl
#
# 文のリストから、未知語獲得対象外の文を除いて出力
#
use strict;
use utf8;

use UnknownWordDetector;

use Dumpvalue;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':encoding(euc-jp)');

# my %opt;
# GetOptions (\%opt, 'spec=s', 'dicdir=s', 'debug', 'log=s');

my $ruleFile = '/home/murawaki/research/lebyr/data/undefRule.storable';

use KNP;
my $knp = KNP->new ( -Option => '-tab -bnst' );
my $detector = UnknownWordDetector->new ($ruleFile, undef, undef, { enableNgram => 0 });

while (<STDIN>) {
    chomp;
    my $sentence = "$_\n";
    my $result = $knp->parse ($sentence);
    next unless (defined ($result));

    if ($detector->filterResult ($result)) {
	# print STDERR ("skip $sentence"); # なぜかセグフォする
	next;
    }
    print ($sentence);
}

1;
