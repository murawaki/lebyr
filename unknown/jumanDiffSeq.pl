#!/bin/env perl
#
# 獲得した語彙を使って解析の差分を見る
#

use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Digest::MD5 qw/md5_base64/;
use Juman;
use KNP;
use KNP::Result;

use Egnee::GlobalServices;
use Egnee::DocumentPoolFactory;
use Egnee::Util qw/dynamic_use/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt,
	   Egnee::DocumentPoolFactory::optionList,
	   'jumanrc=s', 'output=s', 'debug', 'verbose');

# .jumanrc
die unless ( -f $opt->{jumanrc} );

my $overlibPath = "http://reed.kuee.kyoto-u.ac.jp/~murawaki/overlib.js";

if (defined($opt->{spec})) {
    # this must be called before mkdir
    # $opt->{dicdir} will not be overridden if provided by the command-line
    Egnee::DocumentPoolFactory::processSpec($opt);

    # 取得済みのキャッシュを使う
    delete($opt->{tsubakiOption}->{cacheData});
    delete($opt->{tsubakiOption}->{saveData});
    $opt->{tsubakiOption}->{useCache} = 1;
}

my $ofile;
if ($opt->{output}) {
    open($ofile, ">:utf8", $opt->{output}) or die;
} else {
    # default
    $ofile= \*STDOUT;
}


my $juman = Juman->new;
my $juman2 = Juman->new({ rcfile => $opt->{jumanrc} });

my $documentCount = 0;
my $sentenceCount = 0;
my $orgMrphCount = 0;
my $expMrphCount = 0;
my $correctMrphCount = 0;

my $sentenceDiffCount = 0;
my $totalOrg = 0;
my $totalExp = 0;

&printHeader($ofile, $opt->{querySpec});

my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
if ($opt->{kyotocorpus}) {
    # KyotoCorpus calls KNP
    dynamic_use('AnalyzerRegistry');
    dynamic_use('Analyzer::KNP');
    my $analyzerRegistry = AnalyzerRegistry->new;
    $analyzerRegistry->add(Analyzer::KNP->new('knp', {
	knpOption => '-tab -dpnd -timeout 600',
	debug => $opt->{debug}
    }), ['juman']); # Analyzer::Juman を使うことを保証するために raw を付けない
    Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);
}

while ((my $document = $documentPool->get)) {
    my $sentenceList = $document->getAnalysis('sentence');
    next unless (defined($sentenceList));

    my %udb;
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	my $rawstring = $sentence->get('raw');
	# 同じ文は解析しない
	my $digest = md5_base64(encode_utf8($rawstring));
	next if (defined($udb{$digest}));
	$udb{$digest}++;

	my $resultOrg = $juman->analysis($rawstring);
	my $resultExp = $juman2->analysis($rawstring);

	my @mrphListOrg = $resultOrg->mrph;
	my @mrphListExp = $resultExp->mrph;
	$totalOrg += scalar(@mrphListOrg);
	$totalExp += scalar(@mrphListExp);
	$sentenceCount++;

	my $diff = &checkDiff(\@mrphListOrg, \@mrphListExp);

	if (scalar(@$diff) > 0) {
	    $sentenceDiffCount++;
	    &printSentence($ofile, $sentence, \@mrphListOrg, \@mrphListExp, $diff);
	}
    }
}

# statistics
printf $ofile ("<pre>\n");
printf $ofile ("total org: %d\n", $totalOrg);
printf $ofile ("total exp: %d\n", $totalExp);
printf $ofile ("change: %f\%\n", ($totalExp - $totalOrg) * 100 / $totalOrg);
printf $ofile ("number of sentences: %d\n", $sentenceCount);
printf $ofile ("number of sentences changed: %d (%f\%)\n", $sentenceDiffCount, $sentenceDiffCount * 100 / $sentenceCount);
printf $ofile ("</pre>\n");

&printFooter($ofile);
if ($opt->{output}) {
    close($ofile);
}


sub checkDiff {
    my ($mrphListOrg, $mrphListExp) = @_;

    my $i = 0; my $j = 0;
    my ($posOrg, $posExp) = (0, 0);

    my $rv = [];
    my $diffArray;

    my $endFlag = 0; # 1 bit 目が org, 2 bit 目が exp
    while (1) {
	my $mrphOrg;
	my $mrphExp;

	# my $incrementFlag = 0;

	if ($posOrg == $posExp) {
	    if (defined ($diffArray)) {
		$diffArray->[0]->[1] = $i - 1;
		$diffArray->[1]->[1] = $j - 1;
		push(@$rv, $diffArray);
		undef($diffArray);
	    }

	    unless ($endFlag & 1) {
		$mrphOrg = $mrphListOrg->[$i++];
		if (defined($mrphOrg)) {
		    $posOrg += length($mrphOrg->midasi);
		    # $incrementFlag++;
		} else {
		    $endFlag += 1;
		}
	    }
	    unless ($endFlag & 2) {
		$mrphExp = $mrphListExp->[$j++];
		if (defined($mrphExp)) {
		    $posExp += length($mrphExp->midasi);
		    # $incrementFlag++;
		} else {
		    $endFlag += 2;
		}
	    }	
	    if ($posOrg != $posExp) {
		# $rv = 1;
		$diffArray = [];
		$diffArray->[0]->[0] = $i - 1;
		$diffArray->[1]->[0] = $j - 1;
	    } else {
		# $correctMrphCount++ if ($incrementFlag >= 2);
	    }
	} else {
	    if ($posOrg > $posExp) {
		$mrphExp = $mrphListExp->[$j++];
		if (defined($mrphExp)) {
		    $posExp += length($mrphExp->midasi);
		} else {
		    $endFlag += 2;
		}
		# printf("> %s", $mrphExp->spec) if ($opt->{verbose});
	    } else {
		$mrphOrg = $mrphListOrg->[$i++];
		if (defined($mrphOrg)) {
		    $posOrg += length($mrphOrg->midasi);
		} else {
		    $endFlag += 1;
		}
		# printf("< %s", $mrphOrg->spec) if ($opt->{verbose});
	    }
	}

	last if ($endFlag >= 3);
    }
    if (defined($diffArray)) {
	$diffArray->[0]->[0] = (!($endFlag & 1))? $i : $i - 1;
	$diffArray->[1]->[0] = (!($endFlag & 2))? $j : $j - 1;
	push(@$rv, $diffArray);
    }
    return $rv;
}

sub printSentence {
    my ($ofile, $sentence, $mrphListOrg, $mrphListExp, $diff) = @_;

    my $outputSentence = '';
    my $pos = 0;
    foreach my $tmp (@$diff) {
 	my ($is, $ie) = @{$tmp->[0]};
 	my ($js, $je) = @{$tmp->[1]};

	for (; $pos < $is; $pos++) {
	    $outputSentence .= $mrphListOrg->[$pos]->midasi;
	}


	my $diffShort = '';
	my $diffBuffer = '';
	my $diffString = '';
 	for (; $pos <= $ie; $pos++) {
 	    $diffBuffer .= '< ' . $mrphListOrg->[$pos]->spec;
	    $diffShort .= $mrphListOrg->[$pos]->midasi . ' | ';
 	}
	$diffShort = substr($diffShort, 0, length($diffShort) - 3) . "\n";
	$diffString .= '|';
 	for (my $j = $js; $j <= $je; $j++) {
 	    $diffBuffer .= '> ' . $mrphListExp->[$j]->spec;
	    $diffString .= $mrphListExp->[$j]->midasi . '|';
	    $diffShort .= $mrphListExp->[$j]->midasi . ' | ';
 	}
	$diffShort = substr($diffShort, 0, length($diffShort) - 3) . "\n\n";
	$diffBuffer = $diffShort . $diffBuffer;

	# $diffBuffer =~ s/\"/\\\"/g;
	$diffBuffer =~ s/\"/\&quot/g;
	$diffBuffer =~ s/\</\&lt\;/g;
	$diffBuffer =~ s/\>/\&gt\;/g;
	$diffBuffer =~ s/\n/\&lt\;br\/\&gt\;\\n/mg;
	$outputSentence .= sprintf("<a href=\"javascript:void(0);\" onmouseover=\"return overlib(\'%s\', STICKY, CAPTION, \'diff\', CENTER, WIDTH, 700);\" onmouseout=\"return nd();\">%s</a>", $diffBuffer, $diffString);
    }
    for (; $pos < scalar(@$mrphListOrg); $pos++) {
	$outputSentence .= $mrphListOrg->[$pos]->midasi;
    }

    print $ofile <<__EOF__;
<div>
$outputSentence
</div>
__EOF__
    
}

sub printHeader {
    my ($ofile, $querySpec) = @_;

    use Data::Dumper;
    my $d = Data::Dumper->new([$querySpec]);
    $d->Terse(1);  # 無理矢理1行にする
    $d->Indent(0);
    my $spec = $d->Dump;
    $spec =~ s/\\x\{([0-9a-f]*)\}/chr (hex ("0x" . $1))/eg;

    print $ofile <<__EOF__;
<html>
<script type="text/javascript" src="$overlibPath"><!-- overLIB (c) Erik Bosrup --></script>
<body>
<pre>spec:
$spec
</pre>
<div id="overDiv" style="position:absolute; visibility:hidden; z-index:1000;"></div>
__EOF__
}

sub printFooter {
    my ($ofile) = @_;

    print $ofile <<__EOF__;
</body>
</html>
__EOF__
}
