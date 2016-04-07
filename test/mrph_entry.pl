#!/bin/env perl
#
# MorphemeEntry のテスト
# see also encode.pl
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


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

# if ('注１' =~ /^.[０-９]+$/) {
if ('注１１' =~ /^.\d+$/) {
    print "ok\n";
}

use JumanDictionary::MorphemeEntry;

# malformed input の検証
my $me = JumanDictionary::MorphemeEntry->new
    ('名詞',  # hinsi
     undef, # bunrui
     {
	 '読み' => 'ありえない',
	 '見出し語' => { 'ｱﾘｴﾅｲ' => 1 },
	 '意味情報' => {
	     '自動獲得' => JumanDictionary::MorphemeEntry->NoValue,
	 }
     });
if (defined ($me)) {
    Dumpvalue->new->dumpValue ($me);
} else {
    print ("bad input\n");
}

# my $text = '(動詞 ((読み あいす)(見出し語 愛す あいす)(活用型 子音動詞サ行)(意味情報 "代表表記:愛す/あいす")))';
# my $text = <<__EOF__;
# (指示詞
#   (名詞形態指示詞
#         ((見出し語 これ) (読み これ))
#         ((見出し語 それ) (読み それ))
#    ))
# __EOF__
# my $text =<<__EOF__;
# (連語 ; かする
#  ((助詞 (接続助詞 ((読み か)(見出し語 か)(意味情報 "連語"))))
#   (動詞 ((読み する)(見出し語 する)(活用型 サ変動詞)(活用形 *)(意味情報 "連語")))
# ))
# __EOF__
# my $text =<<__EOF__;
# (連語 ; ことにより
#  ((名詞 (形式名詞 ((見出し語 こと) (読み こと)(意味情報 "連語"))))
#   (助詞 (格助詞 ((見出し語 に) (読み に)(意味情報 "連語"))))
#   (動詞 ((読み よる)(見出し語 よる)(活用型 子音動詞ラ行)(活用形 基本連用形)(意味情報 "連語")))
# ) 0.3 )
# __EOF__
my $text =<<__EOF__;
(連語 ; めぐみおおき
 ((名詞 (普通名詞 ((読み めぐみ)(見出し語 恵み めぐみ)(意味情報 "連語"))))
  (形容詞 ((読み おおい)(見出し語 多い おおい)(活用型 イ形容詞アウオ段)(活用形 *)(意味情報 "連語")))
))
__EOF__
# my $text =<<__EOF__;
# (連語 ; 意気上がる
#  ((名詞 (普通名詞 ((読み いき)(見出し語 意気)(意味情報 "連語"))))
#   (動詞 ((読み あがる)(見出し語 あがる 上がる)(活用型 子音動詞ラ行)(活用形 *)(意味情報 "連語")))
# ))
# __EOF__
# my $text =<<__EOF__;
# (連語 ; とはいえ
#  ((助詞 (格助詞 ((読み と)(見出し語 と)(意味情報 "連語"))))
#   (助詞 (副助詞 ((読み は)(見出し語 は)(意味情報 "連語"))))
#   (動詞 ((読み いう)(見出し語 いう)(活用型 子音動詞ワ行)(活用形 命令形)(意味情報 "連語")))
# ) 0.9 )
# __EOF__


use SExpression;
my $ds = SExpression->new ({ use_symbol_class => 1, fold_lists => 0 });
my ($se, $buf) = $ds->read ($text);
my $mspec = JumanDictionary::MorphemeEntry->createFromSExpression ($se);
Dumpvalue->new->dumpValue ($mspec);

print $mspec->[0]->serialize, "\n";

use JumanDictionary::MorphemeEntry::Annotated;
Dumpvalue->new->dumpValue (&JumanDictionary::MorphemeEntry::Annotated::makeAnnotatedMorphemeEntryFromStruct ({ posS => '普通名詞', stem => 'グーグル' }));

# my ($se, $buf) = $ds->read ($mspec->[0]->serialize);
# my $mspec = JumanDictionary::MorphemeEntry->createFromSExpression ($se);
# Dumpvalue->new->dumpValue ($mspec);

## 全角空白
# use JumanDictionary;
# # my $dic = JumanDictionary->new ("/home/murawaki/download/juman/dic/", { doLoad => 0 });
# my $dic = {};
# bless ($dic, "JumanDictionary");
# use SExpression;
# $dic->{ds} = SExpression->new ({ use_symbol_class => 1, fold_lists => 0 });
# $dic->loadEachDictionary ("/home/murawaki/download/juman/dic/Special.dic");
# Dumpvalue->new->dumpValue ($dic->{mrphList});

print ("\n\n");
use DictionaryManager;
my $dm = DictionaryManager->new;

$me = JumanDictionary::MorphemeEntry->new
    ('形容詞',  # hinsi
     undef, # bunrui
     {
	 '活用型' => 'ナ形容詞',
	 '読み' => 'エッチだ',
	 '見出し語' => { 'えっちだ' => 1 },
	 '意味情報' => {
	     '自動獲得' => JumanDictionary::MorphemeEntry->NoValue,
	 }
     });
$dm->updateFusana ($me, 0);
Dumpvalue->new->dumpValue ($me);

$me = JumanDictionary::MorphemeEntry->new
    ('名詞',  # hinsi
     '普通名詞', # bunrui
     {
	 '読み' => 'エッチ',
	 '見出し語' => { 'えっち' => 1 },
	 '意味情報' => {
	     '自動獲得' => JumanDictionary::MorphemeEntry->NoValue,
	 }
     });
my $dm = DictionaryManager->new;
$dm->updateFusana ($me, 2);
Dumpvalue->new->dumpValue ($me);

1;
