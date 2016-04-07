#!/bin/env perl
#
# 検出の precision を調べる
# 入力: KNPの解析結果
# 出力: 検出器によるタグ付け結果
#
# 最終的な precision は人手で付ける
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw/retrieve/;
use Dumpvalue;

use KNP::Result;
use Sentence;
use UnknownWordDetector;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my %opt = ( debug => 0, smoothing => 0, 'eval' => 1 );
GetOptions(\%opt, 'debug!', 'smoothing!', 'ngram!', 'eval!', 'all', 'random=i');

my $ruleFile = '/home/murawaki/public_html/egnee/data/undefRule.storable';
my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $suffixListDir = "/home/murawaki/research/lebyr/data";
my $repnameListFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameNgramFile = "/home/murawaki/research/lebyr/data/repnameNgram.storable";

my $total = 0;
my $katakana = 0;

my $detector;

# 注意: precision の測定では detectionSkip をやらない
if ($opt{ngram}) {
    my $repnameList = retrieve($repnameListFile) or die;
    my $repnameNgram = retrieve($repnameNgramFile) or die;
    $detector = UnknownWordDetector->new($ruleFile, $repnameList, $repnameNgram, { enableNgram => 1, debug => $opt{debug}, smoothing => $opt{smoothing}, debugSmoothing => $opt{smoothing}});
} else {
    $detector = UnknownWordDetector->new($ruleFile, undef, undef, { enableNgram => 0, debug => $opt{debug} });
}
$detector->setCallback(\&processExample);


my $detectedList = [];

my $buffer = '';
while (<STDIN>) {
    chomp;
    $buffer .= "$_\n";

    if (index ($_, 'EOS') == 0) {
	my $result = KNP::Result->new($buffer);
	$detector->onSentenceAvailable(Sentence->new({ 'raw' => $buffer, 'knp' => $result }));
	$buffer = '';
    }
}

&printHeader;

# detectedList
printf("$total examples detected\n");
printf("$katakana: katakana\n");
printf("%d: the rest\n", scalar(@$detectedList));

# そのなかから N 文を選択
my $seq = [];
if ($opt{random}) {
    $seq = &getRandSequence(scalar(@$detectedList), $opt{random});
}

&printDetectedList($detectedList, $seq);

&printFooter;


# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($knpResult, $exampleCand) = @_;

    my $feature = $exampleCand->{feature};
    my $output = '';
    my @mrphList = $knpResult->mrph;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $midasi = ($mrphList[$i])->midasi;

	if ($i == $exampleCand->{pos}) {
	    $midasi = '<D>' . $midasi . '</D>';
	}
	$output .= $midasi;
    }
    $output .= "\n";

    $total++;

    my $pivot = $exampleCand->{mrph}->midasi;
    if ($pivot =~ /^(\p{Katakana}|ー)+$/) {
	$katakana++;
	print ("$feature\t$output") if ($opt{all});
    } else {
	my $mrphP = $exampleCand->{mrphP};
	my $mrph = $exampleCand->{mrph};
	my $mrphN = $exampleCand->{mrphN};

	$output .= sprintf("feature: %s\n", $exampleCand->{feature});
	$output .= "#" . $mrphP->spec if (defined($mrphP));
	$output .= "#!" . $mrph->spec;
	$output .=  "#" . $mrphN->spec if (defined($mrphN));
	$output .= "\n";

	push(@$detectedList, [$feature, $output]);
    }
}

sub printDetectedList {
    my ($detectedList, $seq) = @_;

    my $cur = shift(@$seq);
    for (my $i = 0; $i < scalar(@$detectedList); $i++) {
	my ($feature, $output) = @{$detectedList->[$i]};
	print("<div>\n");
	print("<pre>$feature\t$output</pre>\n");

	if (defined($cur) && $cur == $i) {
	    if ($opt{'eval'}) {
		print <<__EOF__;
C: <input type="radio" name="sec$i" value="1"><br/>
E: <input type="radio" name="sec$i" value="0"><br/>
__EOF__
            }
	    $cur = shift(@$seq);
	}
	print ("</div>\n");
    }
}

# 0 ... $length - 1 の列からランダムに $num 個とる
sub getRandSequence {
    my ($length, $num) = @_;

    my $seq = {};
    for (my $i = 0; $i < $num; $i++) {
	while (1) {
	    my $rand = int(rand($length));
	    unless (defined($seq->{$rand})) {
		$seq->{$rand} = 1;
		last;
	    }
	}
    }
    my @seq2 = sort { $a <=> $b } (keys(%$seq));
    return \@seq2;
}

sub printHeader {
    print <<__EOF__;
<html>
<head>
<title>evaluation of precision</title>
</head>
<body>
__EOF__
    if ($opt{'eval'}) {
	print <<__EOF__;
<form method="POST" action="/~murawaki/cgi-bin/precisionEval.cgi">
<input type="input" name="pageID" value="">
__EOF__
    }
}

sub printFooter {
    if ($opt{'eval'}) {
	print <<__EOF__;
<input type="submit" value="Submit">
</form>
__EOF__
    }
    print <<__EOF__;
</body>
</html>
__EOF__
}

1;
