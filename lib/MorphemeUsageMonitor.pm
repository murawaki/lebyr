package MorphemeUsageMonitor;
#
# monitor usages of acquired morphemes
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;
use SuffixExtractor;
use MorphemeGrammar qw/$posList $IMIS/;
use MorphemeUtilities;

our $SUFFIX_MAX_LENGTH = 4; # TODO: move this const. to SuffixList
our $monitorMax = 500;
our $monitorMin = 100;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $obj = shift;
    my $self = {
	suffixList => shift,
	opt => shift,
    };
    if ($obj->isa('DictionaryManager')) {
	$self->{dictionaryManager} = $obj;
	$self->{workingDictionary} = $obj->{workingDictionary};
    } else {
	$self->{workingDictionary} = $obj;
    }
    bless($self, $class);
    $self->{se} = SuffixExtractor->new({ markAcquired => 0, excludeDoukei => 0 });

    # default opt values
    $self->{opt}->{counter} = 1 unless (defined($self->{opt}->{counter}));
    $self->{opt}->{targetIMIS} = '自動獲得:テキスト' unless (defined($self->{opt}->{targetIMIS}));
    $self->{opt}->{suffix} = 0 unless (defined($self->{opt}->{suffix}));
    $self->{opt}->{monitorMax} = $monitorMax unless (defined($self->{opt}->{monitorMax}));
    $self->{opt}->{monitorMin} = $monitorMin unless (defined($self->{opt}->{monitorMin}));
    $self->{opt}->{update} = 1 unless (defined($self->{opt}->{update}));
    $self->{opt}->{updateMidasi} = 1 unless (defined($self->{opt}->{updateMidasi}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    # fusanaModel: MultiClassClassifier

    Egnee::Logger::setLogger($self->{opt}->{debug});
    $self->resetCount if ($self->{opt}->{reset});
    return $self;
}

sub resetCount {
    my ($self) = @_;

    if ($self->{opt}->{counter}) {
	foreach my $me (@{$self->{workingDictionary}->getAllMorphemes}) {
	    $me->deleteAnnotation('count');
	}
    }
    if ($self->{opt}->{suffix}) {
	foreach my $me (@{$self->{workingDictionary}->getAllMorphemes}) {
	    $me->deleteAnnotation('monitor');
	}
    }
}

# sub onDocumentChange {
#     my ($self, $document) = @_;
# }

sub onSentenceAvailable {
    my ($self, $sentence) = @_;

    my $knpResult = $sentence->get('knp');
    return unless (defined($knpResult));
    $self->processKNPResult($knpResult);
}

sub processKNPResult {
    my ($self, $knpResult) = @_;

    my @bnstList = $knpResult->bnst;
    for (my $i = 0; $i < scalar(@bnstList); $i++) {
	my $bnst = $bnstList[$i];
	my $bnstN = $bnstList[$i + 1];
	my @mrphList = $bnst->mrph;
	for (my $j = 0; $j < scalar(@mrphList); $j++) {
	    my $mrph = $mrphList[$j];
	    my $doCount = (index($mrph->imis, $self->{opt}->{targetIMIS}) >= 0);
	    my $doSuf = ($self->{opt}->{suffix} && index($mrph->imis, $IMIS->{FUSANA}) >= 0);
	    next unless ($doCount || $doSuf);

	    my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph);
	    my ($me, $posS) = $self->getMorphemeEntry($mrphO);
	    next unless (defined($me));

	    if ($doCount) {
		$me->getAnnotationCollection->{count}++;
	    }
	    # 普通名詞、サ変名詞、ナ形容詞識別のための追跡調査
	    if ($doSuf) {
		$self->checkSuffix($me, $posS, $bnst, $bnstN, \@mrphList, $i, $j);
	    }
	}
    }
}

sub onFinished {
    my ($self) = @_;

    my $workingDictionary = $self->{workingDictionary};
    my $mrphList = $workingDictionary->getAllMorphemes;
    foreach my $me (@$mrphList) {
	next unless (defined($me->{'意味情報'}->{$IMIS->{FUSANA}}));
	my $usage = $me->getAnnotation('monitor');
	if (($usage->{suffixCount} || 0) >= $self->{opt}->{monitorMin}) {
	    $self->updateFusana($me, { update => 0, updateMidasi => $self->{opt}->{updateMidasi} });
	}
    }
}

sub getMorphemeEntry {
    my ($self, $mrphO) = @_;

    my $posS = &MorphemeGrammar::getPOSName($mrphO);
    my $workingDictionary = $self->{workingDictionary};
    # 制限は hinsi だけで登録済みか調べる
    my $voc = $workingDictionary->getMorpheme($mrphO->genkei, { '品詞' => (keys (%{$posList->{$posS}->{constraints}->{hinsi}}))[0] } );
    my $me;
    unless (defined($voc) && scalar(@$voc) == 1 && ($me = $voc->[0]) ) {
	Egnee::Logger::warn(sprintf("mrph not found in working dictionary: %s\n", $mrphO->genkei));
	return undef;
    }
    return ($me, $posS);
}

# 普通名詞、サ変名詞、ナ形容詞の識別のために獲得後もサフィックスを調べる
# 注意: ここで抽出されるサフィックスは、本当のサフィックスではない疑似サフィックスが含まれる
#       SuffixList に含まれることによって本物のサフィックスと認定される
sub checkSuffix {
    my ($self, $me, $posS, $bnst, $bnstN, $mrphList, $i, $j) = @_;

    my $mrph = $mrphList->[$j];
    my ($mrphS, $startPoint, $opOpt) = $self->{se}->getTargetMrph($bnst);
    return unless (defined($mrphS));
    if ($startPoint == $j) {
	# 複合名詞の最右
	my $struct = $self->{se}->extractSuffix($mrphS, $startPoint, $bnst, $bnstN, $opOpt);

	return unless (defined($struct));
	$self->updateSuffixAnnotation($mrph, $me, $struct);
    } elsif ($startPoint > $j) { # このチェックはあまり意味がない assert
	# ひらがな地獄: e.g. ツンデレすぎだ
	# ナ形容詞を普通名詞扱いした場合、
	# 付属語を誤解析する場合があるので
	# 文節内のひらがな要素を調べる; 文節境界を引かれた場合に機能しない。
	# $j を開始位置にして強制的にサフィックスを作る
	my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph);
	my $struct = $self->{se}->extractSuffix($mrphO, $j, $bnst, $bnstN, $opOpt);

	return unless (defined($struct));
	my $suffix = $struct->{suffix};
	return unless ($suffix =~ /^\p{Hiragana}$/);

	Egnee::Logger::info("pseudo suffix extracted: $suffix\n");
	$self->updateSuffixAnnotation($mrph, $me, { suffix => $suffix, posS => $posS });
    } else {
	Egnee::Logger::warn("something wrong happens in suffix extraction\n");
    }
}

# 辞書情報の annotation を更新
sub updateSuffixAnnotation {
    my ($self, $mrph, $me, $suffixStruct) = @_;

    Egnee::Logger::info("##### detect morpheme #####\n");
    Egnee::Logger::info(sprintf("%s%s\n\n", $mrph->spec, $suffixStruct->{suffix}));

    # 継続監視タグの drop が反映されていない場合を考慮
    return unless (defined($me->{'意味情報'}->{$IMIS->{FUSANA}}));

    my $posS = $suffixStruct->{posS};
    my $suffix = $suffixStruct->{suffix};
    $suffix = substr($suffix, 0, $SUFFIX_MAX_LENGTH) if (length($suffix) > $SUFFIX_MAX_LENGTH);
    my $suffixList = $self->{suffixList};
    my $idList = $suffixList->commonPrefixSearchID($suffix);
    # 同一性確認
    return if (scalar(@$idList) <= 0);
    my $id = $idList->[-1];
    return unless (length($suffix) == $suffixList->getSuffixLengthByID($id));

    my $usage = $me->getAnnotation('monitor', {});
    $usage->{suffixCount}++;
    $usage->{suffix}->{$suffix}++;

    if ($usage->{suffixCount} >= $self->{opt}->{monitorMax}) {
	$self->updateFusana($me, { update => $self->{opt}->{update}, updateMidasi => $self->{opt}->{updateMidasi} });
    }
}

sub updateFusana {
    my ($self, $me, $opt)= @_;
    # $opt:
    #   update: exec dictionary update

    my $suffixList = $self->{suffixList};
    my $usage = $me->getAnnotation('monitor');
    my $list = $usage->{suffix};
    my $sum = $usage->{suffixCount};
    my $featureList = [];
    foreach my $suffix (keys(%$list)) {
	my $fid = $suffixList->getIDBySuffix($suffix);
	next unless (defined($fid));
	push(@$featureList, [$fid, $list->{$suffix} / $sum]);
    }
    my $id = $self->{opt}->{fusanaModel}->classifyMax({ featureList => $featureList });

    Egnee::Logger::dumpValue($usage->{suffix});
    delete($usage->{suffix});

    if ($self->{dictionaryManager}) {
	# call DictionaryManager to evoke events
	$self->{dictionaryManager}->updateFusana($me, $id, $opt);
    } else {
	my $info = $me->updateFusana($id);
	Egnee::Logger::info(sprintf("##### %s FUSANA decided: %s #####\n", (keys(%{$me->{'見出し語'}}))[0], $info->{pos}));
	if ($info->{midasiChange} && $opt->{updateMidasi}) {
	    $self->{workingDictionary}->updateMidasi($me, $info->{midasiChange});
	}
	if ($opt->{update}) {
	    $self->{workingDictionary}->saveAsDictionary;
	    $self->{workingDictionary}->update;
	}
    }
}

1;
