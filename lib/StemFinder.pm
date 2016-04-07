package StemFinder;

use strict;
use warnings;
use utf8;
use base qw/Exporter/;
our @EXPORT_OK = qw/$minimumExampleNum/;

use Scalar::Util qw/refaddr/;

use Egnee::Logger;
use MorphemeGrammar qw/$posList $posInclusion/;

our $minimumExampleNum = 3;       # 最低限必要な用例数
our $minimumSafeCount = 8;        # safeMode で必要な用例数

our $stemCoverageThres = 0.01;    # 後方境界のチェックの足きり
our $containedCoverageThres = 0.20;   # 完全に包含されている場合に、閾値以上の被覆率だと生かす
our $OVERLAP_THRES = 0.05;        # 包含関係のエラー許容率
our $POS_COVERAGE_THRES = 0.90;   # POS の coverage による閾値
our $BOS_THRES = 0.05;            # 用例リストの BOS 含有率の閾値
our $KATUYOU2_UNIQ_COUNT = 3;     # 活用形の最低異なり数
our $ADVERB_UNIQ_COUNT= 4;        # 副詞向け: 後続用言の最低異なり数
our $PRED_RATIO_THRES = 0.5;      # 活用形の最低異なり数

=head1 名前

StemFinder - トライを調べて新たな形態素を獲得する

=head1 用法

  use StemFinder;
  my $stemFinder = StemFinder->new;

=head1 説明

トライを調べて新たな形態素を獲得する
出力は bless されていないデータ構造。

=head1 メソッド

=head2 new()

引数なし

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift
    };
    $self->{counter} = 0;

    # default settings
    $self->{opt}->{safeMode} = 0 unless (defined($self->{opt}->{safeMode}));
    $self->{opt}->{safePosMode} = 0 unless (defined($self->{opt}->{safePosMode}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

sub setSafeMode {
    my ($self, $val) = @_;
    $self->{opt}->{safeMode} = (defined($val))? $val : 1;
}

=head2 getEntry($example, $sharedExampleList)

前方境界を共有する用例のリストから、後方境界、品詞を絞り込み、entry を帰納する

引数
  $example: 注目している用例
  $sharedExampleList: 前方境界を共有する用例のリスト

=cut
sub getEntry {
    my ($self, $sharedExamplesPerFront) = @_;

    # $example は各用例と、その解釈の候補群
    # 複数の解釈のうち、どれを選択したかは selector が持っている
    # $exampleFrontSelector は、前方境界だけを決めたもの
    # $exampleSelector は前方、後方両方を決めたもの
    # 品詞については selector を作らない
    foreach my $sharedExampleList (@$sharedExamplesPerFront) {
	my ($entry, $exampleList) = $self->getEntryFromFrontSharedExamples($sharedExampleList);
    if (not defined($entry) || $entry eq "POS_UNLIMITED_CANDIDATES"){ # POSを絞り込めなかった(opt->{safePosMode} の時のみ有効
        return undef;
    } elsif (defined($entry)) {
	    return ($entry, $exampleList);
	}
    }
    return undef;
}

sub getEntryFromFrontSharedExamples {
    my ($self, $sharedExampleList) = @_;

    # 一番後ろに格納されているのが自身
    my $exampleFrontSelector = $sharedExampleList->[$#$sharedExampleList];
    my $listPerStem = $self->arrangeExamplesPerStem($exampleFrontSelector, $sharedExampleList);

    # 被覆率でふるいにかける
    my $stemCandList = $self->dropStemsPerCoverage($listPerStem);

    # 候補毎にスコアを算出
    foreach my $stem (@$stemCandList) {
 	# ひらがな1文字語幹を除外する
 	next if (length($stem) <= 1 && $stem =~ /\p{Hiragana}/);

	my $exampleList = $listPerStem->{$stem};
 	# 品詞ごとのデータ
 	my ($listPerPOS, $katuyou2PerPOS, $eobList) =
 	    $self->arrangeExamplesPerPOS($exampleList, $stem);

	# ごみ集め用に、この段階で counter を更新
	# 要検討
	$self->updateCounter($exampleList);

	# とりあえずマッチ率であしきり
 	my $totalCount = scalar(@$exampleList);
 	my $finalPOSList = $self->dropPOSPerCoverage($listPerPOS, $totalCount, $eobList);

 	# 候補なし
 	next if (scalar(@$finalPOSList) <= 0);

 	my ($posS, $inclusionFlag);
 	if (scalar(@$finalPOSList) == 1) {
 	    # 品詞候補が一つならそれでよし
 	    $posS = $finalPOSList->[0];
 	} else {
 	    # 包含関係で品詞を絞りこむ
 	    my $realFinalPOSList = $self->dropByPOSInclusion($finalPOSList);
 	    if (scalar(@$realFinalPOSList) == 1) {
 		$posS = $realFinalPOSList->[0];
 		$inclusionFlag = 1;
        }else{
            Egnee::Logger::info(sprintf("$stem: has multiple(%d) pos candidates. \n", scalar(@$realFinalPOSList)));
            if ($self->{opt}->{safePosMode}){
                #すでにPOSの候補があるので，境界をさらに広げる前に保留する
                Egnee::Logger::info(sprintf("$stem: has multiple(%d) pos candidates. Skip search here after. \n", scalar(@$realFinalPOSList)));
                return ("POS_UNLIMITED_CANDIDATES", undef);
            }
        }
 	}
	if (defined($posS)) {
	    # TODO: 副詞チェック

	    # 最後に前方境界の妥当性をチェック
	    return undef unless ($self->isFrontBoundaryReliable($listPerPOS->{$posS}));

	    my $entry = {
		stem => $stem,
		posS => $posS,
		count => $totalCount,
		countStart => $totalCount
	    };
	    if ($inclusionFlag) {
		$entry->{status} = 'INCLUSION'; # 継続監視の必要 # DEPRECATED!
	    }

	    # TODO
 	    # とりあえず 3 回以上
	    my ($posReliable, $defaultAdverb) = $self->isPOSReliable($posS, $katuyou2PerPOS);
	    if ($posReliable) {
		$entry->{defaultAdverb} = 1 if ($defaultAdverb);

		# 獲得に用いた用例のリスト
		my $exampleList = $self->getUsedExampleList($posS, $listPerPOS, $eobList);

		# safe mode では多めの用例が必要
		# ここで調べるのは、GC の count に悪影響がないようにするため
		if ($self->{opt}->{safeMode} && scalar(@$exampleList) < $minimumSafeCount) {
		    Egnee::Logger::info(sprintf("$stem:$posS is selected, but count %d is not enough\n", scalar(@$exampleList)));
		    return undef;
		}
 		return ($entry, $exampleList);
        }else{
            if ($self->{opt}->{safePosMode}){
                #信頼度が低いだけなので，境界をさらに広げる前に保留して用例の収集に戻る
                Egnee::Logger::info(sprintf("$stem: $posS is not reliable. Skip search here after. \n"));
                return ("POS_UNLIMITED_CANDIDATES", undef);
            }
 	    }
 	}
    }
    return undef; # 獲得なし
}

# 前方境界を共有する用例のリストを $stem 毎に再配置
sub arrangeExamplesPerStem {
    my ($self, $exampleFrontSelector, $sharedExampleList, $limited) = @_;
    # $example で候補に上がっている語幹候補のみを対象にするか
    # sequential なら 1, batch 処理なら 0
    $limited = 1 unless (defined($limited));

    my $listPerStem = {};

    my $example = $exampleFrontSelector->{example};
    my $frontIndex = $exampleFrontSelector->{frontIndex};
    my ($pos, $front) = @{$example->{frontList}->[$frontIndex]};

    # 自身を最初に登録
    foreach my $rear (keys(%{$example->{rearCands}})) {
	my $stem = $front . $rear;

	# stem が空になる可能性をここで排除
	next unless (length($stem) > 0);

	my $exampleSelector = {
	    example => $example,
	    frontIndex => $frontIndex,
	    rear => $rear
	};
	$listPerStem->{$stem} = [$exampleSelector];
    }

    # 残りを登録
    for (my $i = 0; $i < scalar(@$sharedExampleList) - 1; $i++) {
	my $exampleFrontSelector = $sharedExampleList->[$i];
	my $example = $exampleFrontSelector->{example};
	my $frontIndex = $exampleFrontSelector->{frontIndex};
	my ($pos, $front) = @{$example->{frontList}->[$frontIndex]};
	foreach my $rear (keys(%{$example->{rearCands}})) {
	    my $stem = $front . $rear;
	    next unless (length($stem) > 0);
	    # $limited が正の場合は、自身にあるリストしか考慮しない
	    next if ($limited && !defined($listPerStem->{$stem}));

	    my $exampleSelector = {
		example => $example,
		frontIndex => $frontIndex,
		rear => $rear
		};
	    push(@{$listPerStem->{$stem}}, $exampleSelector);
	}
    }

    # 高速化のためにこの段階で用例数で足きり
    foreach my $stem (keys(%$listPerStem)) {
 	unless (scalar(@{$listPerStem->{$stem}}) >= $minimumExampleNum) {
	    Egnee::Logger::info("drop stem: $stem\n");

 	    delete($listPerStem->{$stem});
 	}
    }
    return ($listPerStem);
}

# 被覆率でふるいにかける
# この段階では品詞を考慮しないので (怪しい)
# EOB もそのまま扱う
sub dropStemsPerCoverage {
    my ($self, $listPerStem) = @_;

    my $stemByLength = [];
    foreach my $stem (keys(%$listPerStem)) {
	my $l = length($stem);
	push(@{$stemByLength->[$l]}, $stem);
    }

    my $dropped = {};
    # どれとどれを比較するかは再検討が必要?
    for (my $i = 0; $i < scalar(@$stemByLength) - 1; $i++) {
	next unless (defined($stemByLength->[$i]));
	for (my $p = 0; $p < scalar(@{$stemByLength->[$i]}); $p++) {
	    my $stemA = $stemByLength->[$i]->[$p];
	    next if (defined($dropped->{$stemA}));
	    for (my $j = $i + 1; $j < scalar(@$stemByLength); $j++) {
		next unless (defined($stemByLength->[$j]));
		for (my $q = 0; $q < scalar(@{$stemByLength->[$j]}); $q++) {
		    my $stemB = $stemByLength->[$j]->[$q];
		    next if (defined($dropped->{$stemB}));

		    next unless (index($stemB, $stemA) == 0);
		    my $rv = $self->calcOverlap($stemA, $stemB, $listPerStem);
		    unless ($rv) {
			Egnee::Logger::info("\tdrop $stemB\n");
			$dropped->{$stemB} = 1;
		    }
		}
	    }
	}
    }
    my $stemCands = {};
    foreach my $stem (keys(%$listPerStem)) {
	unless (defined($dropped->{$stem})) {
	    Egnee::Logger::info("survivor: '$stem'\n");

	    $stemCands->{$stem} = $listPerStem->{$stem};
	}
    }
    # 長さの短い候補から順番に
    my @stemCandsByLength = sort { length($a) <=> length($b) } (keys(%$stemCands));

    return \@stemCandsByLength;
}

# stem 同士を用例によって比較して親子関係をチェック
# B を殺す場合は 0, そうでなければ 1 を返す
# | B - A| / | A and B |
sub calcOverlap {
    my ($self, $stemA, $stemB, $listPerStem) = @_;

    my $dA = scalar(@{$listPerStem->{$stemA}});
    my $dB = scalar(@{$listPerStem->{$stemB}});

    # あまりに被覆率が低いものは足きり
    if ($dB / $dA < $stemCoverageThres) {
	Egnee::Logger::info(sprintf("%s vs %s: too low cov.: %f [%d, %d]\n", $stemA, $stemB, $dB / $dA, $dA, $dB));

	return 0;
    }

    my $bMa = 0; # 分子: B - A
    my $bIa = 0; # 分母: A and B (intersection)
    my $docID = {};
    foreach my $exampleSelector (@{$listPerStem->{$stemA}}) {
	my $id = refaddr($exampleSelector);
	$docID->{$id} |= 1;

	# トイザらス問題
	# 文字列的に $stemB に一致すればよしとする
	my $example = $exampleSelector->{example};
	my $string = $example->{frontList}->[$exampleSelector->{frontIndex}]->[1] .
	    $example->{pivot} . $example->{rearString};
	if (index($string, $stemB) == 0) {
	    $docID->{$id} |= 2;
	}
    }
    foreach my $exampleSelector (@{$listPerStem->{$stemB}}) {
	my $id = refaddr($exampleSelector);
	$docID->{$id} |= 2;
    }
    foreach my $id (keys(%$docID)) {
	if ($docID->{$id} & 2) {
	    if ($docID->{$id} & 1) {
		$bIa++;
	    } else {
		$bMa++;
	    }
	}
    }
    if ($bIa <= 0) { # 共通部分がない
	Egnee::Logger::info(sprintf("%s vs %s: [%d, %d] N/A (%d / 0): no intersection\n",
				    $stemA, $stemB, $dA, $dB, $bMa));

	return 1;
    } else {
	# 「トイザらス」問題
	# | A and B | / | A | も考慮する
	my $covA = $bIa / scalar(@{$listPerStem->{$stemA}});

	Egnee::Logger::info(sprintf("%s vs %s: [%d, %d] %f (%d / %d), intersection cov.: %f\n",
				    $stemA, $stemB, $dA, $dB,
				    $bMa / $bIa, $bMa, $bIa, $covA));
	# A が正解でなくても、かならずマッチする場合に
	# B が正解でも drop されてしまうので、
	# B が A に完全に包含されている場合は制限を緩める
	#   e.g. 煌 vs. 煌く
	if ($bMa <= 0 && $covA >= $containedCoverageThres) {
	    Egnee::Logger::info("\tcontained with substantial coverage\n");

	    return 1;
	}
	return ($covA < 1 - $OVERLAP_THRES &&  $bMa / $bIa < $OVERLAP_THRES)? 0 : 1;
    }
}

# 品詞ごとに情報を収集
sub arrangeExamplesPerPOS {
    my ($self, $exampleList, $stem) = @_;

    # 制約を満たすか調べた情報をキャッシュ
    my $POSstatus = {};

    my $listPerPOS = {}; # 品詞毎に用例を収集
    my $katuyou2PerPOS = {};
    my $eobList = [];
    foreach my $exampleSelector (@$exampleList) {
	my $example = $exampleSelector->{example};
	my $rear = $exampleSelector->{rear};
	my $posCands = $example->{rearCands}->{$rear};

	# EOB など
	if (!ref($posCands)) {
	    push(@$eobList, $exampleSelector);
	    next;
	}

	foreach my $posS (keys(%$posCands)) {
	    # $posS が追加制約を満たしているか
	    unless (defined($POSstatus->{$posS})) {
		if ($posList->{$posS}->{stemConstraints}) {
		    my $code = $posList->{$posS}->{stemConstraints};
		    my $status = &$code($stem);
		    $POSstatus->{$posS} = $status;

		    Egnee::Logger::info("$stem does not satisfy the stem constraints of $posS\n")
			if (!$status)
		} else {
		    $POSstatus->{$posS} = 1; # 制約なし
		}
	    }
	    next unless ($POSstatus->{$posS});

	    my ($katuyou2, $suffix) = @{$posCands->{$posS}};
	    push(@{$listPerPOS->{$posS}}, [$katuyou2, $suffix, $exampleSelector]);
	    $katuyou2PerPOS->{$posS}->{$katuyou2}++;
	}
    }
    Egnee::Logger::info("stem: $stem (" . join(" ", keys(%$listPerPOS)) . ")\n");

    return ($listPerPOS, $katuyou2PerPOS, $eobList);
}

# 品詞をマッチ率であしきり
sub dropPOSPerCoverage {
    my ($self, $listPerPOS, $totalCount, $eobList) = @_;

    my $eobCount = scalar(@$eobList);
    Egnee::Logger::info("EOB: $eobCount\n");

    my $finals = {};
    foreach my $posS (keys(%$listPerPOS)) {
	my $count = scalar(@{$listPerPOS->{$posS}});
	# 語幹単独で出現できる品詞は EOB の用例を追加
	$count += $eobCount if ($posList->{$posS}->{bareStem});

	Egnee::Logger::info(sprintf("%s: %f (%d / %d)\n",
				    $posS, $count / $totalCount, $count, $totalCount));

	if ($count / $totalCount > $POS_COVERAGE_THRES) {
	    $finals->{$posS} = $count / $totalCount;
	}
    }
    my @finalPOSList = keys(%$finals);
    return \@finalPOSList;
}

# 包含関係で品詞を絞りこむ
sub dropByPOSInclusion {
    my ($self, $finalPOSList) = @_;

    my $scorePerPOS = {};
    foreach my $posS1 (@$finalPOSList) {
	foreach my $posS2 (@$finalPOSList) {
	    next if ($posS1 eq $posS2);

	    # 包含される品詞
	    if ($posInclusion->{$posS1}->{$posS2}) {
		$scorePerPOS->{$posS1}->{$posS2} = 1; # included
	    }
	}
    }
    my $realFinalPOSList = [];
    foreach my $posS1 (keys(%$scorePerPOS)) {
	my $flag = 1;
	foreach my $posS2 (@$finalPOSList) {
	    next if ($posS1 eq $posS2);
	    unless ($scorePerPOS->{$posS1}->{$posS2}) {
		$flag = 0;
		last;
	    }
	}
	if ($flag) {
	    push(@$realFinalPOSList, $posS1);
	}
    }
    return $realFinalPOSList;
}

# 前方境界の妥当性をチェック
# 獲得に用いた用例群の前方境界タグがある程度信頼できるか
sub isFrontBoundaryReliable {
    my ($self, $exampleList) = @_;

    my $total = scalar(@$exampleList);
    my $BOSCount = 0;
    foreach my $tmp (@$exampleList) {
	my ($katuyou2, $suffix, $exampleSelector) = @$tmp;
	my $example = $exampleSelector->{example};
	my $type = $example->{frontList}->[$exampleSelector->{frontIndex}]->[2];
	$BOSCount++ if ($type eq 'BOS');
    }
    return ($BOSCount / $total > $BOS_THRES)? 1 : 0;
}

sub isPOSReliable {
    my ($self, $posS, $katuyou2PerPOS) = @_;

    my $totalUniq = scalar(keys(%{$katuyou2PerPOS->{$posS}}));
    return (0, 0) unless ($totalUniq >= $KATUYOU2_UNIQ_COUNT);

    my $total = 0;
    my $predCount = 0;
    my $predUniq = 0;
    while ((my ($katuyou2, $count) = each(%{$katuyou2PerPOS->{$posS}}))) {
	$total += $count;
	if ($katuyou2 =~ /^用言\:/) {
	    $predUniq++;
	    $predCount += $count;
	}
    }

    # OR conditions for adverb candidates
    #   1. 通常の活用形異なり数が閾値以上 (用言はあわせて1個の扱い)
    #   2. 用言異なり数が閾値以上
    if (($totalUniq - ($predUniq > 0? $predUniq - 1: 0) >= $KATUYOU2_UNIQ_COUNT)
	or ($predUniq >= $ADVERB_UNIQ_COUNT)) {
	my $defaultAdverb = ($predCount / $total > $PRED_RATIO_THRES && $predUniq > 1)? 1 : 0;
	return (1, $defaultAdverb);
    } else {
	return (0, 0);
    }
}


# 獲得に用いた用例のリスト
# EOB を忘れないようにする!
sub getUsedExampleList {
    my ($self, $posS, $listPerPOS, $eobList) = @_;

    my $exampleList = [];
    foreach my $tmp (@{$listPerPOS->{$posS}}) {
	my ($katuyou2, $suffix, $exampleSelector) = @$tmp;
	push(@$exampleList, $exampleSelector);
    }
    if ($posList->{$posS}->{bareStem}) {
	push(@$exampleList, @$eobList);
    }
    return $exampleList;
}

sub getCounter {
    return $_[0]->{counter};
}
# ごみ集め用に用例に count を記録
sub updateCounter {
    my ($self, $exampleList) = @_;

    my $counter = ++$self->{counter};

    foreach my $exampleSelector (@$exampleList) {
	my $example = $exampleSelector->{example};
	$example->{count} = $counter;
    }    
}

1;
