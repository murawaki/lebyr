#!/bin/env perl
#
# サフィックスを集めてくる
# 結果は標準出力に吐く
# format: suffix POS katuyou2 genkei
#
use strict;
use warnings;
use utf8;

use Getopt::Long;

use Egnee::AnalyzerRegistryFactory;
use Egnee::DocumentPoolFactory;
use Egnee::GlobalConf;
use AnalysisObserverRegistry;
use SentenceBasedAnalysisObserverRegistry;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs" };
GetOptions($opt, 'conf=s', Egnee::DocumentPoolFactory::optionList, 'debug', 'autodic');

##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

my $sentenceBasedAnalysisObserverRegistry;
&init;

my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $documentID = $document->getAnnotation('documentID');
    printf("#document\t%s\n", $documentID) if ($documentID);

    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}
# &save ();

1;

##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});

    # debug
    # 解析しなおさない
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 0);

    if ($opt->{autodic}) {
	Egnee::GlobalConf::set('juman.rcfile', Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic'));
    }
    Egnee::GlobalConf::set('knp.options', '-tab -dpnd -postprocess');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;

    use SuffixExtractor;
    $sentenceBasedAnalysisObserverRegistry->add('suffix extractor',
						SuffixExtractor->new({ markAcquired => 1, excludeDoukei => 1 }),
						{ 'getUnique' => 1 } );

}

1;
