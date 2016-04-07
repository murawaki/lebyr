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
use Document::StandardFormat;
use AnalyzerRegistry;
use Analyzer::Juman;
use Analyzer::KNP;

my $analyzerRegistry = AnalyzerRegistry->new;
$analyzerRegistry->add(Analyzer::Juman->new('juman', {
    jumanOpt => { rcfile => "/home/murawaki/.jumanrc.bare" }
}), ['raw']);
my $knp = Analyzer::KNP->new('knp');
$analyzerRegistry->add($knp, ['juman', 'raw']);
Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);


my $filename = "/home/murawaki/data/online/random/100103602.xml.gz";
my $tmpfile = "/tmp/" . "00000913" . '.xml';
`gunzip -fc $filename > $tmpfile`;
my $document = Document::StandardFormat->new($tmpfile);
unlink($tmpfile);

# $knp->exec($document);
my $sentenceList = $document->getAnalysis('sentence');
my $sentence = $sentenceList->get(1);
my $knpResult = $sentence->get('knp');
print $knpResult->spec;

1;
