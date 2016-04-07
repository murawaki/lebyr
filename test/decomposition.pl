#!/bin/env perl
#
# 分割可能性のチェック
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;
use Storable qw/retrieve/;

use Egnee::GlobalConf;
use Egnee::AnalyzerRegistryFactory;
use SentenceBasedAnalysisObserverRegistry;

use JumanDictionary;
use JumanDictionary::Static;

use SuffixList;
use UnknownWordDetector;
use DictionaryManager;

use Dumpvalue;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => '/home/murawaki/research/lebyr/prefs', dicdir => '/tmp/dic', debug => 1 };
GetOptions($opt, 'conf=s', 'stdin', 'dicdir=s', 'debug');

my $jumanrcOrig = "/home/murawaki/.jumanrc";

# my $detector;
# my $detectFlag;

my $dictionaryDir = $opt->{dicdir};
`mkdir -p $dictionaryDir`;
die unless ( -d $dictionaryDir );
my $jumanrcFile = "$dictionaryDir/.jumanrc";

my $sentenceBasedAnalysisObserverRegistry;
my $dictionaryManager;
my $workingDictionary;

&init;

my $entryL = {
    stem => 'ふぁぼったー',
    posS => '普通名詞',
};
my $entryS = {
    stem => 'ふぁぼ',
    posS => '子音動詞ラ行',
};

use JumanDictionary::MorphemeEntry::Annotated;
$entryS->{me} = &JumanDictionary::MorphemeEntry::Annotated::makeAnnotatedMorphemeEntryFromStruct($entryS);
$workingDictionary->appendSave($entryS->{me});
$workingDictionary->update;

$entryL->{me} = &JumanDictionary::MorphemeEntry::Annotated::makeAnnotatedMorphemeEntryFromStruct($entryL);
my $rv = $dictionaryManager->isDecomposable($entryS, "「あ」" . $entryL->{stem}, 1);
if ($rv) {
    printf("\tdelete longer entry!!! %s << %s\n", $entryL->{stem}, $entryS->{stem});
}


##################################################
#                                                #
#                  subroutines                   #
#                                                #
##################################################

# 諸々の初期化
sub init {
    JumanDictionary->makeJumanrc ($jumanrcOrig, $jumanrcFile, $dictionaryDir);

    Egnee::GlobalConf::loadFile($opt->{conf});

    Egnee::GlobalConf::set('juman.rcfile', $jumanrcFile);
    Egnee::GlobalConf::set('knp.options', '-tab -dpnd -check -timeout 600');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    my $suffixListDir = Egnee::GlobalConf::get('suffix-list.path');
    my $suffixList = SuffixList->new($suffixListDir);

    $workingDictionary = JumanDictionary->new($dictionaryDir,
					      { writable => 1, annotation => 1, doLoad => 0 });

    my $mainDicDirList = Egnee::GlobalConf::get('main-dictionary.db-path');
    my $mainDictionary = JumanDictionary::Mixed->new;
    foreach my $mainDicDir (@$mainDicDirList) {
	$mainDictionary->add(JumanDictionary::Static->new($mainDicDir));
    }

    $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;

    my $decompositionRuleFile = Egnee::GlobalConf::get('unknown-word-detector.decomposition-rule-file');
    my $unihan = retrieve(Egnee::GlobalConf::get('morpheme-variant-checker.unihan-db'));
    my $dictionaryManagerOpt = {
	suffixList => $suffixList,
	decompositionRuleFile => $decompositionRuleFile,
	unihan => $unihan,
	debug => $opt->{debug},
    };
    $dictionaryManager = DictionaryManager->new($mainDictionary, $workingDictionary, $dictionaryManagerOpt);
}

1;
