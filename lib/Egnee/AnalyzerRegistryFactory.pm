package Egnee::AnalyzerRegistryFactory;

use strict;
use utf8;
use warnings;

use Egnee::GlobalConf;
use Egnee::GlobalServices;
use Sentence;
use AnalyzerRegistry;
use Analyzer::Raw;
use Analyzer::Juman;
use Analyzer::KNP;

sub createAnalyzerRegistry {
    my $debug = Egnee::GlobalConf::get('main.debug');

    my $analyzerRegistry = AnalyzerRegistry->new;
    Sentence->setAnalyzerRegistry($analyzerRegistry);

    $analyzerRegistry->add(Analyzer::Raw->new('raw'), ['knp', 'juman']);
    $analyzerRegistry->add(Analyzer::Juman->new('juman', {
	jumanOpt => { rcfile => Egnee::GlobalConf::get('juman.rcfile') },
	debug => $debug,
    }), ['raw']);
    $analyzerRegistry->add(Analyzer::KNP->new('knp', {
	knpOption => Egnee::GlobalConf::get('knp.options'),
	debug => $debug,
    }), ['juman']); # 'raw' omitted to ensure that Analyzer::Juman is always used
    Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);
    return $analyzerRegistry;
}

1;
