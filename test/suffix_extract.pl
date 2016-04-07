#!/bin/env perl
#
# SuffixExtractor のテスト
#
use strict;
use utf8;
use lib "/home/murawaki/research/lebyr/lib";

use Encode;
use Getopt::Long;
use KNP;

use Sentence;
use SuffixExtractor;

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

my $knp = new KNP ( -Option => "-tab -postprocess" );


# my $input = "自らを律することができるのだろうか。";
# my $input = "それなら明日するよ。";
# my $input = "セットしなおす。";
# my $input = "馬鹿がやる。";
# my $input = "採用がやる。";
# my $input = "真似といって。";
# my $input = "研究気味だ。";
# my $input = "遊び、研究気味だ。";
# my $input = "遊び、貧乏性で";
# my $input = "あばいてるぜ。";
# my $input = "メモるぜ。";
# my $input = "メモる勘定のだ。";
# my $input = "モメるぜ。";
# my $input = "あれるぜ。";
# my $input = "天気な。";
# my $input = "メモする。";
# my $input = "メモするやれよ。";
# my $input = "京都する。";
# my $input = "天気する。";
# my $input = "待ちぼうけしている。";
# my $input = "病気なことをしよう。";
# my $input = "微妙なことになった。";
# my $input = "なった微妙なこと。";
# my $input = "通版する前に。";
# my $input = "水がきれい等の利点があった。";
# my $input = "それはうざすぎる。";
# my $input = "ヵゎぃくて";
# my $input = "ジャスラック・登録済み。";
my $input = "感覚できるよ。";

# my ($mrphS, $startPoint, $opOpt) = SuffixExtractor->getTargetMrph ($result->bnst(0));
# Dumpvalue->new->dumpValue ($opOpt);
# print ("\n");
# my $struct = SuffixExtractor->extractSuffix ($result->mrph(0), 0, $result->bnst(0), undef, $opOpt);
# Dumpvalue->new->dumpValue ($struct);

# my $input = <<__EOS__;
# # S-ID:1 KNP:3.0-20090617 DATE:2010/02/16 SCORE:-19.86832
# * 1D <文頭><体言><係:未格><隣係絶対><用言一部><裸名詞><区切:0-0><RID:1464><格要素><連用要素><正規化代表表記:試聴/試聴><主辞代表表記:試聴/試聴>
# + 1D <文頭><体言><係:未格><隣係絶対><用言一部><裸名詞><区切:0-0><RID:1464><格要素><連用要素><名詞項候補><先行詞候補><正規化代表表記:試聴/試聴><解析格:ガ>
# 試聴 試聴 試聴 名詞 6 普通名詞 1 * 0 * 0 "自動獲得 普サナ識別 疑似代表表記 代表表記:試聴/試聴" <自動獲得><普サナ識別><疑似代表表記><代表表記:試聴/試聴><正規化代表表記:試聴/試聴><文頭><漢字><かな漢字><名詞相当語><自立><内容語><タグ単位始><文節始><文節主辞>
# * -1D <BGH:する/する><文末><スルナル><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:708><提題受:30><主節><正規化代表表記:する/する><主辞代表表記:する/する>
# + -1D <BGH:する/する><文末><スルナル><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:708><提題受:30><主節><正規化代表表記:する/する><用言代表表記:する/する><格要素-ガ:試聴><格要素-外の関係:NIL><動態述語><時制-未来><主題格:一人称優位><格関係0:ガ:試聴><格解析結果:する/する:動1572:ガ/N/試聴/0/0/1;外の関係/U/-/-/-/->
# する する する 動詞 2 * 0 サ変動詞 16 基本形 2 "代表表記:する/する 付属動詞候補（基本） 自他動詞:自:成る/なる" <代表表記:する/する><付属動詞候補（基本）><自他動詞:自:成る/なる><正規化代表表記:する/する><文末><表現文末><とタ系連用テ形複合辞><かな漢字><ひらがな><活用語><自立><内容語><タグ単位始><文節始><文節主辞>
# EOS
# __EOS__

my $se = new SuffixExtractor ({ excludeDoukei => 1 });

# use KNP::Result;
# my $result = KNP::Result->new ($input);
# my $mrph = $result->mrph (0);
# my $bnstN = $result->bnst (1);
# my $mrphO = &MorphemeUtilities::getOriginalMrph ($mrph);
# my $struct = $se->extractSuffix ($mrphO, -1, $bnstN, undef, {});
# use Dumpvalue;
# Dumpvalue->new->dumpValue ($struct);
# exit;

use Juman;
my $juman = Juman->new ( -Rcfile => '/home/murawaki/.jumanrc.autodic' );
my $jumanResult = $juman->analysis ($input);
my $result = $knp->parse ($jumanResult);
print $result->spec (), "\n";

if ($se->isNoisySentence ($result)) {
    print ("this is a noise.\n");
}

$se->onSentenceAvailable (Sentence->new ({ 'knp' => $result }));

# 未定義語のテスト
# my $input = "京都のアーマＨＣＭにもあった。";
my $input = "京都する。";
my $result = $knp->parse ($input);
for my $bnst ($result->bnst) {
    my ($mrphS, $startPoint, $opOpt) = $se->getTargetMrph ($bnst, { all => 1 });

    next unless ($mrphS);
    printf ("%s\t%d\n", $mrphS->midasi, $startPoint);
}

1;
