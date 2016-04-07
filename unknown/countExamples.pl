#!/bin/env perl
#
# 獲得した語彙を使って解析の差分を見る
#

use strict;
use utf8;

use Encode;
use Getopt::Long;

use Juman;
use DocumentPool::Tsubaki;
use KNP;
use Digest::MD5 qw (md5_base64);
use KNP::Result;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'spec=s', 'jumanrc=s', 'output=s', 'debug', 'verbose');

# .jumanrc
die unless ( -f $opt{jumanrc} );

# デフォルトのクエリ
my $querySpec = { query => '捕鯨問題', results => 500 };
my $tsubakiOption = { workingDirectory => '/avocado2/murawaki/tsubaki_query/whaling500',
		      useCache => 1, debug => 1 };  # 取得済みのキャッシュを使う
		      # cacheData => 1, saveData => 1, debug => 1 };
# クエリをファイルで指定
if (defined ($opt{spec})) {
    my $dictionaryDir;
    if ( -f $opt{spec} ) {
	open (my $file, "<:utf8", $opt{spec});
	my $data = join('', <$file>);
	eval ($data);
	close ($file);
	die if ($@);
    } else {
	die "file not found: $opt{spec}\n";
    }
    if ($dictionaryDir) {
	$opt{jumanrc} = "$dictionaryDir/.jumanrc";
    }

    # 取得済みのキャッシュを使う
    delete ($tsubakiOption->{cacheData});
    delete ($tsubakiOption->{saveData});
    $tsubakiOption->{useCache} = 1;
}

my $ofile;
if ($opt{output}) {
    open ($ofile, ">:utf8", $opt{output}) or die;
} else {
    # default
    $ofile= \*STDOUT;
}


# my $juman = new Juman ();
my $juman2 = new Juman ({ rcfile => $opt{jumanrc} });

# my $documentCount = 0;
my $sentenceCount = 0;
# my $orgMrphCount = 0;
# my $expMrphCount = 0;
# my $correctMrphCount = 0;
my $acCount = 0;

# my $sentenceCount = 0;
# my $sentenceDiffCount = 0;
# my $totalOrg = 0;
# my $totalExp = 0;

my $document;
my $tsubaki = new DocumentPool::Tsubaki ($querySpec, $tsubakiOption);
while (($document = $tsubaki->get ())) {
    my $idList = $document->getAnalysis ('raw');

    next unless (defined ($idList));

    my %udb;

    my $sentence;
    while (($sentence = $idList->next ())) {
	# 同じ文は解析しない
	my $digest = md5_base64 (encode_utf8 ($sentence));
	next if (defined ($udb{$digest}));
	$udb{$digest}++;

	$sentenceCount++;

	my $resultExp = $juman2->analysis ($sentence);
	foreach my $mrph ($resultExp->mrph) {
	    if ($mrph->imis =~ /自動獲得/) {
		$acCount++;

		unless ($acCount % 50) {
		    printf ("%d\t%d\n", $sentenceCount, $acCount);
		}
	    }
	}
    }
    printf ("%d\t%d\n", $sentenceCount, $acCount);
}
printf ("%d\t%d\n", $sentenceCount, $acCount);
