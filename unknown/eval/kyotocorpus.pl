#!/bin/env perl
#
# 短いひらがな連続には正解例がおおすぎるので、
# KyotoCorpus から収集したものを負例とする
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw /nstore/;

use UnknownWordDetector;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {};
GetOptions($opt, 'kyotocorpus=s', 'debug', 'output=s');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});

my $ruleFile = '/home/murawaki/research/unknown/eval/undef2.storable';
my $mainDicDir = '/home/murawaki/research/lebyr/data';
my $suffixListDir = "/home/murawaki/research/lebyr/data";
my $repnameListFile = "/home/murawaki/research/lebyr/data/cfRepname.storable";
my $repnameNgramFile = "/home/murawaki/research/lebyr/data/repnameNgram.storable";

my $detector;

&init;

my $data = {};

use DocumentPool::KyotoCorpus;
my $documentPool = DocumentPool::KyotoCorpus->new($opt->{kyotocorpus}, { debug => 1});
while ((my $document = $documentPool->get)) {
    my $documentID = $document->getAnnotation('documentID');
    printf("#document\t%s\n", $documentID) if ($documentID);

    my $sentenceList = $document->getAnalysis('sentence');
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	$detector->onSentenceAvailable($sentence);
    }
}
nstore($data, $opt->{output}) or die;


# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($knpResult, $exampleCand) = @_;

    my $mrphP = $exampleCand->{mrphP};
    my $mrph = $exampleCand->{mrph};
    $data->{$mrphP->genkei . ':' . $mrph->genkei}++;
}

sub init {
    $detector = UnknownWordDetector->new($ruleFile, undef, undef, { enableNgram => 0, debug => 1 });
    $detector->setCallback(\&processExample);
}

1;
