#!/usr/bin/env perl
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;

use Egnee::GlobalConf;
use Egnee::DocumentPoolFactory;
use Egnee::AnalyzerRegistryFactory;
use MorphemeUtilities;
use MorphemeGrammar;
use SentenceBasedAnalysisObserverRegistry;

use JumanDictionary;
use JumanDictionary::Static;

use SuffixExtractor;
use MorphemeGrammar qw/$separators/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs" };
GetOptions($opt, 'conf=s', Egnee::DocumentPoolFactory::optionList, 'dicdir=s', 'debug', 'log=s', 'clean');

# global vars
my $sentenceBasedAnalysisObserverRegistry;
my $workingDictionary;
my $documentID;
my $currentDomain;

&init;

############################################################
#                       main routine                       #
############################################################
my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    $documentID = $document->getAnnotation('documentID');
    printf("#document\t%s\n", $documentID) if ($documentID);

    &setDomain($document);
    $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}

# 最後に辞書を更新
$workingDictionary->saveAsDictionary;
$workingDictionary->update;



############################################################
#                       subroutines                        #
############################################################
sub setDomain {
    my ($document) = @_;

    my $url = $document->url;
    if ($url =~ /^(?:https?:\/\/)?([^\/]+)/xi) {
	$currentDomain = $1;
    } else {
	print STDERR ("malformed URL: $url\n");
    }
}

sub examineSentence {
    my ($sentence) = @_;

    my $result = $sentence->get('knp');
    my @bnstList = $result->bnst;
    for (my $i = 0; $i < scalar(@bnstList); $i++) {
 	my $bnst = $bnstList[$i];
 	my $bnstN = $bnstList[$i + 1];

	my @mrphList = $bnst->mrph;
	for (my $j = 0; $j < scalar(@mrphList); $j++) {
	    my $mrph = $mrphList[$j];
 	    next unless ($mrph->imis =~ /自動獲得/);

	    &updateMorphemeInfo($mrph, $j, $bnst, $bnstN);
 	}
    }
}

# annotation の意味:
#   hasSuffix: suffix つきで現れた回数
#   eob: 文節末に出現
#   sep: 次が記号
#   withLeft: 複合語で左に要素がある
#   rightmost: 右になにもない
#   single: 複合語の一部になっていない
sub updateMorphemeInfo {
    my ($mrph, $mrphPos, $bnst, $bnstN) = @_;

    $mrph = &MorphemeUtilities::getOriginalMrph($mrph);

    # 制限は hinsi だけで登録済みか調べる
    my $voc = $workingDictionary->getMorpheme($mrph->genkei, { '品詞' => $mrph->hinsi } );
    my $me;
    unless (defined($voc) && scalar(@$voc) == 1 && ($me = $voc->[0]) ) {
	if ($opt->{debug}) {
	    printf STDERR ("mrph not found in working dictionary: %s\n", $mrph->genkei);
	}
	return;
    }
    my $annotation = $me->getAnnotationCollection;

#     if ($mrph->hinsi eq '名詞' ||
# 	$mrph->katuyou1 eq 'ナ形容詞' ||
# 	$mrph->katuyou1 eq '母音動詞') {
# 	&checkBunsetsuContext ($annotation, $mrph, $mrphPos, $bnst, $bnstN);
#     }

    $annotation->{count}++;
    $annotation->{domain}->{$currentDomain}++;
    my $curID = $annotation->{curID};
    if ($documentID ne $curID) {
	$annotation->{df}++;
	$annotation->{curID} = $documentID;

	printf("%s:%s\t%s\n", $mrph->genkei, $annotation->{posS}, $documentID);
    }
}

sub checkBunsetsuContext {
    my ($annotation, $mrph, $mrphPos, $bnst, $bnstN) = @_;
    my @mrphList = $bnst->mrph;

    # TODO:
    #  名詞をナ形容詞扱いしたときの誤解析の吸収

    my $hasRight = 0;
    # 先に後ろ
    if ($mrphPos == $#mrphList) {
	$annotation->{eob}++;	
    } else {
	my ($mrphS, $startPoint, $opOpt) = SuffixExtractor->getTargetMrph($bnst, { all => 1 });
	my $suffixStruct;
	# サフィックスを含む
	if (defined($mrphS) && $mrphPos == $startPoint) {
	    # $mrphS は JUMAN の品詞に戻されている
	    $suffixStruct = SuffixExtractor->extractSuffix($mrphS, $startPoint, $bnst, $bnstN, $opOpt);
	}
	if ($suffixStruct) {
	    my $suffix = $suffixStruct->{suffix};
	    if (length($suffix) > 5) {
		$suffix = substr($suffix, 0, 5);
	    }
	    $annotation->{hasSuffix}++;
	    $annotation->{suffix}->{$suffix}++;
	    $annotation->{katuyou2}->{$suffixStruct->{katuyou2}}++;
	} else {
	    # 自分より後ろに自立語がある
	    if ($mrphPos < $startPoint) {
		my $rightElement = '';
		for (my $i = $mrphPos + 1; $i <= $startPoint; $i++) {
		    $rightElement .= ($mrphList[$i])->midasi;
		}
		$annotation->{withRight}++;
		$annotation->{rightElements}->{$rightElement}++;
		$hasRight = 1;
	    } else {
		$annotation->{rightSep}++;
	    }
	}
    }

    my $hasLeft = 0;
    if ($mrphPos == 0) {
	$hasRight = 0;
	$annotation->{rightmost}++;
    } else {
	my $leftElement = '';
	for (my $i = $mrphPos - 1; $i >= 0; $i--) {
	    my $mrphT = $mrphList[$i];
	    my $midasi = $mrphT->midasi;

	    if ($mrphT->hinsi eq '特殊' || $separators->{$midasi}) {
		last;
	    }
	    $leftElement = $midasi . $leftElement;
	}
	if ($leftElement) {
	    $annotation->{withLeft}++;
	    $annotation->{leftElements}->{$leftElement}++;
	    $hasLeft = 1;
	} else {
	    $annotation->{leftSep}++;

	}
    }

    if (!$hasLeft && !$hasRight) {
	$annotation->{single}++;
    }
}

sub init {
    # クエリをファイルで指定
    if (defined ($opt->{spec})) {
	# this must be called before mkdir
	# $opt->{dicdir} will not be overridden if provided by the command-line
	Egnee::DocumentPoolFactory::processSpec($opt);
    }
    die unless ($opt->{dicdir});
    `mkdir -p $opt->{dicdir}`;
    die unless ( -d $opt->{dicdir} );
    my $jumanrcFile = "$opt->{dicdir}/.jumanrc";

    Egnee::GlobalConf::loadFile($opt->{conf});
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 0);

    my $rcPath = Egnee::GlobalConf::get('main-dictionary.rc-path');
    JumanDictionary->makeJumanrc($rcPath, $jumanrcFile, $opt->{dicdir});

    Egnee::GlobalConf::set('juman.rcfile', $jumanrcFile);
    Egnee::GlobalConf::set('knp.options', '-tab -bnst');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    my $mainDicDirList = Egnee::GlobalConf::get('main-dictionary.db-path');
    my $mainDictionary = JumanDictionary::Mixed->new;
    foreach my $mainDicDir (@$mainDicDirList) {
	$mainDictionary->add(JumanDictionary::Static->new($mainDicDir));
    }
    $workingDictionary = JumanDictionary->new($opt->{dicdir},
					      { writable => 1, doLoad => 1, annotation => 1 });
    $workingDictionary->saveAsDictionary;
    $workingDictionary->update;

    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;
    $sentenceBasedAnalysisObserverRegistry->addHook(\&examineSentence, { getUnique => 1 });

    # 辞書の初期化
    my $meList = $workingDictionary->getAllMorphemes;
    return 0 if (scalar (@$meList) <= 0);
    foreach my $me (@$meList) {
	my $annotation = $me->getAnnotationCollection;

	if ($opt->{clean}) {
	    foreach my $key (keys(%$annotation)) {
		delete($annotation->{$key});
	    }
	}

	my $mrph = $me->getJumanMorpheme;
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	$annotation->{posS} = $posS;
	$annotation->{df} = 0;
    }

}

1;
