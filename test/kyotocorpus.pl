#!/bin/env perl
#
# KyotoCorpus のテスト
#
use strict;
use utf8;

use Encode;
use Getopt::Long;

use Egnee::GlobalConf;
use Egnee::GlobalServices;
use Egnee::AnalyzerRegistryFactory;
use AnalysisObserverRegistry;
use JumanDictionary;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my %opt;
GetOptions(\%opt, 'debug', 'tgzfile=s');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

&init;

use DocumentPool::KyotoCorpus;
my $documentPool = DocumentPool::KyotoCorpus->new("/home/murawaki/download/KyotoCorpus", { fullKNPFeatures => 1, debug => 1});

 main_loop:
    while ((my $document = $documentPool->get)) {

	# debug
	# last main_loop;

	my $analysisObserver;
	while (($analysisObserver = Egnee::GlobalServices::get('analysis observer registry')->next)) {
	    my $serviceID = $analysisObserver->getRequiredAnalysis;
	    my $state = $document->isAnalysisAvailable($serviceID);

	    # debug
	    # my $state = 0;

	    # analysis not supplied yet
	    if ($state == 0) {
		# maybe we need more than one analyzers, but ...
		my $analyzer = Egnee::GlobalServices::get('analyzer registry')->get($serviceID);
		next main_loop unless (defined($analyzer));

		$state = $analyzer->exec($document);
	    }
	    # failed to gain analysis
	    if ($state < 0) {
		next main_loop;
	    }

	    $analysisObserver->onDataAvailable($document);
	}
    }

1;

##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

sub init {
    Egnee::GlobalConf::loadFile("/home/murawaki/research/lebyr/prefs");

    # debug
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 1);

    Egnee::GlobalConf::set('juman.rcfile', Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic'));
    Egnee::GlobalConf::set('knp.options', '-tab -dpnd');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    my $analysisObserverRegistry = AnalysisObserverRegistry->new;
    use SentenceBasedAnalysisObserverRegistry;
    my $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;
    $analysisObserverRegistry->add($sentenceBasedAnalysisObserverRegistry);

    use SuffixExtractor;
    $sentenceBasedAnalysisObserverRegistry->add('suffix extractor', SuffixExtractor->new,
						{ 'getUnique' => 1 });

    Egnee::GlobalServices::set('analysis observer registry', $analysisObserverRegistry);
}

1;
