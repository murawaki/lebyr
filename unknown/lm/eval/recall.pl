#!/bin/env perl
#
# 検出の recall を調べる
#
# 人手でタグづけした過分割未知語のみを対象とした疑似 recall
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw/retrieve/;
use Dumpvalue;

use Sentence;
use UnknownWordDetector;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { debug => 0, smoothing => 0 };
GetOptions($opt, 'debug!', 'smoothing!', 'ngram!', 'jmecab');

# my $ruleFile = '/home/murawaki/research/unknown/lm/eval/undefRule.storable';
my $ruleFile = '/home/murawaki/public_html/egnee/data/undefRule.storable';
my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $suffixListDir = "/home/murawaki/research/lebyr/data";
my $repnameListFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameNgramFile = "/home/murawaki/research/lebyr/data/repnameNgram.storable";

my $mecabDicDir = "/home/murawaki/local/lib/mecab/dic/jumandic";

my $detector;

if ($opt->{ngram}) {
    my $repnameList = retrieve($repnameListFile) or die;
    my $repnameNgram = retrieve($repnameNgramFile) or die;
    $detector = UnknownWordDetector->new($ruleFile, $repnameList, $repnameNgram, { enableNgram => 1, debug => $opt->{debug}, smoothing => $opt->{smoothing}, debugSmoothing => $opt->{smoothing}, detectionSkip => 0, filterNoise => 0 });
} else {
    $detector = UnknownWordDetector->new($ruleFile, undef, undef, { enableNgram => 0, debug => $opt->{debug}, detectionSkip => 0, filterNoise => 0 });
}
$detector->setCallback(\&processExample);


# my $input = "明日するアレだから素直に支払った。";

use KNP;
my $knp = KNP->new( -Option => '-tab -dpnd -postprocess' );
my $juman;
if ($opt->{jmecab}) {
    use JMecab;
    $juman = JMecab->new(dicdir => $mecabDicDir);
}

my $score = {};
my $total = {};
my ($sentence, $tagInfo); # global vars
my $detected; # 複数回呼ばれるからこの変数で管理
while (<STDIN>) {
    chomp;
    next if ($_ =~ /^\#/ || length($_) <= 0); # skip comments

    my $input = $_;
    print "$input\n";

    ($sentence, $tagInfo) = &parseTaggedSentence($input);

    $total->{all}++;
    $total->{unknown}++ if (defined($tagInfo->{U}));
    $total->{error}++ if (defined($tagInfo->{E}));
    $total->{out}++ if (defined($tagInfo->{O}));

    $detected = 0;
    next unless (defined($tagInfo->{U})
		 || defined($tagInfo->{E})
		 || defined($tagInfo->{O}));

    my $result;
    if ($opt->{jmecab}) {
	$result = $knp->parse_mlist($juman->analysis($sentence));
    } else {
	$result = $knp->parse($sentence);
    }
    unless ($result) {
	print("!!! parse error\n");
	next;
    }
    $detector->onSentenceAvailable(Sentence->new({ 'raw' => $sentence, 'knp' => $result }));

    unless ($detected) {
	print ("omitted\n");
	$score->{omitted}++;

	if (defined($tagInfo->{U})) {
	    print("false negative: $input\n\n");
	}
    }
}

print("\ttotal\n");
Dumpvalue->new->dumpValue($total);
print("\tresult\n");
Dumpvalue->new->dumpValue($score);

sub parseTaggedSentence {
    my ($tagged) = @_;

    my $sentence = '';
    my $tagInfo = {};
    foreach my $frg (split(/[\<\>]/, $tagged)) {
	if ($frg =~ /^([A-Z])$/) {
	    $tagInfo->{$1}->[0] = length($sentence);
	} elsif ($frg =~ /^\/([A-Z])$/) {
	    $tagInfo->{$1}->[1] = length($sentence);
	} else {
	    $sentence .= $frg;
	}
    }

    my @tagList = keys(%$tagInfo);
    if (scalar(@tagList) == 0) {
	die "no tag defined\n";
    }

    # check
    if (index($sentence, '<') >= 0
	|| index($sentence, '>') >= 0) {
	die "malformed input: $tagged\n";
    }
    foreach my $tag (@tagList) {
	unless ($tag =~ /^[UEOR]$/) {
	    die "undefined tag: $tag <- $tagged\n";
	}
	my @region = @{$tagInfo->{$tag}};
	unless (defined($region[0]) && defined($region[1]) && $region[0] < $region[1]) {
	    die "mismatched tag: $tag <- $tagged\n";
	}
    }

    return ($sentence, $tagInfo);
}


# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($knpResult, $exampleCand) = @_;

    my $region;
    my $pos = 0;
    my @mrphList = $knpResult->mrph;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
	my $l = length($mrph->midasi);
	if ($i == $exampleCand->{pos}) {
	    $region = [$pos, $pos + $l];
	}
	$pos += $l;
    }

    Dumpvalue->new->dumpValue($tagInfo);
    printf("detected: [%d, %d]\n", $region->[0], $region->[1]);

    if (defined($tagInfo->{U})
	&& $tagInfo->{U}->[0] <= $region->[0]
	&& $tagInfo->{U}->[1] >= $region->[0]){
	# 語幹の終りにぎりぎり引っかかればよい
	    # && ($tagInfo->{U}->[1] >= $region->[0])) { 
	    # || $tagInfo->{U}->[1] == $region->[0])) {
	print("unknown\n");

	delete($tagInfo->{U});
	$score->{unknown}++;
    } elsif (defined($tagInfo->{E})
	     && $tagInfo->{E}->[0] <= $region->[0]
	     && $tagInfo->{E}->[1] >= $region->[1]) {
	print("error\n");

	delete($tagInfo->{E});
	$score->{error}++;
    } elsif (defined($tagInfo->{O})
	     && $tagInfo->{O}->[0] <= $region->[0]
	     && $tagInfo->{O}->[1] >= $region->[1]) {
	print("out\n");

	delete($tagInfo->{O});
	$score->{out}++;
    } else {
	print("other\n");
    }

    my $mrphP = $exampleCand->{mrphP};
    my $mrph = $exampleCand->{mrph};
    my $mrphN = $exampleCand->{mrphN};
    printf("feature: %s\n", $exampleCand->{feature});
    print "#" . $mrphP->spec if (defined($mrphP));
    print "#!" . $mrph->spec;
    print "#" . $mrphN->spec if (defined($mrphN));
    print "\n";

    $detected = 1;
}

1;
