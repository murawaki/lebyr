#!/bin/env perl
#
# 単純にマージされた辞書に対して後処理をほどこす
# やっつけ処理の塊
#
#
# TODO: 副詞と名詞のマージの検証
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Storable qw/retrieve/;
use Dumpvalue;

use Egnee::GlobalConf;
use Egnee::AnalyzerRegistryFactory;
use MorphemeGrammar qw/$IMIS $fusanaID2pos/;
use JumanDictionary;
use JumanDictionary::Mixed;
use JumanDictionary::Static;
use MorphemeUtilities;
use JumanDictionary::MorphemeVariantChecker;
use JumanDictionary::MorphemeEntry;
use JumanDictionary::MorphemeEntry::Annotated;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs",
	    rcfile => "/home/murawaki/.jumanrc.bare" };
GetOptions($opt, 'conf=s', 'debug', 'input=s', 'rcfile=s', 'dicdir=s', 'df_thres=i', 'count_thres=i', 'domainF_thres=i', 'unihan=s', 'clean');

my $KATAKANA_THRES_RATE = 2;

my ($dictionaryDir, $jumanrcFile);

die unless ( -f $opt->{input} );
my $fileName = $opt->{input};

# 作業用辞書を置くディレクトリ
# .jumanrc ファイルもここに置く
if ($opt->{dicdir}) {
    `mkdir -p $opt->{dicdir}`;
    die unless ( -d $opt->{dicdir} );
    $dictionaryDir = $opt->{dicdir};
    $jumanrcFile = "$dictionaryDir/.jumanrc";
    JumanDictionary->makeJumanrc($opt->{rcfile}, $jumanrcFile, $dictionaryDir);
}

my $workingDictionary;
my $dictionaryManager;
my $variantChecker;
my $usageMonitor;

&init;

# やっつけの stopwords
my $stopwords = {
    # irregular
    '來:母音動詞' => 1,
    '來:子音動詞ラ行' => 1,
    '來:子音動詞ラ行' => 1,
    'しに来:母音動詞' => 1,

    # one character
    '之:ナ形容詞' => 15,
    '為:ナ形容詞' => 15,
    '迄:ナ形容詞' => 15,
    '笑:ナ形容詞' => 15,
    '杜:ナ形容詞' => 15,
    '華:ナ形容詞' => 15,
    '燗:ナ形容詞' => 15,
    '薄:ナ形容詞' => 15,
    '注:ナ形容詞' => 15,
    '安:ナ形容詞' => 15,
    '焼:ナ形容詞' => 15,
    '栞:ナ形容詞' => 15,
    '以:子音動詞タ行' => 20,
    '何:子音動詞サ行' => 20,

    'けて:普通名詞' => 50,
    'じる:普通名詞' => 50,
    'たあ:普通名詞' => 50,
    'たぁ:普通名詞' => 50,
    'だあ:普通名詞' => 50,
    'だぁ:普通名詞' => 50,
    'だべ:普通名詞' => 50,
    'にゃ:普通名詞' => 50,
    'のち:ナ形容詞' => 50,
    'べる:普通名詞' => 50,
    'ぽい:普通名詞' => 50,
    'よん:普通名詞' => 50,
    'りる:普通名詞' => 50,
    'るる:普通名詞' => 50,
    '其の:普通名詞' => 50,
    '何ん:普通名詞' => 50,
    'しょー:普通名詞' => 55,
    'とゆー:普通名詞' => 55,

    'ぢゃな:イ形容詞アウオ段' => 55,
    'まっ:子音動詞サ行' => 55,
    'よっ:子音動詞サ行' => 55,
    'なさいま:子音動詞サ行' => 55,
    'じゃ:子音動詞ラ行' => 54,
    'ちょ:子音動詞ラ行' => 54,

    'まちる:普通名詞' => 56,
    'まちる:ナノ形容詞' => 56,
    'まち:母音動詞' => 54,

    'おっか:普通名詞' => 54,
    'おっか:サ変名詞' => 54,
    'おっか:ナ形容詞' => 54,

    'アレ:母音動詞' => 54,
    'アレだ:普通名詞' => 55,
    'アレです:普通名詞' => 56,

    'イイの:普通名詞' => 56,
    'イイです:普通名詞' => 56,
    'イイ女:普通名詞' => 56,
    'イイ感じ:普通名詞' => 56,
    'イイ感じ:ナ形容詞' => 56,

    'おもし:子音動詞ラ行' => 52, # おもしる:ラ行
    '多か:子音動詞ラ行' => 52, # おもしる:ラ行
    'おっ:子音動詞サ行' => 53,
    'まー:子音動詞サ行' => 53,

    'おっさ:子音動詞マ行' => 55,

    'あり:母音動詞' => 54,
    'ごめ:母音動詞' => 54,
    'つい:母音動詞' => 54,
    'なり:母音動詞' => 60,
    'けて:母音動詞' => 54,
    'けてい:母音動詞' => 54,
    'なんて:母音動詞' => 61,
    'まり:母音動詞' => 60,
    'められ:母音動詞' => 60,
    'わひ:母音動詞' => 60,
    '思ひ:母音動詞' => 300,
    'よーく見:母音動詞' => 54,

    'くだ:イ形容詞アウオ段' => 54,
    'おー:イ形容詞アウオ段' => 54,
    'ごー:イ形容詞アウオ段' => 54,

    'オモロ:ナ形容詞'=> 60,

    'さい:子音動詞タ行' => 60,
    'そーい:子音動詞ワ行' => 60,
    'そーいう:普通名詞' => 60,
    'どー:子音動詞サ行' => 60,

    'ぽなくな:子音動詞ラ行' => 60,

    '広報:子音動詞カ行' => 60,

    'どうなります:普通名詞' => 60,
    '思す:普通名詞' => 60,

    '２にゃあ:普通名詞' => 60,
    'レス後Ｑ:サ変名詞' => 60,
    '確り:サ変名詞' => 60,
    '受け止めな:子音動詞サ行' => 60,

    'と思:子音動詞サ行' => 60,
    'から気にな:子音動詞ラ行' => 104,

    '為に:普通名詞' => 300,
    '為にな:子音動詞ラ行' => 300,

    # verb phrases
    '妄想に耽:子音動詞ラ行' => 400,
    'カゴに入れ:母音動詞' => 400,
    '買い物カゴに入れ:母音動詞' => 400,
    'キレイになれ:母音動詞' => 400,
    '素直になれ:母音動詞' => 400,
    'よくしてくれ:母音動詞' => 54,
    '厚みがあ:子音動詞ラ行' => 54,
    '一緒にいた:イ形容詞アウオ段' => 61,
    '一緒にいたい:普通名詞' => 61,

    # noun phrases
    '色々あった女子アナの話題:普通名詞' => 450,
    '日米両国:普通名詞' => 450,

    # ruby
    '思おもいの自じ分ぶん:普通名詞' => 500,
    '本ほん体たいの自じ分ぶん:普通名詞' => 500,
    '極ごく楽らく世せ界かい:普通名詞' => 500,
    '過か去こ世せ:普通名詞' => 500,
    '番ばん組ぐみ:普通名詞' => 500,
    '低ひくい番ばん組ぐみ:普通名詞' => 500,
    '高たかい番ばん組ぐみ:普通名詞' => 500,
    '自じ力りき:普通名詞' => 500,

    # ruby or typo
    '使つか:子音動詞ワ行' => 600,
    '思おもう:子音動詞ワ行' => 600,
    '掴つかむ:子音動詞マ行' => 600,
    '与あたえ:母音動詞' => 600,
    '受うけ:母音動詞' => 600,
    '唱となえ:母音動詞' => 600,
};

my $stopwordsPrefix = {
    'あまり' => 10,
    'この世' => 11,

    '勉べん強きょう' => 20,
    '世せ界かい' => 20,
    '自じ分ぶん' => 20,
    '必ひつ要よう' => 20,
    '表ひょう現げん' => 20,
    '自し然ぜん' => 20,
    '祈いのり' => 20,
    'お祈いのり' => 20,
    '消け' => 20,

    'だっけ' => 30,
    'てゆー' => 30,
    'どぉ' => 30,
    'すげー' => 30,
};


############################################################
#                     main                                 #
############################################################

# 辞書を読み込み初期化
my $registered = {};
&loadDictionary($fileName, $registered);
&filterME($registered);

# 語幹の長さ毎に処理
my $mrphListByLength = [];
while ((my ($key, $entry) = each(%$registered))) {
    push (@{$mrphListByLength->[length ($entry->{stem})]}, $entry);
}

for (my $i = 1; $i < scalar(@$mrphListByLength); $i++) {
    foreach my $entry (@{$mrphListByLength->[$i]}) {
	my $stem = $entry->{stem};
	my $me = $entry->{me};

	# 2文字漢語は例外
	if ($i == 2 && $stem =~ /\p{Han}\p{Han}/
	    && (($entry->{posS} =~ /名詞/ || $entry->{posS} =~ /ナ(?:ノ)形容詞/))) {
	    $workingDictionary->addMorpheme($me);
	    next;
	}

	if ($i > 1) {
 	    my $mrph = $me->getJumanMorpheme;
 	    my $midasi = $mrph->midasi;
	    my $string = "「あ」$midasi";

	    if ($dictionaryManager->isDecomposable($entry, $string, 1)) {
		printf STDERR ("remove %s:%s\n", $stem, $entry->{posS}) if ($opt->{debug});
		next;
	    }
	} else {
	    # 1文字語幹の形態素への付け焼き刃
	    # 名詞と母音動詞
	    if ($entry->{posS} =~ /名詞/ || $entry->{posS} eq '母音動詞') {
		printf STDERR ("remove short nominal %s:%s\n", $stem, $entry->{posS}) if ($opt->{debug});
		next;
	    }
	}

	printf STDERR ("save %s:%s\n", $stem, $entry->{posS}) if ($opt->{debug});

	if ($entry->{posS} eq '母音動詞') {
	    my $rv = $variantChecker->checkKanouVerb($entry->{me});
	    if ($rv) {
		printf STDERR ("可能動詞 %s <- %s\n", $stem, $me->{'意味情報'}->{'可能動詞'}) if ($opt->{debug});
	    }
	}

	$workingDictionary->addMorpheme($me);
    }
    $workingDictionary->saveAsDictionary("$dictionaryDir/output.dic");
    $workingDictionary->update;
}

# 漢字のマージ 一応やる
my $mrphList = $workingDictionary->getAllMorphemes;
foreach my $me (@$mrphList) {
    $variantChecker->checkKanjiVariants($me);
}

$workingDictionary->saveAsDictionary("$dictionaryDir/output.dic");
$workingDictionary->update;


sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});

    Egnee::GlobalConf::set('juman.rcfile', $jumanrcFile);
    Egnee::GlobalConf::set('knp.options', '-tab -dpnd -check -timeout 600');
    Egnee::AnalyzerRegistryFactory::createAnalyzerRegistry();

    $workingDictionary = JumanDictionary->new($dictionaryDir,
					     { writable => 1, doLoad => 0 });
    $workingDictionary->saveAsDictionary("$dictionaryDir/output.dic");
    $workingDictionary->update;

    my $mainDicDirList = Egnee::GlobalConf::get('main-dictionary.db-path');
    my $mainDictionary = JumanDictionary::Mixed->new;
    foreach my $mainDicDir (@$mainDicDirList) {
	$mainDictionary->add(JumanDictionary::Static->new($mainDicDir));
    }

    use UnknownWordDetector;
    my $decompositionRuleFile = Egnee::GlobalConf::get('unknown-word-detector.decomposition-rule-file');
    my $repnameListFile = Egnee::GlobalConf::get('unknown-word-detector.repname-list');
    my $repnameNgramFile = Egnee::GlobalConf::get('unknown-word-detector.repname-ngram');
    my $repnameList = retrieve($repnameListFile) or die;
    my $repnameNgram = retrieve($repnameNgramFile) or die;
    my $unihan = retrieve(Egnee::GlobalConf::get('morpheme-variant-checker.unihan-db'));

    use SuffixList;
    my $suffixListDir = Egnee::GlobalConf::get('suffix-list.path');
    my $suffixList = SuffixList->new($suffixListDir);

    my $dictionaryManagerOpt = {
	suffixList => $suffixList,
	decompositionRuleFile => $decompositionRuleFile,
	unihan => $unihan,
	repnameList => $repnameList,
	repnameNgram => $repnameNgram,
	debug => $opt->{debug},
    };
    use DictionaryManager;
    $dictionaryManager = DictionaryManager->new($mainDictionary, $workingDictionary, $dictionaryManagerOpt);
    $variantChecker = $dictionaryManager->{variantChecker}; # hack

    use MorphemeUsageMonitor;
    use MultiClassClassifier;
    my $fusanaModel = retrieve(Egnee::GlobalConf::get('morpheme-usage-monitor.fusana-model')) or die;
    $usageMonitor = MorphemeUsageMonitor->new($dictionaryManager, $suffixList,
					      { fusanaModel => $fusanaModel, suffix => 1, update => 0, updateMidasi => 0, debug => 0 });
}

sub loadDictionary {
    my ($fileName, $registered) = @_;

    my $meList = JumanDictionary::MorphemeEntry::Annotated->readAnnotatedDictionary($fileName);
    foreach my $me (@$meList) {
	my $mrph = $me->getJumanMorpheme;

	my $midasiList = $me->{'見出し語'};
	if (scalar(keys(%$midasiList)) == 1) {
	    my $midasi = (keys(%$midasiList))[0];
	    if ($me->{'見出し語'}->{$midasi} == 1) {
		$me->{'見出し語'}->{$midasi} = 1.1;
	    }
	}

	my $annotation = $me->getAnnotationCollection;
	if ($opt->{clean} || defined($me->{'fusana'})) {
	    delete($me->{'意味情報'}->{'普サナ識別'});
	}

	my $stem = ($mrph->katuyou1 eq '*')? $mrph->genkei : (&MorphemeUtilities::decomposeKatuyou($mrph))[0];

	my $posS = &MorphemeGrammar::getPOSName($mrph, 1);
	if ($posS) { # 「連体詞」など未定義の場合がある
	    $me->setAnnotation('posS', $posS);
	} else {
	    $posS = 'RESERVED';
	}

	my $key = "$stem:$posS";
	print STDERR ("$stem $posS\n") if (!$stem or !$posS); # assert
	my $entry = {
	    me => $me,
	    # mrph => $mrph,
	    stem => $stem,
	    posS => $posS,
	};
	$registered->{$key} = $entry;
    }
}

sub filterME {
    my ($registered) = @_;

    my $checked = {}; # merge チェック済みのものを再びチェックしない

    # 怪しいものを取り除く
  outer:
    foreach my $key (keys(%$registered)) {
	next unless (defined($registered->{$key})); # 処理の途中で消される場合がある

	my $entry = $registered->{$key};

	# 語幹の最初の文字がおかしい
	if ($entry->{stem} =~ /^[ぁぃぅぇぉっゃゅょゎんァィゥェォッャュョヮ]/) { # ン??
	    printf STDERR ("# remove: %s:%s (bad head character)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
	    delete($registered->{$key});
	    next;
	}
	# やっつけで一文字のナ形容詞を排除
	my $posS = $entry->{posS};
	if ($posS =~ /ナ(?:ノ)形容詞/ && length ($entry->{stem}) == 1) {
	    printf STDERR ("# remove: %s:%s (short na-adjective)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
	    delete($registered->{$key});
	    next;
	}

	if ($posS eq '子音動詞ラ行') {
	    my $target = $entry->{stem} . ":母音動詞";
	    if (defined($registered->{$target})) {
		printf STDERR ("remove possible verb-r verb %s\n", $target) if ($opt->{debug});
		delete($registered->{$target});
		# 自分を消すのではないので next しない
	    }
	} elsif ($posS eq '子音動詞カ行') {
	    my $target = $entry->{stem} . "い:母音動詞";
	    if (defined($registered->{$target})) {
		printf STDERR ("remove possible verb-k verb %s\n", $target) if ($opt->{debug});
		delete($registered->{$target});
		# 自分を消すのではないので next しない
	    }
	}

	# やっつけで語尾までカタカナの用言を削除
	if ($posS eq '母音動詞' && $entry->{stem} =~ /^(\p{Katakana}|・|ー)+イ$/) {
	    printf STDERR ("# remove: %s:%s (possible katakana ending)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
	    delete($registered->{$key});
	    next;
	}

	# やっつけ 2
	if ($entry->{stem} =~ /^.[０-９]+$/) { # e.g. 注１
	    printf STDERR ("# remove: %s:%s (single char + number)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
	    delete($registered->{$key});
	    next;
	}

	# stopword
	if (defined($stopwords->{$key})) {
	    printf STDERR ("# remove: %s:%s (stopword)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
	    delete($registered->{$key});
	    next;
	}
	foreach my $stopword (keys(%$stopwordsPrefix)) {
	    if (index ($entry->{stem}, $stopword) == 0) {
		printf STDERR ("# remove: %s:%s (stopword prefix)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
		delete($registered->{$key});
		next outer;
	    }
	}

	# マージ処理
	if (!defined($checked->{$key}) && ($posS =~ /(?:名詞|副詞)/ || $posS =~ /ナノ?形容詞/)) {
	    my $posS2 = &checkNounMerging($entry, $registered, $checked);
	    next if ($posS2 && $posS2 ne $posS); # 自分が生き残った場合のみ続行
	}

	if ($opt->{clean}) {
	    # delete longer words
	    if (length($entry->{stem}) >= 10) {
		printf STDERR ("# remove: %s:%s (too long stem)\n", $entry->{stem}, $entry->{posS}) if ($opt->{debug});
		delete($registered->{$key});
		next;
	    }
	}

	if ($opt->{df_thres}) {
	    my $df = $entry->{me}->getAnnotation ('df') || 0;
	    if ($df < $opt->{df_thres}) {
		printf STDERR ("# remove: %s:%s (df count: %d)\n", $entry->{stem}, $entry->{posS}, $df) if ($opt->{debug});
		delete($registered->{$key});
		next;
	    }

	    if ($opt->{clean}) {
		# カタカナの場合は閾値を厳しくする
		if (($posS =~ /名詞/ || $posS =~ /ナ(?:ノ)形容詞/)
		    && $entry->{stem} =~ /^(\p{Katakana}|・|ー)+$/) {
		    if ($df < $opt->{df_thres} * $KATAKANA_THRES_RATE) {
			printf STDERR ("# remove: %s:%s (katakana df count: %d)\n", $entry->{stem}, $entry->{posS}, $df) if ($opt->{debug});
			delete($registered->{$key});
			next;
		    }
		}
	    }
	}

	if ($opt->{domainF_thres}) {
	    my $domainF = $entry->{me}->getAnnotation ('domainF') || 0;
	    if ($domainF < $opt->{domainF_thres}) {
		printf STDERR ("# remove: %s:%s (domain freq count: %d)\n", $entry->{stem}, $entry->{posS}, $domainF) if ($opt->{debug});
		delete($registered->{$key});
		next;
	    }

	    if ($opt->{clean}) {
		# カタカナの場合は閾値を厳しくする
		if (($posS =~ /名詞/ || $posS =~ /ナ(?:ノ)形容詞/)
		    && $entry->{stem} =~ /^(\p{Katakana}|・|ー)+$/) {
		    if ($domainF < $opt->{domainF_thres} * $KATAKANA_THRES_RATE) {
			printf STDERR ("# remove: %s:%s (katakana df count: %d)\n", $entry->{stem}, $entry->{posS}, $domainF) if ($opt->{debug});
			delete($registered->{$key});
			next;
		    }
		}
	    }
	}


	if ($opt->{count_thres}) {
	    my $domainF = $entry->{me}->getAnnotation ('count') || 0;
	    if ($domainF < $opt->{count_thres}) {
		printf STDERR ("# remove: %s:%s (domain freq count: %d)\n", $entry->{stem}, $entry->{posS}, $domainF) if ($opt->{debug});
		delete($registered->{$key});
		next;
	    }

	    if ($opt->{clean}) {
		# カタカナの場合は閾値を厳しくする
		if (($posS =~ /名詞/ || $posS =~ /ナ(?:ノ)形容詞/)
		    && $entry->{stem} =~ /^(\p{Katakana}|・|ー)+$/) {
		    if ($domainF < $opt->{domainF_thres} * $KATAKANA_THRES_RATE) {
			printf STDERR ("# remove: %s:%s (katakana df count: %d)\n", $entry->{stem}, $entry->{posS}, $domainF) if ($opt->{debug});
			delete($registered->{$key});
			next;
		    }
		}
	    }
	}
    }
}

# 名詞とナ形容詞の重複を多数決で解消
#
# TODO:
#   名詞と母音動詞の衝突
sub checkNounMerging {
    my ($entry, $registered, $checked) = @_;

    my $stem = $entry->{stem};
    my $posS = $entry->{posS};
    my @list = ('普通名詞', 'サ変名詞', 'ナ形容詞', 'ナノ形容詞');

    if ($stem !~ /\p{Hiragana}$/ && defined(my $entry2 = $registered->{"$stem:母音動詞"})) {
	printf STDERR ("conflict vowel verb: %s: %s <- 母音動詞\n", $stem, $posS) if ($opt->{debug});
	delete($registered->{"$stem:母音動詞"});
    }

    # merged stats
    my ($count, $df, $domainF) = (0, 0, 0);

    my $fusanaFlag = ($entry->{me}->{'意味情報'}->{$IMIS->{FUSANA}})? 1 : 0;

    my $cands = {};
    my $suffixList = {};
    my $suffixCount = 0;
    foreach my $posS2 (@list) {
	next unless  (defined(my $entry2 = $registered->{"$stem:$posS2"}));

	$fusanaFlag = 1 if ($entry2->{me}->{'意味情報'}->{$IMIS->{FUSANA}});

	if ($posS2 ne $posS) {
	    printf STDERR ("conflict %s: %s <- %s\n", $stem, $posS, $posS2) if ($opt->{debug});
	    $checked->{"$stem:$posS2"}++;
	}

	my $score = 0;
	my $fusanaM = $entry2->{me}->getAnnotation('fusana');
	if (defined($fusanaM)) {
	    $score += $fusanaM->{(keys(%$fusanaM))[0]} * 500;
	}
	$cands->{$posS2} = {
	    entry => $entry2,
	    score => $score,
	};

	$count += $entry2->{me}->getAnnotation('count') || 0;
	$df += $entry2->{me}->getAnnotation('df') || 0;
	$domainF += $entry2->{me}->getAnnotation('domainF') || 0;

	my $monitor = $entry2->{me}->getAnnotation('monitor');
	if (defined ($monitor)) {
	    if (defined($monitor->{suffix})) {
		$suffixCount += $monitor->{suffixCount} || 0;
		foreach my $suffix (keys(%{$monitor->{suffix}})) {
		    $suffixList->{$suffix} += $monitor->{suffix}->{$suffix};
		}
		$entry2->{me}->deleteAnnotation('monitor');
	    }
	}
    }
    return if (scalar(keys(%$cands)) <= 1
	       && $suffixCount < 100);

    if ($fusanaFlag) {
	if ($suffixCount >= 100) {
	    my $clone = &cloneME($entry->{me});
	    $clone->setAnnotation('monitor', { suffix => $suffixList, suffixCount => $suffixCount });
	    $usageMonitor->updateFusana($clone, { update => 0 });
	    my $cmrph = $clone->getJumanMorpheme;
	    my $posSclone = &MorphemeGrammar::getPOSName($cmrph, 1);
	    if (defined($cands->{$posSclone})) {
		$cands->{$posSclone}->{score} += $suffixCount;
	    } else {
		my $stem = ($cmrph->katuyou1 eq '*')? $cmrph->genkei : (&MorphemeUtilities::decomposeKatuyou($cmrph))[0];
		$cands->{$posSclone} = {
		    entry => {
			me => $clone,
			stem => $stem,
			posS => $posSclone,
		    },
		    score => $suffixCount,
		};
		$checked->{"$stem:$posSclone"}++;
		$registered->{"$stem:$posSclone"} = $cands->{$posSclone}->{entry};
	    }
	}
    }
    my $maxPosS;
    my $maxV = -1;
    foreach my $posS (keys(%$cands)) {
	if ($cands->{$posS}->{score} > $maxV) {
	    $maxPosS = $posS;
	    $maxV = $cands->{$posS}->{score};
	}
    }
    foreach my $posS (keys(%$cands)) {
	next if ($posS eq $maxPosS);
	    
	my $posS2 = $cands->{$posS}->{entry}->{posS};
	printf STDERR ("merge %s:%s into %s:%s\n", $stem, $posS2, $stem, $maxPosS) if ($opt->{debug});	
	delete($registered->{"$stem:$posS2"});
    }

    my $maxME = $cands->{$maxPosS}->{entry}->{me};
    $maxME->setAnnotation('count', $count);
    $maxME->setAnnotation('df', $df);
    $maxME->setAnnotation('domainF', $domainF);

    # 副詞
    if (defined($registered->{"$stem:副詞"})) {
	my $entry2 = $registered->{"$stem:副詞"};
	my $count2 = $entry2->{me}->getAnnotation('count') || 0;
	if ($count < $count2) {
	    printf STDERR ("merge %s:%s into 副詞\n", $stem, $maxPosS) if ($opt->{debug});
	    delete($registered->{"$stem:$maxPosS"});
	    return "副詞";
	}
    }
    return $maxPosS;
}

sub cloneME {
    my ($me) = @_;

    use SExpression;
    my $ds = SExpression->new({ use_symbol_class => 1, fold_lists => 0 });
    my $se = $ds->read($me->JumanDictionary::MorphemeEntry::serialize);
    return (JumanDictionary::MorphemeEntry::Annotated->createFromSExpression($se))->[0];
}

1;
