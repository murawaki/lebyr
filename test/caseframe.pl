#!/usr/bin/env perl

use strict;
use utf8;
use Getopt::Long;

use CorpusTools;
use Examples;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt = ( 'rn' => 1, 'no_eneralize' => 1, compound => 2, probcase => 0 );
GetOptions (\%opt, 'debug', 'inputdir=s', 'outputdir=s', 'probcase');

use Encode;
use KNP;

# my $input = "敵がゲーム世界を遊んだ。";
# my $input = "敵がゲーム世界を遊んだら、明日は晴れになる。";
# my $input = "明日の朝悪の敵と遊ぶだろうさ。";
# my $input = "遊んだとき、それをやるのがいいさ。";
# my $input = "晴れきったのだろうよ。";
# my $input = "つかれた子供よ。";
# my $input = "そのとき、敵の敵を倒した。";
# my $input = "どんぶり茶屋は、市場の真ん中にあります。";
# my $input = "活気溢れる店内。";
# my $input = "どんぶり茶屋の外観です。";
# my $input = "コンセプトは「人間力をつけましょう！」";
# my $input = "私のところは、一応、「常にオン」　ハードディスクの電源を切る「なし」　にしています。";
# my $input = "コーディネイトの仕上げやスパイスとして欠かせない名脇役になる事間違い無し！";
# my $input = "表サイトは特に隠してるわけではないんですけど、　おおっぴらには言ってません（＾＾；";
# my $input = "百道浜の仕立て屋【テーラー】ですが…。?ハイ○ットホテルの中の仕立て屋なんていうと、高級で近寄りがたいイメージもお持ちでしょうが、そうでもありません。『ご自身にあったお気に入りを購入すべきではないか』と　初心を忘れず大量生産とは異なる【一着】をお仕立てすることで　使っては捨てるのではない【ＭＯＮＯ】を大切にする気持ちや【環境問題】などに　少しでもお役に立てればと思っております。スーツの持つ歴史や伝統を踏まえつつ時代のトレンドも取り入れておりますし　おためしモデル　○８０００円（税込み３９○００円）からもご用意いたしております。コトスーツの画像はｈｔｔｐ：／／ｂｌｏｇｓ．ｙａｈｏｏ．ｃｏ．ｊｐ／ｂｅｓｐｏｋｅ４２／ｆｏｄｅｒ／１５０３２７９．ｈｔｍｌ　です。";
# my $input = "高級で近寄りがたいイメージ";
# my $input = "と言うのが海外旅行時の定番だが、　タイではこれはあきらめた方がいい。";
# my $input = "と言うのが海外旅行時の定番だが。";
# my $input = "そんなときに「ありがとう」というと、その不幸の連鎖が断ち切れるそうです。";
# my $input = "そんな二人の様子を見つつ、いつかはこんな家に住めたらなあなどと思った私は、住宅展示場のアンケートに、深く考えず、書いてはいけない欄に○をつけて まう。";
# my $input = "書いてはいけない欄に○をつけて まう。";
# my $input = "まささんの豊富な経験と知識がいよいよ集大成化されるのですね。";
# my $input = "写真ちょっとわかりづらいですか？";
# my $input = "送料無料まであと　５，０００円　です。";
# my $input = "ＥＣプランニングでは、にっぽん市のショッピングカートを利用しております。";
# my $input = "妹が一人の４人家族で生まれ育った。";
# my $input = "急に親近感を覚えたのは、私だけではありますまい。";
# my $input = "魚屋ならではの威勢のよさと少し口ベタなところはご愛嬌・・。";
# my $input = "のほほんとトークしていたんですが、Ｂに引きこもっていたイナゴ集団が今日は動いている模様。";
# my $input = "そんなときに「ありがとう」というと、その不幸の連鎖が断ち切れるそうです。";
# my $input = "象は鼻が長そうです。";
# my $input = "象の鼻は長さです。";
# my $input = "長い鼻です。";
# my $input = "画像一覧ページに戻る　ホームページに戻る";
# my $input = "仲店通を歩くと、市場らしい店頭が目に入るはずです。";
# my $input = "国で探す。";
# my $input = "発毛ネット?　その常識、ウソ！ホント！：さると人間、どっちが毛が多い？　［株式会社メディナ］";
# my $input = "発毛ネット?　その常識、ウソ！ホント！：さると人間、どっちが毛が多い？";
# my $input = "どうやらビジネスマンの会議録音用といった需要・用途を想定して企画された機種なようで（勝手にそう思ってるだけ？？　でも、店頭にはそんなイメージの写真（たぶんメーカーのセールスが貼っていったんだろう）もあってそんな訴求の仕方をしてました）、会議録音用途には　ＡＬＣ（Ａｕｔｏ　Ｌｅｖｅｌ　Ｃｏｎｔｒｏｌｅｒ）　による録音レベルオートでもなんら問題は無いのですが、ライブを生ロクするとなるとでんでんダメです。";
# my $input = "ライブを生ロクするとなるとでんでんダメです。";
# my $input = "持ち上げている帯域が低すぎで電車内の騒音に対し効果がない";
# my $input = "★こちらのお品物は送料代引手数料とも無料となります。";
# my $input = "爽やかさと甘さのバランスが心地よいムスクの香り。";
# my $input = "やがて立ち上るウッディとムスクの香りがフェミニンで洗練された女性を演出します。";
# my $input = "（１３歳）　を倒す。";
# my $input = "（１３歳）を倒す。";
my $input = "札幌で乗り換えする。";

# My $input = <<__EOF__;
# # S-ID:188 KNP:3.0-20090927 DATE:2009/11/24 SCORE:-10.94976
# * 1D <SM-主体><SM-動作><SM-人><BGH:使い/つかいv|使う/つかう><文頭><助詞><連体修飾><体言><係:ノ格><区切:0-4><RID:1072><準主題表現><正規化代表表記:使い/つかいv><主辞代表表記:使い/つかいv><候補:1>
# + 1D <SM-主体><SM-動作><SM-人><BGH:使い/つかいv|使う/つかう><文頭><助詞><連体修飾><体言><係:ノ格><区切:0-4><RID:1072><準主題表現><名詞項候補><先行詞候補><係チ:非用言格解析||用言&&文節内:Ｔ解析格-ヲ><正規化代表表記:使い/つかいv><候補:1>
# お お お 接頭辞 13 名詞接頭辞 1 * 0 * 0 "代表表記:御/お" <代表表記:御/お><正規化代表表記:御/お><文頭><かな漢字><ひらがな><接頭><非独立接頭辞><タグ単位始><文節始>
# 使い つかい 使い 名詞 6 普通名詞 1 * 0 * 0 "代表表記:使い/つかいv 代表表記変更:使う/つかう 品詞変更:使い-つかい-使う-2-0-12-8" <代表表記:使い/つかいv><正規化代表表記:使い/つかいv><かな漢字><品詞変更:使い-つかい-使う-2-0-12-8-"代表表記:使う/つかう"><代表表記変更:使う/つかう><名詞相当語><自立><内容語><文節主辞>
# の の の 助詞 9 接続助詞 3 * 0 * 0 NIL <かな漢字><ひらがな><付属>
# * 3D <ハ><助詞><体言><係:未格><提題><区切:3-5><RID:1278><主題表現><格要素><連用要素><正規化代表表記:ブラウザ/ぶらうざ><主辞代表表記:ブラウザ/ぶらうざ><候補:3>
# + 4D <ハ><助詞><体言><係:未格><提題><区切:3-5><RID:1278><主題表現><格要素><連用要素><名詞項候補><先行詞候補><正規化代表表記:ブラウザ/ぶらうざ><候補:4><解析格:ガ>
# ブラウザ ぶらうざ ブラウザ 名詞 6 普通名詞 1 * 0 * 0 "代表表記:ブラウザ/ぶらうざ カテゴリ:抽象物 ドメイン:科学・技術" <代表表記:ブラウザ/ぶらうざ><カテゴリ:抽象物><ドメイン:科学・技術><正規化代表表記:ブラウザ/ぶらうざ><記英数カ><カタカナ><名詞相当語><自立><内容語><タグ単位始><文節始><固有キー><文節主辞>
# は は は 助詞 9 副助詞 2 * 0 * 0 NIL <かな漢字><ひらがな><付属>
# * 3D <BGH:フレーム/ふれーむ><ニ><助詞><体言><係:ニ格><区切:0-0><RID:1180><格要素><連用要素><正規化代表表記:行/ぎょう?行/こう+フレーム/ふれーむ><主辞代表表記:フレーム/ふれーむ><候補:3>
# + 3D <SM-動作><BGH:行/ぎょう|行/こう><文節内><係:文節内><体言><一文字漢字><名詞項候補><先行詞候補><正規化代表表記:行/ぎょう?行/こう>
# 行 ぎょう 行 名詞 6 普通名詞 1 * 0 * 0 "代表表記:行/ぎょう 漢字読み:音 カテゴリ:抽象物" <代表表記:行/ぎょう><漢字読み:音><カテゴリ:抽象物><正規化代表表記:行/ぎょう?行/こう><品曖><ALT-行-こう-行-6-1-0-0-"代表表記:行/こう 漢字読み:音 カテゴリ:抽象物"><品曖-普通名詞><原形曖昧><漢字><かな漢字><名詞相当語><自立><内容語><タグ単位始><文節始>
# 内 ない 内 接尾辞 14 名詞性名詞接尾辞 2 * 0 * 0 "代表表記:内/ない" <代表表記:内/ない><正規化代表表記:内/ない><漢字><かな漢字><名詞相当語><付属><複合←>
# + 4D <BGH:フレーム/ふれーむ><ニ><助詞><体言><係:ニ格><区切:0-0><RID:1180><格要素><連用要素><名詞項候補><先行詞候補><正規化代表表記:フレーム/ふれーむ><候補:4><解析格:ニ>
# フレーム ふれーむ フレーム 名詞 6 普通名詞 1 * 0 * 0 "代表表記:フレーム/ふれーむ カテゴリ:人工物-その他" <代表表記:フレーム/ふれーむ><カテゴリ:人工物-その他><正規化代表表記:フレーム/ふれーむ><記英数カ><カタカナ><名詞相当語><自立><複合←><内容語><タグ単位始><固有キー><文節主辞>
# に に に 助詞 9 格助詞 1 * 0 * 0 NIL <かな漢字><ひらがな><付属>
# * -1D <BGH:対応/たいおう+する/する><文末><サ変><サ変動詞><サ変スル><否定表現><句点><〜ぬ><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:1498><係:文末><提題受:30><主節><格要素><連用要素><敬語:丁寧表現><正規化代表表記:対応/たいおう><主辞代表表記:対応/たいおう>
# + -1D <BGH:対応/たいおう+する/する><文末><サ変動詞><サ変スル><否定表現><句点><〜ぬ><用言:動><レベル:C><区切:5-5><ID:（文末）><RID:1498><係:文末><提題受:30><主節><格要素><連用要素><敬語:丁寧表現><サ変><正規化代表表記:対応/たいおう><用言代表表記:対応/たいおう><格要素-ガ:ブラウザ><格要素-ヲ:NIL><格要素-ニ:フレーム><格要素-デ:NIL><格要素-カラ:NIL><格要素-ヨリ:NIL><格要素-マデ:NIL><格要素-時間:NIL><格要素-ノ:NIL><格要素-修飾:NIL><格要素-外の関係:NIL><格フレーム-ガ-主体><格フレーム-ガ-主体ｏｒ主体準><動態述語><主題格:一人称優位><格関係1:ガ:ブラウザ><格関係3:ニ:フレーム><格解析結果:対応/たいおう:動19:ガ/N/ブラウザ/1/0/188;ヲ/U/-/-/-/-;ニ/C/フレーム/3/0/188;デ/U/-/-/-/-;カラ/U/-/-/-/-;ヨリ/U/-/-/-/-;マデ/U/-/-/-/-;時間/U/-/-/-/-;ノ/U/-/-/-/-;修飾/U/-/-/-/-;外の関係/U/-/-/-/->
# 対応 たいおう 対応 名詞 6 サ変名詞 2 * 0 * 0 "代表表記:対応/たいおう カテゴリ:抽象物" <代表表記:対応/たいおう><カテゴリ:抽象物><正規化代表表記:対応/たいおう><漢字><かな漢字><名詞相当語><サ変><サ変動詞><自立><内容語><タグ単位始><文節始><文節主辞>
# して して する 動詞 2 * 0 サ変動詞 16 タ系連用テ形 14 "代表表記:する/する 付属動詞候補（基本） 自他動詞:自:成る/なる" <代表表記:する/する><付属動詞候補（基本）><自他動詞:自:成る/なる><正規化代表表記:する/する><とタ系連用テ形複合辞><かな漢字><ひらがな><活用語><付属>
# い い いる 接尾辞 14 動詞性接尾辞 7 母音動詞 1 基本連用形 8 "代表表記:いる/いる" <代表表記:いる/いる><正規化代表表記:いる/いる><かな漢字><ひらがな><活用語><付属>
# ませ ませ ます 接尾辞 14 動詞性接尾辞 7 動詞性接尾辞ます型 31 未然形 3 "代表表記:ます/ます" <代表表記:ます/ます><正規化代表表記:ます/ます><かな漢字><ひらがな><活用語><付属>
# ん ん ぬ 助動詞 5 * 0 助動詞ぬ型 27 音便基本形 12 NIL <表現文末><かな漢字><ひらがな><活用語><否定><付属>
# 。 。 。 特殊 1 句点 1 * 0 * 0 NIL <文末><英記号><記号><付属>
# EOS            
# __EOF__

# use KNP::Result;
# my $result = KNP::Result->new ($input) or die;
my $knp = KNP->new ( -Option => ' -tab -check ' );
my $result = $knp->parse ($input);

use IO::Scalar;
my $d = '';
my $sfh = IO::Scalar->new (\$d);

# my $tmpSTDOUT = \*STDOUT;
# *STDOUT = \$sfh;
my $examples = Examples->new ();
$examples->{DATA} = $sfh;
# *STDOUT = \$tmpSTDOUT;
my $corpus = CorpusTools->new (encode ('euc-jp', $result->spec), {'notag' => 1});

my $count = 1;

print $result->spec, "\n";


my $paList = [];
while (my $sid = $corpus->ReadParsedData) {
    for my $i (reverse(0 .. $#{$corpus->{Bunsetsu}})) {
	next unless defined($corpus->{Bunsetsu}[$i]);
	next if $opt{last} && $i != $corpus->{BunsetsuList}[$#{$corpus->{BunsetsuList}}];

	# 文末または括弧終にある用言をチェック
	unless ($examples->CheckSentence($corpus, $i, $opt{no_discard_ambiguity})) {
	    last; # FALSEがかえるとこの文をスキップ
	}

	# 一つの用言から述語項構造を抽出
	my @currentPA = $examples->MakeExamples($corpus, $i, $sid, $opt{rn}, $opt{compound}, $opt{no_generalize}, $opt{no_discard_ambiguity});
	push(@$paList, @currentPA) if @currentPA;
    }

    if ($opt{debug}) {
	print '*' unless $count%1000;
	print " $count\n" unless $count%10000;
    }
    $count++;

    # $corpus->PrintParsedData if $opt{debug};
}

print (decode ('euc-jp', join ("\n", @$paList)), "\n");

print ("here we go!!!\n");

use Sentence;
use CaseFrameExtractor;
my $cfe = CaseFrameExtractor->new ({ useCompoundNoun => $opt{compound}, generalize => !$opt{no_eneralize}, discardAmbiguity => !$opt{no_discard_ambiguity}, useRepname => $opt{rn}, dump => 1, probcase => $opt{probcase} });
# my $sentence = Sentence->new ({ 'knp' => $result });
$cfe->prepare ($result);
my $cfList = $cfe->extract ($result);
$cfe->clean ($result);
# use Dumpvalue;
# Dumpvalue->new->dumpValue ($cfList);

# my $output = '';

# while (<$sfh>) {
#     print (decode ('euc-jp', "data: $_\n"));

#     use bytes;

#     chomp;
#     split;
#     my ($sid) = shift(@_);

#     if ($_[0] =~ /^[\xa3-\xa5\xb0-\xf3][\xa0-\xff]/) { # 英数字, ひらがな, カタカナ, 漢字
# 	s/(<(?:数量|時間)>.*:)[^:]*:([^:]+)/$1$2/ for (@_);

# 	unless ($opt{basic}) {
# 	    print $sid, ' ';
# 	}
#         $output .= join(' ', @_), "\n";
#     }
# }

# print (decode ('euc-jp', $output), "\n");
