#!/bin/env perl
#
# count words to build a language model of ContentW
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Storable qw/nstore/;

use Egnee::GlobalConf;
use Egnee::GlobalServices;
use Egnee::DocumentPoolFactory;
use Egnee::AnalyzerRegistryFactory;

use Ngram;
use MorphemeUtilities;
use SuffixExtractor;
use SentenceBasedAnalysisObserverRegistry;

binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs" };
GetOptions($opt, 'conf=s', Egnee::DocumentPoolFactory::optionList, 'debug', 'inputdir=s', 'output=s');
# backward compatibility
$opt->{docdir} = $opt->{inputdir} if (defined($opt->{inputdir}));

my %TD; # Trigram Denominator
my %TN; # Trigram Numerator
# my %TZ; # Trigram non-Zero counts
my %BD; # Bigram Denominator
# my %BN; # Bigram Numerator
# my %BZ; # Bigram non-Zero counts
my $UD; # Unigram Denominator
# my %UN; # Unigram Numerator

&Ngram::initTable; # initialize
&Ngram::setGenkeiMode(1); # 原形をとりあえず採取
my $repnameList;

my $HEADID = &Ngram::bosID; # '$'
my $HEADKEY = &Ngram::compressID($HEADID);  # '$'
my $BOUNDARYID = &Ngram::boundaryID; # '|'
my $BOUNDARYKEY = &Ngram::compressID($BOUNDARYID);

my $sentenceBasedAnalysisObserverRegistry;
&init;

# # morpheme type
# my $BUNSETSU_START =  1;
# my $BUNSETSU_END   =  2;
# my $JIRITU         =  4;
# my $HUZOKU         =  8;
# my $JIRITU_START   = 16;
# my $JIRITU_END     = 32;
# my $JIRITU_SINGLE  = 64;

my $mrphInfo = {};

my $count = 0;
##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################
my $documentPool = Egnee::DocumentPoolFactory::createDocumentPool($opt);
while ((my $document = $documentPool->get)) {
    my $documentID = $document->getAnnotation('documentID');
    printf("#document\t%s\n", $documentID) if ($documentID);

    my $state = $document->isAnalysisAvailable('sentence');
    next if ($state <= 0);

    $sentenceBasedAnalysisObserverRegistry->onDataAvailable($document);
}

$mrphInfo->{ngram} = {
    TD => \%TD,
    # TN => \%TN,
    BD => \%BD,
    UD => $UD,
};
$mrphInfo->{table} = &Ngram::getTable;

nstore($mrphInfo, $opt->{output}) or die;

1;

sub examineSentence {
    my ($sentence) = @_;

    my $result = $sentence->get('knp');
    # filtering
    return unless (SuffixExtractor->isNoisySentence($result));

    my $bnstMap = &MorphemeUtilities::makeBnstMap($result);    

    my @mrphList = $result->mrph;
    my @mrphOList = ();
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];
 	my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph, { revertVoicing => 1 });
	push (@mrphOList, $mrphO);
    }
    &buildNgram(\@mrphOList, $bnstMap);
}

sub buildNgram {
    my ($mrphList, $bnstMap) = @_;

    my ($id2, $id1);
    $id2 = $id1 = $HEADID; # $w2 = $w1 = '$';

    # $TD{$HEADKEY_TD}++; # $TD{'$;$'}++;
    $BD{$HEADKEY}++; # $BD{'$'}++;
    for (my $i = 0; $i < scalar(@$mrphList); $i++) {
	my $mrph = $mrphList->[$i];
 	my $id0 = &Ngram::word2id(&Ngram::getWord($mrph));
	$UD++;
	$BD{pack("LLS", @$id0)}++;
	$TD{pack("LLSLLS", @$id1, @$id0)}++;
	# $TN{pack ("LLSLLSLLS", @$id2, @$id1, @$id0)}++;

	# 文節境界のカウント
	if ($i > 0 && $bnstMap->[$i]->[1] == 0) {
	    # w0 が文頭以外の文節先頭
	    $TD{pack("LLSLLS", @$BOUNDARYID, @$id0)}++;

	    # 片側だけ boundary の unigram を更新
	    $BD{$BOUNDARYKEY}++;
	}
	if ($i + 1 < scalar(@$mrphList) && $bnstMap->[$i + 1]->[1] == 0) {
	    # w0 が文末以外の文節終り
	    $TD{pack("LLSLLS", @$id0, @$BOUNDARYID)}++;
	}

	$id2 = $id1;
	$id1 = $id0;
    }
}

##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});
    Egnee::GlobalConf::set('standardformat-document.use-knp-anotation', 0);

    Egnee::GlobalConf::set('knp.options', ' -tab -bnst -disable-emoticon-recognition');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;
    $sentenceBasedAnalysisObserverRegistry->addHook(\&examineSentence, { getUnique => 1 });
}

1;
