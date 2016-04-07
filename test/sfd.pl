#!/bin/env perl
#
# StandardFormat のテスト
#
use strict;
use utf8;

use Encode;
use Getopt::Long;

use Egnee::GlobalConf;
use Egnee::GlobalServices;
use Egnee::Logger;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions ($opt, 'input=s', 'debug');


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

use Document::StandardFormat;

Egnee::GlobalConf::loadFile("/home/murawaki/research/lebyr/prefs");
Egnee::GlobalConf::set('standardformat-document.use-knp-annotation', 1);

use AnalyzerRegistry;
my $analyzerRegistry = AnalyzerRegistry->new;
use Analyzer::KNP;
$analyzerRegistry->add(Analyzer::KNP->new('knp'), ['juman', 'raw']);
Egnee::GlobalServices::set('analyzer registry', $analyzerRegistry);

Egnee::Logger::setLogger(1, 'Document::StandardFormat');
my $sfd = Document::StandardFormat->new($opt->{input});
my $domain = $sfd->getAnnotation('domain');
print("domain?: $domain\n");
print("url: ", $sfd->url, "\n");
if ($sfd->url =~ /^(?:https?:\/\/)?([^\/]+)/xi) {
    print "domain: ", $1, "\n";
}

my $sentenceList = $sfd->getAnalysis('sentence');
printf("Class: %s\n", ref($sentenceList));
my $iterator = $sentenceList->getIterator;
while ((my $sentence = $iterator->nextNonNull)) {
    printf("Result: Class: %s\n", ref($sentence));

    my $knpResult = $sentence->get('knp');
    print Analyzer::KNP->serialize($knpResult);
    # print $result->all_dynamic; # Syngraph つき
    # last;
}

1;
