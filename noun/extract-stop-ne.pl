#!/bin/env perl
#
# 訓練データからノイズを除去
#
use strict;
use warnings;
use utf8;

use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
use Egnee::AnalyzerRegistryFactory;
use AnalysisObserverRegistry;
use MorphemeUtilities;
use NounCategorySpec;

use Getopt::Long;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs", verbose => 1 };
GetOptions($opt, 'conf=s', 'debug', 'verbose=i', Egnee::DocumentPoolFactory::optionList);

my $neList = {
    'PERSON' => '人名',
    'LOCATION' => '地名',
    'ORGANIZATION' => '組織名',
};
# 形態素の意味情報に付与されている末尾成分のリスト
my $entityTagList = {
    '人名' => 1,
    '地名' => 2,
    '住所' => 3,
    '組織名' => 4
};

my $sentenceBasedAnalysisObserverRegistry;
&init;

my $nounCat = NounCategorySpec->new;
my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    my $documentID = $document->getAnnotation('documentID');
    printf("#document\t%s\n", $documentID);
    $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}

sub onDataAvailable {
    my ($sentence) = @_;

    # 格要素のペアを取り出す
    my $knpResult = $sentence->get('knp');
    return unless ($knpResult);

    for my $tag (reverse($knpResult->tag)) {
	next unless ($tag->fstring =~ /\<NE\:([A-Z]+)\:([^\>]+)\>/);
	my ($type, $neString) = ($1, $2);
	next unless (defined($neList->{$type}));

	my $neMrph;
	my @mrphList = $tag->mrph;
	for (my $i = 0; $i < scalar(@mrphList); $i++) {
	    my $mrph = $mrphList[$i];
	    my $fstring = $mrph->fstring;
	    next unless ($fstring =~ /\<NE:[A-Z]+\:([a-z]+)\>/);
	    my $pos = $1;
	    if ($pos eq 'single') {
		$neMrph = $mrph;
	    } elsif ($pos eq 'head') {
		last unless ($i + 1 < scalar(@mrphList));
		my $mrphN = $mrphList[$i + 1];
		if ($mrphN->bunrui eq '名詞性特殊接尾辞' || $mrphN->bunrui eq '名詞性名詞接尾辞') {
		    $neMrph = $mrph;
		} elsif ($mrphN->imis =~ /(\w+)末尾(外)?[\s\"]/ && index($mrphN->fstring, '<文節主辞>') >= 0) {
		    # 「首相」など、一部の末尾要素についても候補を列挙する
		    my $entityTag = $1;
		    if ($entityTagList->{$entityTag}) {
			$neMrph = $mrph;
		    }
		}
	    }
	    last;
	}
	if (defined($neMrph)) {
	    next if (&MorphemeUtilities::isUndefined($neMrph));
	    my $flag = 0;
	    my $mrphList = [$neMrph];
	    push(@$mrphList, $neMrph->doukei);
	    foreach my $mrph (@$mrphList) {
		if ($neList->{$type} eq $mrph->bunrui) {
		    $flag = 1;
		    last;
		}
	    }
	    if (!$flag) {
		my $idString = $nounCat->getIDFromMrph($neMrph);
		printf("%s\t%s\t%s\t%s\n", $neMrph->genkei, $idString, $type, $neString);
	    }
	}
    }
}

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});

    # debug
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 1);

    if ($opt->{both} || $opt->{acquired}) {
	Egnee::GlobalConf::set('juman.rcfile', Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic'));
    }
    Egnee::GlobalConf::set('knp.options', ($opt->{probcase}? '-tab -check' : '-tab -check -dpnd'));
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    use SentenceBasedAnalysisObserverRegistry;
    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;
    $sentenceBasedAnalysisObserverRegistry->addHook(\&onDataAvailable, { getUnique => 1 });
}

1;
