#!/bin/env perl
#
# 名詞の分類
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;
use Dumpvalue;
use NounCategorySpec;

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

use Juman;
use KNP;

my $juman = Juman->new;
my $knp = KNP->new;

# my $spec = "なんば なんば なんば 名詞 6 普通名詞 1 * 0 * 0 \"自動獲得 疑似代表表記 代表表記:なんば/なんば\" <自動獲得><疑似代表表記><代表表記:なんば/なんば><正規化代表表記:なんば/なんば><文頭><文末><表現文末><かな漢字><ひらがな><名詞相当語><自立><内容語><タグ単位始><文節始><文節主辞>\n";
# use KNP::Morpheme;
# my $mrph = KNP::Morpheme->new ($spec);
# my $inputList = [$mrph];

my $nouncat = NounCategorySpec->new;
# my $inputList = ["ポケモン"];
my $inputList = ["森川", "かおるさん", "京都", '北海道', '札幌', '豊平', '東京', '中央' , '中央区', 'むかわ', 'アメリカ', '米国', '霞が関', 'チベット', '満州', 'ナイアガラ', 'ニューヨーク', '河北', 'パリ', 'キリマンジャロ', 'サハリン', 'ダラス', '関東', 'アジア', 'キャラ', '愛ちゃん', 'ヒマラヤ', '北米', '地球', 'ザイール', '香港', 'ローマ', '政界', '県', '村', '命'];
foreach my $input (@$inputList) {
    my $jresult = $juman->analysis ($input);
    my $kresult = $knp->parse ($jresult);
    my $mrph = $kresult->mrph (0);
    # my $mrph = $input;

    printf ("%s", $mrph->spec);
    my $idString = $nouncat->getIDFromMrph ($mrph);
    printf ("%s\n", join ('?', map { $nouncat->getClassFromID ($_) } (split (/\?/, $idString))));
}

1;
