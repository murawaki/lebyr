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
use Sentence;
use AnalyzerRegistry;
use Analyzer::Raw;
use Analyzer::Juman;
use Analyzer::KNP;

my $analyzerRegistry = AnalyzerRegistry->new;
{
    $analyzerRegistry->add(Analyzer::Juman->new('juman', {
	jumanOpt => { rcfile => "/home/murawaki/.jumanrc.exp" }
    }), ['raw']);
    my $knp = Analyzer::KNP->new('knp');
    $analyzerRegistry->add($knp, ['juman', 'raw']);
    my $raw = Analyzer::Raw->new('raw');
    $analyzerRegistry->add($raw, ['knp', 'juman']);
    Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);

    Sentence->setAnalyzerRegistry($analyzerRegistry);
}

use KNP;
my $knp = KNP->new;
my $knpResult = $knp->parse('ただいまマイクのテスト中です。');

my $sentence = Sentence->new({ knp => $knpResult });

printf ("%s\n", $sentence->get('raw'));

1;
