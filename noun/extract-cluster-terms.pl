#!/bin/env perl
#
# extract terms to cluster documents
#
use strict;
use utf8;
use warnings;

use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
use Egnee::AnalyzerRegistryFactory;
use AnalysisObserverRegistry;
use MorphemeUtilities;

use Encode;
use Digest::MD5 qw/md5_base64/;

use Getopt::Long;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs", verbose => 1 };
GetOptions($opt, 'conf=s', 'debug', Egnee::DocumentPoolFactory::optionList);

my $stopHinsi = {
    '指示詞' => 1,
    '接続詞' => 2,

    '副詞' => 3,
    '連体詞' => 4,
};
my $stopBunrui = {
    # noun
    '形式名詞' => 1,
    '副詞的名詞' => 1,
    '時相名詞' => 1,
};
my $stopRepname = {
    'する/する' => 1,
    '成る/なる' => 1,
    '有る/ある' => 1,
    '居る/いる' => 1,
    '思う/おもう' => 1,
    'やる/やる' => 1,
    '言う/いう' => 1,
    '出来る/できる' => 1,
    '付く/つく' => 1,
    'つく/つく' => 1,

    'あなた/あなた' => 2,
    '私/わたし' => 2,
    '彼/かれ' => 2,
    '彼女/かのじょ' => 2,
    '自分/じぶん' => 2,
    '事/こと' => 2,
    '一部/いちぶ' => 2,
    'そんなこんな/そんなこんな' => 2,

    'ホームページ/ほーむぺーじ' => 20,
    '頁/ぺーじ' => 20,
    'サイト/さいと' => 20,

    '無い/ない' => 3,
    '良い/よい' => 4,

    '或る/ある' => 4,
};

my $sentenceBasedAnalysisObserverRegistry;
&init;

my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    my $documentID = $document->getAnnotation('documentID');
    my $domain = $document->getAnnotation('domain');
    unless ($domain) {
	$document->can('url') and $document->url =~ /^(?:https?:\/\/)?([^\/]+)/xi and $domain = $1;
    }
    printf("#document\t%s\t%s\n", $documentID, $domain);

    &onDocumentAvailable($document);
    # $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}

sub onDocumentAvailable ($) {
    my ($document) = @_;

    my $sentenceList = $document->getAnalysis('sentence');
    return unless (defined($sentenceList));

    my $termDB = {};

    my %udb;
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	my $rawString = $sentence->get('raw');
	my $knpResult = $sentence->get('knp');
	next unless ($knpResult);
	my $isUnique = 1;
	my $digest = md5_base64(encode_utf8($rawString));
	next if ($udb{$digest}++);

	&updateTermDB($termDB, $knpResult);
    }
    &outputTermDB($termDB);
}

sub updateTermDB ($$) {
    my ($termDB, $knpResult) = @_;

  outer:
    foreach my $mrph ($knpResult->mrph) {
	my $fstring = $mrph->fstring;
	next unless (index($fstring, '<自立>') >= 0 && index($fstring, '<内容語>') >= 0);
	next if (index($fstring, '<記号>') >= 0);
	next if (index($fstring, '<付属動詞候補') >= 0);
	next if ($fstring =~ /\<カテゴリ\:[^\>]*場所\-機能/);
	next if ($mrph->hinsi eq '特殊');
	next if ($stopHinsi->{$mrph->hinsi});
	next if ($stopBunrui->{$mrph->bunrui});
	my $genkei = $mrph->genkei;
	next if ($genkei =~ /^(?:\p{Hiragana}|\p{Katakana}|ー)$/);

	my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph, { revertVoicing => 1 });
	my $doukeiList = [$mrphO];
	push(@$doukeiList, $mrphO->doukei);
	foreach my $mrph2 (@$doukeiList) {
	    next outer if ($stopRepname->{$mrph2->repname || ''});
	}
	$termDB->{$genkei}++;
    }
}

sub outputTermDB ($) {
    my ($termDB) = @_;

    while ((my ($term, $val) = each(%$termDB))) {
	printf("%s:%d\t", $term, $val);
    }
    print("\n");
}

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});

    # debug
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 1);

    Egnee::GlobalConf::set('juman.rcfile', Egnee::GlobalConf::get('analyzer-juman.jumanrc-autodic'));
    Egnee::GlobalConf::set('knp.options', '-tab -dpnd');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    # use SentenceBasedAnalysisObserverRegistry;
    # $sentenceBasedAnalysisObserverRegistry = new SentenceBasedAnalysisObserverRegistry ();
    # $sentenceBasedAnalysisObserverRegistry->addHook (\&onDataAvailable, { getUnique => 1 });
}

1;
