#!/bin/env perl
#
# 簡単なルールによりタグ付けの候補を抽出
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw/retrieve/;

use KNP::Result;
use Sentence;
use UnknownWordDetector;

use Dumpvalue;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $corpusBigramFile = '/home/murawaki/research/lebyr/data/corpusBigram.storable';
my $ruleFile = '/home/murawaki/research/unknown/eval/detect/undef2.storable';
my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $suffixListDir = "/home/murawaki/research/lebyr/data";
my $repnameListFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameNgramFile = "/home/murawaki/research/lebyr/data/repnameNgram.storable";

my $data = retrieve($corpusBigramFile);

my $detector = UnknownWordDetector->new($ruleFile, undef, undef, { enableNgram => 0, debug => 0 });
$detector->setCallback(\&processExample);

my $buffer = '';
while (<STDIN>) {
    chomp;
    $buffer .= "$_\n";

    if (index ($_, 'EOS') == 0) {
	my $result = KNP::Result->new($buffer);
	$detector->onSentenceAvailable(Sentence->new({ 'knp' => $result }));
	$buffer = '';
    }
}


# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($knpResult, $exampleCand) = @_;

    # 既知の問題
    # 未定義語など + 短い形態素のパターン
    # タグ付け rule 検出では検出されるが
    # 本番ルールでは前者が検出される結果、後者が skip される


#     if (rand () > 0.1) {
# 	print STDERR ("skip\n");
# 	return;
#     }

    my $mrphP = $exampleCand->{mrphP};
    my $mrph = $exampleCand->{mrph};
    my $mrphN = $exampleCand->{mrphN};
    my $key = $mrphP->genkei . ':' . $mrph->genkei;
    if (defined($data->{$key})) {
	# printf STDERR ("skip corpus bigram: $key\n");
	return;
    }

    my @mrphList = $knpResult->mrph;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	print "<R>" if ($i == $exampleCand->{pos});
	print $mrph->midasi;
	print "</R>" if ($i == $exampleCand->{pos});
    }
    print ("\n");

    print "#" . $mrphP->spec if (defined($mrphP));
    print "#!" . $mrph->spec;
    print "#" . $mrphN->spec if (defined($mrphN));
    print "\n";
}

1;
