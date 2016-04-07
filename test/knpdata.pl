#!/bin/env perl

use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'debug');

use Egnee::GlobalServices;
use DocumentPool::KNPData;
use AnalyzerRegistry;
use Analyzer::Raw;
use Analyzer::Juman;
use Analyzer::KNP;
use Sentence;

my $analyzerRegistry = AnalyzerRegistry->new;
$analyzerRegistry->add(Analyzer::Juman->new('juman', {
    jumanOpt => { rcfile => "/home/murawaki/.jumanrc.bare" }
}), ['raw']);
my $knp = Analyzer::KNP->new('knp');
$analyzerRegistry->add($knp, ['juman', 'raw']);
my $raw = Analyzer::Raw->new('raw');
$analyzerRegistry->add($raw, ['knp', 'juman']);
Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);
Sentence->setAnalyzerRegistry($analyzerRegistry);

my $filename = "/vine5/murawaki/x00000";
# my $filename = "/vine5/murawaki/test.bz2";
my $documentPool = new DocumentPool::KNPData($filename, { debug => 1, compressed => 1 });
while ((my $document = $documentPool->get)) {
    my $documentID = $document->getAnnotation('documentID');
    my $domain = $document->getAnnotation('domain');
    printf("#document\t%s\t%s\n", $documentID, $domain);

    my $sentenceList = $document->getAnalysis('sentence');
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	# my $knpResult = $sentence->get('knp');
	# print $knpResult->spec;
	my $rawString = $sentence->get('raw');
	print "$rawString\n";
    }
}

1;
