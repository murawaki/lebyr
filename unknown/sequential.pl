#!/bin/env perl
#
# 語彙知識獲得のメインプログラム
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Dumpvalue;
use IO::File;

use Egnee;
use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
use Egnee::Logger;
use Egnee::Util qw/dynamic_use/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {
    conf => "/home/murawaki/research/lebyr/prefs",
    tmpdir => "/tmp/lebyr",
    acquisition => 1, doLoad => 0, ngram => 1, safeMode => 0,
    safePosMode => 1,  # pos 獲得を用例が集まるまで延期する
    noDetectHanNgram => 1, # ngarmに漢字が含まれていたら単語の過分割と判定しない
    debug => 0, loglevel => 2, gcCheckThres => 10000, gcLimit => 8000 };

GetOptions($opt,
	   'conf=s',
	   Egnee::DocumentPoolFactory::optionList,
	   'raw=s',     # process a list of raw sentences in the specified file
	   'dicdir=s',  # 作業用の辞書のディレクトリ
       'docdir=s',  # ドキュメントのディレクトリのリスト
	   'acquisition!', # 未知語獲得をやるか
	   'doLoad=i',  # 初期辞書をロードするか
	   'stat=s',    # 実験用に統計を取る場合
	   'debug',
	   'loglevel=i',
	   'ngram!',    # 未知語検出に N-gram を使うか
	   'safeMode',
       'safePosMode',
       'noDetectHanNgram',
	   'gcCheckThres=i',
	   'gcLimit=i',
	   'monitor',
    );

# global vars
my $egnee;
my $countBefore = 0;
my $usedExampleCount = 0;
my ($logger, $simpleMonitor);

&init;


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

if ($opt->{raw}) {
    my $file = IO::File->new($opt->{raw}) or die;
    $file->binmode(':utf8');
    while ((my $line = $file->getline)) {
	chomp($line);
	$egnee->processRawString($line);

	# stat
	&logger if ($opt->{stat} &&
		    ($opt->{loglevel} >= 3 || ($opt->{acquisition} && $opt->{loglevel} >= 2)) );
    }
    $file->close;
} else {
    my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
    while ((my $document = $documentPool->get)) {
	my $documentID = $document->getAnnotation('documentID');
	printf("#document\t%s\n", $documentID) if ($documentID);

	$egnee->processDocument($document);

	# stat
	&logger if ($opt->{stat} &&
		    ($opt->{loglevel} >= 3 || ($opt->{acquisition} && $opt->{loglevel} >= 2)) );
    }
}
&save;

1;

sub onDictionaryChanged {
    my ($struct) = @_;

    my $accumulator = $egnee->{accumulator};
    if ($struct->{type} eq 'beforeChange') {
	$countBefore = $accumulator->getTotal;
    } elsif ($struct->{type} eq 'append') {
	# stat
	$usedExampleCount += $countBefore - $accumulator->getTotal;
	$countBefore = $accumulator->getTotal;
	&logger if ($opt->{stat});
    } elsif ($struct->{type} eq 'decompose') {
	# stat
	$usedExampleCount += $countBefore - $accumulator->getTotal;
	$countBefore = $accumulator->getTotal;
	&logger if ($opt->{stat});
    } else {
	warn("unsupported dictionary event type\n");
    }
}



##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

# 諸々の初期化
sub init {
    if (defined($opt->{spec})) {
	# this must be called before mkdir
	# $opt->{dicdir} will not be overridden if provided by the command-line
	Egnee::DocumentPoolFactory::processSpec($opt);
    }
    die unless ($opt->{dicdir});
    `mkdir -p $opt->{dicdir}`;
    die unless ( -d $opt->{dicdir} );

    Egnee::GlobalConf::loadFile($opt->{conf});
    Egnee::GlobalConf::set('main.debug', $opt->{debug});
    Egnee::GlobalConf::set('working-dictionary.do-load', $opt->{doLoad});
    Egnee::GlobalConf::set('working-dictionary.path', $opt->{dicdir});

    # standard format
    Egnee::GlobalConf::set('standardformat-document.use-knp-annotation', 0);
    Egnee::Logger::setLogger($opt->{debug}, 'Document::StandardFormat');

    # acquisition
    Egnee::GlobalConf::set('main.acquisition', $opt->{acquisition});
    Egnee::GlobalConf::set('unknown-word-detector.use-ngram', $opt->{ngram});

    # safe mode
    Egnee::GlobalConf::set('main.safe-mode', $opt->{safeMode});
    if ($opt->{safeMode}) {
	# server mode ではこれをやらないので
	Egnee::GlobalConf::set('stem-finder.safe-mode', 1);
    }

    $egnee = Egnee->new({ debug => $opt->{debug}, loglevel => $opt->{loglevel} , safePosMode => $opt->{safePosMode}, noDetectHanNgram => $opt->{noDetectHanNgram}});
    $egnee->setDictionaryCallback(\&onDictionaryChanged);

    if ($opt->{monitor}) {
	my $monitorOpt = { suffix => 1, reset => $opt->{doLoad}, debug => $opt->{debug} };
	$egnee->addUsageMonitor($monitorOpt);
    }

    if ($opt->{stat}) {
	$logger = IO::File->new($opt->{stat}, 'w') or die;
	$logger->binmode(':utf8');
	dynamic_use('SimpleMonitor');
	$simpleMonitor = SimpleMonitor->new({ debug => $opt->{debug} });
	$egnee->{sentenceBasedAnalysisObserverRegistry}->add('simple monitor', $simpleMonitor,
							     { 'getUnique' => 1 });
    }
}

sub save {
    if ($opt->{monitor}) {
	my $usageMonitor = $egnee->{sentenceBasedAnalysisObserverRegistry}->get('morpheme usage monitor');
	$usageMonitor->onFinished;
    }

    # annotation などが反映されていないかもしれないので全部 update
    my $workingDictionary = $egnee->{workingDictionary};
    $workingDictionary->saveAsDictionary();
    $workingDictionary->update();
    if ($opt->{stat}) {
	&logger;
	$logger->close;
    }
}

sub logger {
    $logger->printf("documentCount\t%d\n", $simpleMonitor->{documentCount});
    $logger->printf("sentenceCount\t%d\n", $simpleMonitor->{sentenceCount});
    $logger->printf("bnstCount\t%d\n", $simpleMonitor->{bnstCount});
    $logger->printf("mrphCount\t%d\n", $simpleMonitor->{mrphCount});
    $logger->printf("exampleCount\t%d\n", $egnee->{accumulator}->getTotal) if ($opt->{acquisition});
    $logger->printf("usedExampleCount\t%d\n", $usedExampleCount);
    $logger->printf("stemCount\t%d\n", $egnee->{workingDictionary}->getTotal);
    $logger->printf("acquisitionCount\t%d\n", $simpleMonitor->{acquisitionCount});
    $logger->print("----------\n");
}

# DEBUG
END {
    print("the program exits\n");
    print("status code: $?\n");
    # printf "documentPool: %d\n", $documentPool->isEmpty;
}
