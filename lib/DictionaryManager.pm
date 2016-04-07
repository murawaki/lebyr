package DictionaryManager;
#
# managing set of main and working dictionaries for unknown morpheme acquisition
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;
use JumanDictionary::MorphemeEntry::Annotated;
use JumanDictionary::MorphemeVariantChecker;
use MorphemeGrammar qw/$posList $IMIS/;
use MorphemeUtilities;
use Sentence;
use UnknownWordDetector;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	mainDictionary => shift,
	workingDictionary => shift,
	opt => shift,
    };
    $self->{opt}->{safeMode} = 0 unless (defined($self->{opt}->{safeMode}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    $self->{variantChecker} = JumanDictionary::MorphemeVariantChecker->new
	($self->{mainDictionary}, $self->{workingDictionary}, $self->{opt}->{unihan});

    # option for decomposing long morpheme candidates
    if ($self->{opt}->{decompositionRuleFile}) {
	my $detectorOpt = {
	    filterNoise => 0, # disable noise filtering
	    detectZero => 0,  # zero counts do not mean presence of an unknown morpheme
	    debug => $self->{opt}->{debug},
	};
	if ($self->{opt}->{repnameList}) {
	    $detectorOpt->{updateNgram} = 0;
	    $detectorOpt->{debugSmoothing} = 0;
	    $self->{detector} = UnknownWordDetector->new
		($self->{opt}->{decompositionRuleFile},
		 $self->{opt}->{repnameList}, $self->{opt}->{repnameNgram}, $detectorOpt);
	} else {
	    $detectorOpt->{enableNgram} = 0;
	    $self->{detector} = UnknownWordDetector->new
		($self->{opt}->{decompositionRuleFile},
		 undef, undef, $detectorOpt);
	}
	$self->{detector}->setEnumerator($self);
    }
    return $self;
}

sub DESTROY {
    my ($self) = @_;

    if ($self->{opt}->{decompositionFile}) {
	delete($self->{detector});
    }
}
=head2 setCallback ($code)

未定義語が検出されるごとに呼び出すサブルーチンを指定する。
現在のところ、一つしか指定できない。

引数

    $code: サブルーチン

=cut
sub setCallback {
    my ($self, $code) = @_;

    $self->{callback} = $code;
}

sub evokeCallback {
    my ($self, $struct) = @_;

    if (defined($self->{callback})) {
	&{$self->{callback}}($struct);
    }
}

sub setSafeMode {
    my ($self, $val) = @_;
    $self->{opt}->{safeMode} = (defined($val))? $val : 1;
}

sub registerEntry {
    my ($self, $entry, $accumulator, $exampleList) = @_;

    $entry->{me} = &JumanDictionary::MorphemeEntry::Annotated::makeAnnotatedMorphemeEntryFromStruct($entry);

    # JumanDictionary::MorphemeEntry の作成に失敗
    unless ($entry->{me}) {
	Egnee::Logger::warn(sprintf("failed to create MorphemeEntry: %s\n", $entry->{stem}));

	$accumulator->deleteExampleSelectorList($exampleList, $entry);
	return undef;
    }
    $entry->{me}->setAnnotation('count', $entry->{count});
    $entry->{me}->setAnnotation('countStart', $entry->{countStart});

    # 登録はしないかチェック
    my $rejected = 0;
    if ($self->isEntryRegistered($entry)) {
	# 登録済みの場合
	Egnee::Logger::warn(sprintf("%s is already registered\n", $entry->{stem}));
	$rejected = 1;
    } elsif ($self->{opt}->{suffixList} && $self->isFunctionWord($entry)) {
	# 付属語の可能性がある場合
	Egnee::Logger::warn(sprintf("%s may be a function word\n", $entry->{stem}));
	$rejected = 1;
    } elsif ($self->isBadWord($entry)) {
	# safeMode でなくても登録したくない形態素
	Egnee::Logger::warn(sprintf("%s is a malformed word\n", $entry->{stem}));
	$rejected = 1;
    } elsif ($self->{opt}->{safeMode} && $self->isUnsafeWord($entry)) {
	# safeMode のとき
	Egnee::Logger::warn(sprintf ("%s is an unsafe word\n", $entry->{stem}));
	$rejected = 1;
    }
    if ($rejected) {
	# 登録しなくても用例は消す
	$accumulator->deleteExampleSelectorList($exampleList, $entry);
	return undef;
    }

    my $workingDictionary = $self->{workingDictionary};
    if ($entry->{me}) {
	if ($entry->{posS} eq '母音動詞') {
	    $self->{variantChecker}->checkKanouVerb($entry->{me});
	}
	if ($self->{opt}->{unihan}) {
	    $self->{variantChecker}->checkKanjiVariants($entry->{me});
	}

	# 辞書の更新をさぼる
	$workingDictionary->appendSave($entry->{me});
	$workingDictionary->update;
    }
    $accumulator->deleteExampleSelectorList($exampleList, $entry);

    # 用例数のカウントのために Accumulator の掃除をしてから呼び出す
    if ($entry->{me}) {
	$self->evokeCallback({ type => 'append', obj => $entry->{me} });
    }
    # TODO
    # pivot を部分文字列として含む pivot の用例の解釈可能性のチェック

    # 登録済みの語が長過ぎる可能性
    $self->checkLongerEntries($entry);
}

sub isEntryRegistered {
    my ($self, $entry) = @_;

    my $me = $entry->{me};
    my $midasi = (keys(%{$me->{'見出し語'}}))[0];
    my $posS = $entry->{posS};

    my $constraints;
    if (defined($posList->{$posS}->{meMatchConstraints})) {
	$constraints = $posList->{$posS}->{meMatchConstraints};
    } else {
	# 制限は hinsi だけで登録済みか調べる
	$constraints = { '品詞' => (keys(%{$posList->{$posS}->{constraints}->{hinsi}}))[0] };
    }


    my $voc = $self->{mainDictionary}->getMorpheme($midasi, $constraints);
    if (defined($voc)) {
	Egnee::Logger::warn("already registered (main): $midasi\n");

	return 1;
    }
    my $voc2 = $self->{workingDictionary}->getMorpheme($midasi, $constraints);
    if (defined($voc2)) {
	Egnee::Logger::warn("already registered (working): $midasi\n");

	return 1;
    }
    return 0;
}

# suffix と被っていれば付属語っぽいので怪しいというルール
# 多分見直しが必要
sub isFunctionWord {
    my ($self, $entry) = @_;

    my $me = $entry->{me};
    my $midasi = (keys(%{$me->{'見出し語'}}))[0];
    my $posS = $entry->{posS};

    my $l = length($midasi);
    return 0 if ($l > 5);

    my $suffixList = $self->{opt}->{suffixList};
    my $idList = $suffixList->commonPrefixSearchID($midasi);
    return 0 if (scalar(@$idList) <= 0);

    my $id = $idList->[-1];
    my $suffixLength = $suffixList->getSuffixLengthByID($id);
    return ($l == $suffixLength)? 1 : 0;
}

our $nounLikePos = {
    '普通名詞' => 1,
    'サ変名詞' => 2,
    'ナ形容詞' => 3
};

sub isBadWord {
    my ($self, $entry) = @_;

    my $stem = $entry->{stem};
    my $posS = $entry->{posS};

    # 怪しい語幹を付け焼き刃で登録
    return 1 if ($stem =~ /^[っゃゅょぁぃぅぇぉッァィゥェォャュョー〜：・＃○◎●]/); # 先頭
    return 1 if ($stem =~ /[：・]$/); # 後尾

    # 1文字だと意味がない
    return 1 if ($posS =~ /名詞$/ && length($stem) == 1);

    if (defined($nounLikePos->{$posS})) {
	# ひらがな1文字 + 「ー」は大抵非規範的な表記
	return 1 if ($stem =~ /^\p{Hiragana}ー$/);

	# 名詞系で語幹が「っ」で終るのは感動詞などのゴミ
	return 1 if ($stem =~ /っ$/);
    }
    return 0;
}

# safeMode の時に reject するかをチェック
sub isUnsafeWord {
    my ($self, $entry) = @_;

    my $stem = $entry->{stem};
    my $posS = $entry->{posS};

    return 0 unless (defined($nounLikePos->{$posS}));

    # 二文字以下のカタカナ語は怪しい
    return 1 if (length($stem) <= 2 && $stem =~ /^(?:\p{Katakana}|ー)+$/);

    # # カタカナに文字ではじまる or おわる場合を除去
    # # 獲得できなくなる例: スク水、ドラえもん、シャ乱Ｑ
    # if ($posS =~ /(?:名詞|副詞|ナノ?形容詞)/
    # 	&&($stem =~ /^((?:\p{Katakana}|ー)+)/ || $stem =~ /^((?:\p{Katakana}|ー)+)$/)
    # 	&& length($1) <= 2) {
    # 	return 1;
    # }
    return 0;
}

# 文字列が $entry で解釈可能か調べる
sub isDecomposable {
    my ($self, $entry, $string, $checkLevel) = @_;
    $checkLevel = 0 unless (defined($checkLevel));

    my $targetMrph;
    if (defined($entry->{mrph})) {
	$targetMrph = $entry->{mrph};
    } else {
	if (defined($entry->{me})) {
	    $targetMrph = $entry->{mrph} = $entry->{me}->getJumanMorpheme;
	} else {
	    # JumanDictionary::MorphemeEntry の作成に失敗している
	    # 語幹の文字列が不正な場合など
	    return 0;
	}
    }
    my $sentence = Sentence->new({ 'raw' => $string });

    if ($self->{detector}) {
	return $self->isDecomposableByDetector($sentence, $entry, $targetMrph, $checkLevel);
    } else {
	return $self->isDecomposableByRule($sentence, $entry, $targetMrph, $checkLevel);
    }
}

# UnknownWordDetector を使って分割可能性を判定
sub isDecomposableByDetector {
    my ($self, $sentence, $entry, $targetMrph, $checkLevel) = @_;

    # 検出されたら未知語
    my $event = $self->{detectionEvent} = {
	flag => 0,
    };
    $self->{detector}->onSentenceAvailable($sentence);
    delete($self->{detectionEvent});

    # 正の値なら未知語らしい (分割決定を含んでいれば負の値)
    if ($event->{flag} > 0) {

 	# 既知語が前に来る場合のみ許可するオプション
 	# 文章ではなく単語の分割可能性を調べる時に使用
	if ($checkLevel >= 1) {
	    my $result = $sentence->get('knp');
	    # 検出箇所より後ろに自動獲得の語を含んでいたら分割可能とみなす
	    # 前から順番にみて検出していることに依存しているチェック
	    my @mrphList = $result->mrph;
	    my $shift = ($event->{feature} =~ /^FBI\_/)? 2 : 1; # FBI_* features depende on the next mrph
	    for (my $i = $event->{pos} + $shift, my $limit = scalar(@mrphList); $i < $limit; $i++) {
		my $mrph = $mrphList[$i];
		if ($mrph->imis =~ /自動獲得\:テキスト/
		    && $mrph->genkei eq $targetMrph->genkei
		    && $mrph->hinsi eq $targetMrph->hinsi) {
		    $event->{flag} = 0;
		    $entry->{count}++;

		    Egnee::Logger::info(sprintf("example removed (decomposed by acquired morpheme): %s <- %s\n",
						$sentence->get('raw'), $mrph->genkei));
		}
	    }
	}
	if ($event->{flag} > 0) {
	    Egnee::Logger::info(sprintf("example kept (not decomposed by acquired morpheme): %s\n",
					$sentence->get('raw')));
	    return 0;
	} else {
	    return 1;
	}
    } else {
	Egnee::Logger::info(sprintf("example removed (分割決定): %s\n", $sentence->get('raw')));
	return 1;
    }
}

# UnknownWordDetector から呼び出される
# makeExample という名前は CandidateEnumerator にあわせたもの
sub makeExample {
    my ($self, $knpResult, $exampleCand) = @_;

    $self->{detectionEvent}->{pos} = $exampleCand->{pos};
    $self->{detectionEvent}->{feature} = $exampleCand->{feature};
    if ($exampleCand->{feature} eq '分割決定') {
	Egnee::Logger::info(sprintf("分割決定\t%s\n", join('', map { $_ -> midasi} ($knpResult->mrph))));
	$self->{detectionEvent}->{flag} = -1024;
    } else {
	# 未知語らしきものを検出したので、分割するとまずそう
	$self->{detectionEvent}->{flag}++;
    }
}

# 従来通りのルールを使って分割可能性を判定
sub isDecomposableByRule {
    my ($self, $sentence, $entry, $targetMrph, $checkLevel) = @_;

    # 単純に解析結果上の出現だけを調べる
    # 再検討が必要
    my $result = $sentence->get('knp');
    my @mrphList = $result->mrph;
    my $rv = 0;
    for (my $i = 0; $i < scalar(@mrphList); $i++) {
	my $mrph = $mrphList[$i];

 	# 既知語が前に来る場合のみ許可するオプション
 	# 文章ではなく単語の分割可能性を調べる時に使用
 	if ($checkLevel >= 1) {
	    if (&MorphemeUtilities::isUndefined($mrph)) {
		$rv = 0;
		last;
	    }
	}

 	# 同一性確認 不十分?
	if ($mrph->imis =~ /自動獲得\:テキスト/ &&
	    $mrph->genkei eq $targetMrph->genkei &&
	    $mrph->hinsi eq $targetMrph->hinsi) {

	    Egnee::Logger::info(sprintf("filtered out: %s\n", $sentence->get('raw')));

	    $entry->{count}++;
	    $rv = 1;
	}
	my $mrphPrev;
	if ($i > 0 && ($mrphPrev = $mrphList[$i - 1])
	    && $mrphPrev->katuyou2 ne 'タ系連用テ形'
	    && $mrph->bunrui eq '動詞性接尾辞'
	    && $mrph->genkei eq 'る') {
	    $rv = 0;
	    last;
	}
	if ($mrph->bunrui eq '形容詞性名詞接尾辞'
	    && $mrph->genkei eq 'い') {
	    $rv = 0;
	    last;
	}
    }
    return $rv;
}

# 登録済みの語が長過ぎる可能性をチェック
# 以前は並列処理だったので、trie に格納したリストをみていたが、
# 今は辞書を調べる。
sub checkLongerEntries {
    my ($self, $entry) = @_;

    my $stem = $entry->{stem};
    my $me = $entry->{me};

    # まず部分文字列関係にある形態素を列挙
    my $deletionCands = {};
    my $workingDictionary = $self->{workingDictionary};
    my $mrphList = $workingDictionary->getAllMorphemes;
    foreach my $me2 (@$mrphList) {
	next if ($me == $me2); # reference でチェック

	my $mrph2 = $me2->getJumanMorpheme;
	my ($stem2, $gobi2) = &MorphemeUtilities::decomposeKatuyou($mrph2);
 	if (index($stem2, $stem) >= 0) {
	    Egnee::Logger::info(sprintf("\tdelete? %s << %s\n", $stem2, $stem));

	    $deletionCands->{$me2} = [$me2, $mrph2, $stem2]; # reference でハッシュ
	}
    }
    return unless (scalar(keys(%$deletionCands)) > 0);

    # deletionCands を省いた状態で辞書登録し、目的の語で解釈されるか調べる
    # とりあえず clear して deletionCands 以外を登録する
    # 数が増えてきたら効率が悪そう
    $workingDictionary->clear;
    foreach my $me2 (@$mrphList) {
	unless (defined($deletionCands->{$me2})) {
	    $workingDictionary->addMorpheme($me2);
	}
    }
    $workingDictionary->saveAsDictionary;
    $workingDictionary->update;

    my $eventQueue = [];

    my $deletionList = {};
    foreach my $addr (keys(%$deletionCands)) {
	my ($me2, $mrph2, $stem2) = @{$deletionCands->{$addr}};

	# 閉じ括弧で付属語始まりを許容
	if ($self->isDecomposable($entry, "「あ」" . $stem2, 1)) {
	    Egnee::Logger::info(sprintf("\tdelete longer entry!!! %s << %s\n", $stem2, $stem));

	    push(@$eventQueue, $me2);
	    $deletionList->{$me2} = 1;

	    my $merged = $me->getAnnotation('merged');
	    unless (defined ($merged)) {
		my $merged = {};
		$me->setAnnotation('merged', $merged);
	    }
	    $merged->{$stem2} += $me2->getAnnotation('count');
	}
    }

    $workingDictionary->clear;
    foreach my $me2 (@$mrphList) {
	unless (defined($deletionList->{$me2})) {
	    $workingDictionary->addMorpheme($me2);
	}
    }
    $workingDictionary->saveAsDictionary;
    $workingDictionary->update;

    # 用例数のカウントのために Accumulator の掃除をしてから呼び出す
    foreach my $me2 (@$eventQueue) {
	$self->evokeCallback({ type => 'decompose', obj => $me2, deletionBy => $me });
    }
}

sub updateFusana {
    my ($self, $me, $id, $opt) = @_;
    # $opt:
    #   update: 辞書を更新
    #   updateMidasi: 見出しの変更を $workingDictionary に反映させる

    my $info = $me->updateFusana($id);
    Egnee::Logger::info(sprintf("##### %s FUSANA decided: %s #####\n", (keys(%{$me->{'見出し語'}}))[0], $info->{pos}));
    if ($info->{midasiChange} && $opt->{updateMidasi}) {
	$self->{workingDictionary}->updateMidasi($me, $info->{midasiChange});
    }
    if ($opt->{update}) {
	$self->{workingDictionary}->saveAsDictionary;
	$self->{workingDictionary}->update;
    }

    $self->evokeCallback({ type => 'pos-change', obj => $me, to => $info->{pos} });
    return $me;
}

1;
