#!/bin/env perl
#
# KNP の構文・格解析結果を出力
#
use strict;
use warnings;
use utf8;

use Getopt::Long;

use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
# use AnalyzerRegistry;
# use Analyzer::Juman;
# use Analyzer::KNP;
# use AnalysisObserverRegistry;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs", knpOpt => '-tab -check' };
GetOptions($opt, 'conf=s', 'debug', Egnee::DocumentPoolFactory::optionList, 'knpOpt=s');

##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

my $jumanOpt;
my $knpOpt = $opt->{knpOpt};
my ($juman, $knp);
&init;

my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    my $documentID = $document->getAnnotation('documentID');
    $document->can('url') and $document->url =~ /^(?:https?:\/\/)?([^\/]+)/xi and my $domain = $1;
    printf("#document\t%s\t%s\n", $documentID, $domain);

    my $sentenceList = $document->getAnalysis('sentence');
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	&onDataAvailable($sentence);
    }
}

sub onDataAvailable {
    my ($sentence) = @_;

    my $rawString = $sentence->get('raw');
    return unless ($rawString);

    my $buf;
    eval {
	$buf = $juman->juman_lines($rawString . "\n");
    };
    if ($@ || !$buf) {
	print STDERR ("juman failed: $rawString\n");
	$juman = &juman;
	return;
    }
    eval {
	$buf = $knp->_real_parse([join ('', @$buf)], 'あ');
    };
    if ($@ || !$buf) {
	print STDERR ("knp failed: $rawString\n");
	$knp = &knp;
	return;
    }
    print(join('', @$buf));
}

sub juman {
    return Juman->new(rcfile => $jumanOpt);
}
sub knp {
    return KNP->new( -Option => $knpOpt );
}

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});
    $jumanOpt = Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic');

    # debug
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 0);

    $juman = &juman;
    $knp = &knp;

    {
	# HACK!
	no strict 'refs';       # reference within glob
	no warnings 'redefine'; # sometimes override the existing subroutines
	*{"KNP::_internal_analysis"} = sub { return $_[1]; };
    }
}

1;
