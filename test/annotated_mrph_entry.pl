#!/bin/env perl
#
# AnnotatedMorphemeEntry のテスト
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;
use KNP;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

use JumanDictionary::MorphemeEntry::Annotated;

my $data = <<'__EOF__';
; stem: 痒
; count: 80046
; countStart: 12
; countMerged: 5505
(形容詞 ((読み 痒い)(見出し語 痒い)(活用型 イ形容詞イ段)(意味情報 "自動獲得")))
; stem: 謁
; count: 241
; countStart: 4
; countMerged: 0
(動詞 ((読み 謁す)(見出し語 謁す)(活用型 子音動詞サ行)(意味情報 "自動獲得")))
__EOF__
my $list = JumanDictionary::MorphemeEntry::Annotated->readAnnotatedDictionaryData ($data);

use Dumpvalue;
Dumpvalue->new->dumpValue ($list);

print $list->[0]->getAnnotation ('count'), "\n";

$list->[0]->setAnnotation ('abc', ['京都', 1, 2]);

print $list->[0]->serialize, "\n";

1;
