#!/bin/env perl
#
# 検出までを試してみる
# UnknownWordDetector の実験が中心
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw/retrieve/;

use Sentence;
use SuffixList;
use UnknownWordDetector;
use CandidateEnumerator;

use Dumpvalue;


binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'stdin', 'rule=s');

my $ruleFile = '/home/murawaki/research/lebyr/data/undefRule.storable';
my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $suffixListDir = "/home/murawaki/research/lebyr/data";
my $repnameListFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameNgramFile = "/home/murawaki/research/lebyr/data/repnameNgram.storable";

if ($opt->{rule}) {
    $ruleFile = $opt->{rule};
}

my $detector;

&init;

# my $input = "使用料をよこせ」って言って来てかなり頭に来たけど事を荒立てるのもアレだから素直に支払った。";
# my $input = "だからそうして荒立てるのもアレだから素直に支払った。";
# my $input = "明日するアレだから素直に支払った。";
# my $input = "聞いたところによるとエンフバヤルと首相が考えたところだ。";
# my $input = "聞いたところによるとエンフバヤル首相、考えたところだ。";
# my $input = "「らき☆すたを見た。";
# my $input = "それをゲレセンジェと呼ぶのだよ。";
# my $input = "それがゲレセンジェを呼ぶのだよ。";
# my $input = "京都府京都市右京区太秦西蜂岡町６";

# my $input = "あの「はづ×ぽぷ」のシチュはオカズになり得ますか？";
# my $input = "続けるとどうなるか";
# my $input = "行なう「ＷＥＢあきんど養成ジム」";
# my $input = "今日からググってみた。";
# my $input = "「「「みちのくに行った。";
# my $input = "「「「きりたんぽを食べた。";
# my $input = "「「「僕は天才になるのだ。";
# my $input = "「「「おばかさんだ。";
# my $input = "「「「おりこうさんだ。";
# my $input = "ググらずに答えるのが、";
# my $input = "ググるための、";
# my $input = "ちら見したところ";
# my $input = "自作つくばいに挑戦した。";
# my $input = "つくばいとは？";
# my $input = "紅い薔薇";
# my $input = "総て。";
# my $input = "はやっ。";
# my $input = "「「「手間がかかる";
# my $input = "「「「かけてに";
# my $input = "「「「かけてに";
# my $input = "可愛い乳房がたまらない！！";
# my $input = "、うざいよね。";
# my $input = "「そうね」て言う。";
# my $input = "「ドラえもんが嫌いで著作権を侵害してやるっ」ていう人には作り出せないモノだと思うんだけどね。";
# my $input = "嫌われずに気を付けてくださいねッ。";
# my $input = "◆カンマをつける";
my $input = "「うざい。";
# my $input = "「着こなしがうまい。";
# my $input = "「拓く。";
# my $input = "「未来を拓く。";

use KNP;
my $knp = KNP->new(Option => '-tab -dpnd -postprocess',  -JumanRcfile => '/home/murawaki/.jumanrc.bare' );

if ($opt->{stdin}) {
    print ("loading done\n");

    while (<STDIN>) {
	chomp;
	last unless (length($_) > 0);
	my $result = $knp->parse("$_\n");
	print "begin detection\n";
	$detector->onSentenceAvailable(Sentence->new({ 'knp' => $result }));
	print "end detection\n";
    }
} else {
    my $result = $knp->parse($input);
    $detector->onSentenceAvailable(Sentence->new ({ 'knp' => $result }));
}



# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($example) = @_;

    # Dumpvalue->new->dumpValue ($example->{rearCands});
    Dumpvalue->new->dumpValue($example);
}



##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

# 諸々の初期化
sub init {
    my $suffixList = SuffixList->new($suffixListDir);

    my $enumerator = CandidateEnumerator->new($suffixList, { debug => 1 });
    $enumerator->setCallback(\&processExample);

    my $repnameList = retrieve($repnameListFile) or die;
    my $repnameNgram = retrieve($repnameNgramFile) or die;
    $detector = UnknownWordDetector->new($ruleFile, $repnameList, $repnameNgram, { debug => 1, debugSmoothing => 1 });
    $detector->setEnumerator($enumerator);

    use AnalyzerRegistry;
    use Analyzer::Raw;
    my $analyzerRegistry = AnalyzerRegistry->new;
    Sentence->setAnalyzerRegistry($analyzerRegistry); # 依存関係解消のための初期化
    $analyzerRegistry->add(Analyzer::Raw->new('raw'), ['knp', 'juman']);
}

1;
