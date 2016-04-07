package Egnee;
#
# Lexicon Acquirer: the main package
#
use strict;
use warnings;
use utf8;

use Storable qw/retrieve/;

use Egnee::Logger;
use Egnee::GlobalConf;
use Egnee::GlobalServices;
use Egnee::AnalyzerRegistryFactory;
use Sentence;
use SentenceBasedAnalysisObserverRegistry;
use JumanDictionary;
use JumanDictionary::Mixed;
use JumanDictionary::Static;
use SuffixList;
use UnknownWordDetector;
use CandidateEnumerator;
use ExampleAccumulator;
use StemFinder;
use DictionaryManager;
use MultiClassClassifier;
use MorphemeUsageMonitor;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift,
    };
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{opt}->{loglevel} = 0 unless (defined($self->{opt}->{loglevel}));

    bless($self, $class);
    $self->init;
    Egnee::Logger::setLogger($self->{opt}->{debug});
    Egnee::Logger::info("Egnee started\n");
    return $self;
}

sub init {
    my ($self) = @_;

    my $debug = Egnee::GlobalConf::get('main.debug');
    $self->{opt}->{debug} = $debug;

    my $dictionaryDir = Egnee::GlobalConf::get('working-dictionary.path');
    my $rcPath = Egnee::GlobalConf::get('main-dictionary.rc-path');
    my $jumanrcPath = $dictionaryDir . "/.jumanrc";
    JumanDictionary->makeJumanrc($rcPath, $jumanrcPath, $dictionaryDir);
    Egnee::GlobalConf::set('juman.rcfile', $jumanrcPath);
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    my $suffixListDir = Egnee::GlobalConf::get('suffix-list.path');
    my $suffixList = SuffixList->new($suffixListDir);

    my $workingDictionary = JumanDictionary->new($dictionaryDir,
						 { writable => 1, annotation => 1, doLoad => Egnee::GlobalConf::get('working-dictionary.do-load') });

    my $mainDicDirList = Egnee::GlobalConf::get('main-dictionary.db-path');
    my $mainDictionary = JumanDictionary::Mixed->new;
    foreach my $mainDicDir (@$mainDicDirList) {
	$mainDictionary->add(JumanDictionary::Static->new($mainDicDir));
    }

    my $sentenceBasedAnalysisObserverRegistry = SentenceBasedAnalysisObserverRegistry->new;

    $self->{suffixList} = $suffixList;
    $self->{mainDictionary} = $mainDictionary;
    $self->{workingDictionary} = $workingDictionary;
    $self->{sentenceBasedAnalysisObserverRegistry} = $sentenceBasedAnalysisObserverRegistry;

    if (Egnee::GlobalConf::get('main.acquisition')) {
	my $enumerator = CandidateEnumerator->new($suffixList, { debug => $debug });
	$enumerator->addListener($self);

	my $decompositionRuleFile = Egnee::GlobalConf::get('unknown-word-detector.decomposition-rule-file');
	my $unihan = retrieve(Egnee::GlobalConf::get('morpheme-variant-checker.unihan-db'));
	my $dictionaryManagerOpt = {
	    suffixList => $suffixList,
	    decompositionRuleFile => $decompositionRuleFile,
	    unihan => $unihan,
	    debug => $debug,
	};

	my $ruleFile = Egnee::GlobalConf::get('unknown-word-detector.rule-file');
	my $detector;
	if (Egnee::GlobalConf::get('unknown-word-detector.use-ngram')) {
	    my $repnameListFile = Egnee::GlobalConf::get('unknown-word-detector.repname-list');
	    my $repnameNgramFile = Egnee::GlobalConf::get('unknown-word-detector.repname-ngram');

	    my $repnameList = retrieve($repnameListFile) or die;
	    my $repnameNgram = retrieve($repnameNgramFile) or die;
	    $detector = UnknownWordDetector->new($ruleFile, $repnameList, $repnameNgram,
                     { debug => $debug, debugSmoothing => $debug , noDetectHanNgram => $self->{opt}->{noDetectHanNgram}});
	    $dictionaryManagerOpt->{repnameList} = $repnameList;
	    $dictionaryManagerOpt->{repnameNgram} = $repnameNgram;
	} else {
	    $detector = UnknownWordDetector->new($ruleFile, undef, undef, { enableNgram => 0, debug => $debug });
	}
	$detector->setEnumerator($enumerator);

	my $dictionaryManager = DictionaryManager->new($mainDictionary, $workingDictionary, $dictionaryManagerOpt);

	$sentenceBasedAnalysisObserverRegistry->add('unknown word detector', $detector, { 'getUnique' => 1 });

	my $accumulator = ExampleAccumulator->new($dictionaryManager, { debug => $debug });
    my $stemFinder = StemFinder->new({ debug => $debug, safePosMode => $self->{opt}->{safePosMode}});

	$self->{opt}->{safeMode} = Egnee::GlobalConf::get('main.safe-mode');
	if ($self->{opt}->{safeMode}) {
	    use ExampleGC;
        $self->{opt}->{checkThres} = 10000 unless (defined($self->{opt}->{checkThres}));
	    $self->{opt}->{limit}      = 8000 unless (defined($self->{opt}->{limit}));
        $self->{gc} = ExampleGC->new($accumulator, { debug => $debug, checkThres =>  Egnee::GlobalConf::get('ExampleGC.threshold'), limit => Egnee::GlobalConf::get('ExampleGC.threshold') });
	    $stemFinder->setSafeMode(Egnee::GlobalConf::get('stem-finder.safe-mode'));
	    $dictionaryManager->setSafeMode(1);
	}

	$self->{dictionaryManager} = $dictionaryManager;
	$self->{accumulator} = $accumulator;
	$self->{stemFinder} = $stemFinder;
    }
}

sub addUsageMonitor {
    my ($self, $opt) = @_;

    my $monitorOpt = { suffix => 1, reset => $opt->{doLoad}, debug => $opt->{debug} };
    $monitorOpt->{fusanaModel} = retrieve(Egnee::GlobalConf::get('morpheme-usage-monitor.fusana-model')) or die;

    my $monitor = MorphemeUsageMonitor->new($self->{dictionaryManager}, $self->{suffixList}, $monitorOpt);
    $self->{sentenceBasedAnalysisObserverRegistry}->add('morpheme usage monitor', $monitor, { 'getUnique' => 1 });
}

sub processDocument {
    my ($self, $document) = @_;

    my $state = $document->isAnalysisAvailable('sentence');
    return if ($state <= 0);

    $self->{sentenceBasedAnalysisObserverRegistry}->onDataAvailable($document);
    $self->{gc}->run if ($self->{opt}->{safeMode});

    return $document;
}

sub processRawString {
    my ($self, $rawString) = @_;

    my $sentence = Sentence->new({ 'raw' => $rawString });
    $self->{sentenceBasedAnalysisObserverRegistry}->evokeListener($sentence);
    $self->{gc}->run if ($self->{opt}->{safeMode});

    return $sentence;
}

# 検出された未知語の構造体をパラメータにして呼び出される
sub processExample {
    my ($self, $example) = @_;

    if (defined($self->{exampleCallback})) {
	&{$self->{exampleCallback}} ({ type => 'example', obj => $example });
    }

    Egnee::Logger::dumpValue($example) if ($self->{opt}->{loglevel} >= 2);

    $example->{count} = $self->{stemFinder}->getCounter; # GC 用のカウント

    # 用例を格納、前方境界を共有する用例リストの境界候補ごとのリスト
    my $sharedExamplesPerFront = $self->{accumulator}->add($example);
    if (scalar (@$sharedExamplesPerFront) > 0) {
	my ($entry, $exampleList) = $self->{stemFinder}->getEntry($sharedExamplesPerFront);
    if (defined ($entry) && !($entry eq "POS_UNLIMITED_CANDIDATES")) {
 	    Egnee::Logger::info(sprintf("register %s:%s\n", $entry->{stem}, $entry->{posS}));

	    if (defined($self->{dictionaryCallback})) {
		&{$self->{dictionaryCallback}}({ type => 'beforeChange', obj => $entry });
	    }

	    $self->{dictionaryManager}->registerEntry($entry, $self->{accumulator}, $exampleList);
	}
    }
}

sub setDictionaryCallback {
    my ($self, $callback) = @_;

    $self->{dictionaryCallback} = $callback;
    $self->{dictionaryManager}->setCallback($callback);
}

sub setExampleCallback {
    my ($self, $callback) = @_;

    $self->{exampleCallback} = $callback;
}

1;
