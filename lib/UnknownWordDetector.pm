package UnknownWordDetector;
#
# detect unknown morphemes from sentences
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;
use MorphemeUtilities;
use UndefRuleMatcher;
use Ngram;
use MorphemeGrammar qw/$separatorBunrui $separators/;

our $likelihoodThres = 0.001;
# our $likelihoodThres = 0.0001;
our $lambda = 0.99;
our $VOC_SIZE = 30000;
our $PSEUDO_COUNT = 0.01;
our $PSEUDO_DENOM = $PSEUDO_COUNT * $VOC_SIZE;

our $BOUNDARYKEY;

BEGIN {
    $BOUNDARYKEY = &Ngram::compressID(&Ngram::boundaryID);
}

=head1 名前

UnknownWordDetector - KNP の解析結果から未知語の用例を検出する

=head1 用法

  use UnknownWordDetector;
  my $detector = new UnknownWordDetector ($ruleFile, $repnameListFile, $repnameNgramFile, { dumper => 1, debug => 1 });

=head1 説明

KNP の解析結果から未知語の用例を検出する。
setEnumerator に CandidateEnumerator を指定することで、検出した未知語の処理を進める。

=head1 メソッド

=head2 new ($ruleFile, $repnameList, $repnameNgram, $opt)

引数

    $ruleFile: UndefRule のルール構造体のファイルパス
    $repnameList: 表記揺れの代表表記構造体 (使わないなら undef)
    $repnameNgram: 表記揺れの Ngram 構造体 (使わないなら undef)
    $opt: オプション

オプション
    filterNoise: 入力文をフィルタリングして獲得対象テキストから外すか
    enableNgram: 表記揺れ知識を検出に使うか
    smoothing: N-gram の smoothing を行なうか
    detectionSkip: 検出したあと、しばらく検出をしないか
      デフォルトで skip する。評価のためのオプション。
    updateNgram: 走査した Ngram をもとにカウントを増やすか

=cut
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $ruleFile = shift;
    my $repnameList = shift;
    my $repnameNgram = shift;

    my $self = {
	repnameList => $repnameList,
	repnameNgram => $repnameNgram,
	opt => shift,
    };
    # default settings
    $self->{opt}->{filterNoise} = 1 unless (defined($self->{opt}->{filterNoise}));
    $self->{opt}->{enableNgram} = 1 unless (defined($self->{opt}->{enableNgram}));
    $self->{opt}->{detectZero} = 1  unless (defined($self->{opt}->{detectZero}));
    $self->{opt}->{smoothing} = 1   unless (defined($self->{opt}->{smoothing}));
    $self->{opt}->{debugSmoothing} = 0   unless (defined($self->{opt}->{debugSmoothing}));
    $self->{opt}->{detectionSkip} = 1    unless (defined($self->{opt}->{detectionSkip})); # 評価用
    $self->{opt}->{updateNgram} = 1 unless (defined($self->{opt}->{updateNgram}));
    $self->{opt}->{noDetectHanNgram} = 1 unless (defined($self->{opt}->{noDetectHanNgram}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    # if ($self->{opt}->{noAdditiveSmoothing}) {
    # 	$PSEUDO_COUNT = $PSEUDO_DENOM = 0;
    # }

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    $self->{matcher} = UndefRuleMatcher->new($ruleFile);
    if ($self->{opt}->{enableNgram}) {
	&Ngram::initRepnameList($repnameList);
	&Ngram::setTable($repnameNgram->{table});
    }
    return $self;
}

sub DESTROY {
    my ($self) = @_;

    if (defined($self->{enumerator})) {
	delete($self->{enumerator});
    }
}

=head2 setEnumerator ($enumerator)

検出された未知語を処理するインスタンスを指定。
インスタンスの makeExample というメソッドが呼び出される

引数

    $enumerator: CandidateEnumerator のインスタンス

=cut
sub setEnumerator {
    my ($self, $enumerator) = @_;

    $self->{enumerator} = $enumerator;
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
# # SentenceBasedAnalysisObserverRegistry に登録しているので、document が渡される
# sub onDocumentChange {
#     my ($self, $document) = @_;
# }

# SentenceBasedAnalysisObserverRegistry に登録しているので、knp の解析結果が渡される
sub onSentenceAvailable {
    my ($self, $sentence) = @_;

    my $knpResult = $sentence->get('knp');
    return unless (defined($knpResult));

    # filter out dirty data
    if ($self->{opt}->{filterNoise} && $self->isNoisySentence($sentence)) {
	$sentence->set('noisy', 1);
	return;
    }

    # detect unknown morphemes
    my $exampleCandList = $self->detectExampleCands($knpResult, $sentence);

    # call callback functions and event listeners
    if (defined($self->{callback})) {
	foreach my $exampleCand (@$exampleCandList) {
	    &{$self->{callback}}($knpResult, $exampleCand);
	}
    }
    if (defined($self->{enumerator})) {
	foreach my $exampleCand (@$exampleCandList) {
	    # transform the detected unknown morpheme into a struct
	    $self->{enumerator}->makeExample($knpResult, $exampleCand);
	}
    }
}


# 未知語を検出
sub detectExampleCands {
    my ($self, $knpResult, $sentence) = @_;

    my $exampleCandList = []; # return value
    my $detectedBunsetsuList = [];
    my $bnstMap = &MorphemeUtilities::makeBnstMap($knpResult); # mapping from mrph sequence index p to bnst index k

    # variables for N-gram
    my $ngramList = [];
    my $repnameList = $self->{repnameList};
    my $repnameNgram = $self->{repnameNgram};

    my $doSkip = 0;   # skip N morphemes
    my $detected = 0; # 検出されると、境界が出るまでスキップ
    # 形態素を前から順番に走査
    my @mrphList = $knpResult->mrph;
    for (my $i = 0, my $iL = scalar(@mrphList); $i < $iL; $i++) {
	my $mrphP = ($i - 1 >= 0)? $mrphList[$i - 1] : undef;
	my $mrph = $mrphList[$i];
	my $mrphN = ($i + 1 < scalar(@mrphList))? $mrphList[$i + 1] : undef;

	if ($detected) {
	    # 検出したら境界の文字が来るまで飛ばす
	    # 境界文字を $mrph とする SKIP ルールを有効にするため、
	    # $mrph ではなく $mrphN が境界である場合を調べる
	    last unless (defined($mrphN)); # $mrph で終り
	    my $midasiN = substr($mrphN->midasi, 0, 1); # 記号の繰返しはまとめられる
	    $detected = 0
		if ($separatorBunrui->{$mrphN->bunrui} || $separators->{$midasiN});
	    next;
	}
	# SKIP 指定されている場合も調べる
	# さらに SKIP する場合があるから
	my $feature = $self->{matcher}->match($mrphP, $mrph, $mrphN);

	if (!$feature && $doSkip > 0) {
	    $doSkip--;
	    next;
	}
	$doSkip--;
	if ($feature) {
	    if ($feature eq 'SINGLESKIP') { next; }
	    if ($feature eq 'SKIP') { $doSkip = 2; next; }
	    next if ($doSkip > 0);

	    # る動詞の例外条件
	    # 前後の各1形態素だけではわからない条件
	    # 読め + って + の + も などの誤解析
	    if ($feature eq 'る動詞' && $mrphN->midasi eq 'って') {
		my $mrph0 = $knpResult->mrph($i + 2);
		my $mrph1 = $knpResult->mrph($i + 3);
		if (defined($mrph0) && defined($mrph1)
		    && $mrph0->hinsi eq '助詞' && $mrph1->hinsi eq '助詞') {
		    $doSkip = 2;
		    next;
		}
	    }

	    $self->printDetection($knpResult, $mrphP, $mrph, $mrphN, $feature) if ($self->{opt}->{debug});
	    $detected = 1 if ($self->{opt}->{detectionSkip});
	    push(@$detectedBunsetsuList, $bnstMap->[$i]->[0]);
	    push(@$exampleCandList, {
		feature => $feature,
		mrphP => $mrphP, mrph => $mrph,	mrphN => $mrphN,
		pos => $i,
		bnstPos => $bnstMap->[$i]->[0],	mrphPos => $bnstMap->[$i]->[1]
		 });
	    next;
	}
	# 次は Ngram によるマッチ
	next unless ($self->{opt}->{enableNgram});

	my ($checkFB, $checkBB) = &initIDList(\@mrphList, $ngramList, $i);
	my $w0 = $ngramList->[$i]->{word}->[0];
	my $id0 = $ngramList->[$i]->{id}->[0];
	my ($midasi, $repname, $class) = split(/-/, $w0);

	# 付属語やチェック対象でない代表表記を無視
	next unless (($id0->[1] > 0 && defined($repnameList->{$repname})));
	$ngramList->[$i]->{isRepname} = 1;

	my $list = $repnameList->{$repname}->{$midasi}; # 代替表記のリスト
	next unless (defined($list)); # 対象外見出し語を無視
	$ngramList->[$i]->{isTarget} = 1;

	next if (&isStopWord($w0)); # 付け焼き刃の stopword

	my ($uniC, $detectedU, $featureU) = $self->checkUnigram($repnameList, $repnameNgram, $ngramList, $i);
	if ($detectedU) {
	    next if ($self->{opt}->{detectZero});
	    $detected = 1; $feature = $featureU;
	} else {
        if ( $self->{opt}->{noDetectHanNgram} && ($midasi =~ /\p{Han}/)  ){#漢字を含んでいればskip
            next;
        }
	    if ($checkFB && defined($ngramList->[$i + 1])) {
            my $w0_tmp = $ngramList->[$i+1]->{word}->[0];
            my ($midasi_tmp, $repname_tmp, $class_tmp) = split(/-/, $w0_tmp); #word を分割
            if ( $self->{opt}->{noDetectHanNgram} && ($midasi_tmp =~ /\p{Han}/)  ){#漢字を含んでいればskip
                next;
            }
		# forward bigram のチェック
		my ($detectedF, $featureF) =
		    $self->checkForwardBigram($repnameList, $repnameNgram, \@mrphList, $ngramList, $i, $bnstMap, $uniC);
		if ($detectedF) {
		    $detected = $detectedF; $feature = $featureF;
		}
	    }
	    if (!$detected && $checkBB && defined($ngramList->[$i - 1])) {
            my $w0_tmp = $ngramList->[$i-1]->{word}->[0];
            my ($midasi_tmp, $repname_tmp, $class_tmp) = split(/-/, $w0_tmp); #word を分割
            if ( $self->{opt}->{noDetectHanNgram} && ($midasi_tmp =~ /\p{Han}/)  ){#漢字を含んでいればskip
                next;
            }
		# backward bigram のチェック
		my ($detectedB, $featureB) =
		    $self->checkBackwardBigram($repnameList, $repnameNgram, \@mrphList, $ngramList, $i, $bnstMap, $uniC);
		if ($detectedB) {
		    $detected = $detectedB; $feature = $featureB;
		}
	    }
	}
	if ($detected) {
	    $self->printDetection($knpResult, $mrphP, $mrph, $mrphN, $feature) if ($self->{opt}->{debug});

	    push(@$exampleCandList, {
		feature => $feature,
		mrphP => $mrphP, mrph => $mrph,	mrphN => $mrphN,
		pos => $i,
		bnstPos => $bnstMap->[$i]->[0],	mrphPos => $bnstMap->[$i]->[1]
		 });
	    $detected = 0 unless ($self->{opt}->{detectionSkip});
	    push(@$detectedBunsetsuList, $bnstMap->[$i]->[0]);
	}
    }

    # 後処理
    $self->updateNgram($repnameNgram, $ngramList, $bnstMap) if ($self->{opt}->{updateNgram});
    if (scalar(@$detectedBunsetsuList) > 0) {
	$sentence->set('detected', $detectedBunsetsuList);
    }

    return $exampleCandList;
}

# ゃゅょ が前接できるカナのリスト
# ひらがなのみ
our $yooonTable = {
    'き' => 1, 'し' => 2, 'ち' => 3, 'に' => 4, 'ひ' => 5, 'み' => 6, 'り' => 7,
    'ぎ' => 8, 'じ' => 9, 'ぢ' => 10, 'び' => 11, 'ぴ' => 12
};
our $bnstMaxLength = 15; # 文節の最大長によるノイズ除去; -1 のときは制限なし

# ゴミっぽい文をまるごと無視する
# 1 なら除去
sub isNoisySentence {
    my ($self, $sentence) = @_;

    my $knpResult = $sentence->get('knp');
    my $rawString = $sentence->get('raw');
    return 1 unless ($rawString);

    # 変な場所に全角空白が挿入されていることがある
    # 文語はとりあえず無視
    if ($rawString =~ /([　〓ゐゑヰヱヽヾゝゞ])/) {
	if ($1 ne '　') {
	    Egnee::Logger::info("omitted: obsolete orthography or GETA: \"$1\", $rawString\n");
	}
	return 1;
    }

    # 正しい拗音かチェック
    if ($rawString =~ /(.)[ゃゅょ]/g) {
	# @- は the last successful match なので
	# 失敗したときのために if が必要?
	for (my $i = 1; $i < scalar (@-); $i++) {
	    my $matched = substr($rawString, $-[$i], 1);
	    unless (defined($yooonTable->{$matched})) {
		Egnee::Logger::info("incorrect yoon: $matched <- $rawString\n");
		return 1;
	    }
	}
    }

    my @bnstList = $knpResult->bnst;
    my $mrphP;
    for (my $i = 0; $i < scalar(@bnstList); $i++) {
	my $bnst = $bnstList[$i];
	my @mrphList = $bnst->mrph;

	my $bnstLength = 0;
	for (my $j = 0; $j < scalar(@mrphList); $j++) {
	    my $mrph = $mrphList[$j];
	    my $midasi = $mrph->midasi;

	    $bnstLength += length($midasi);
	    # 1 文節が長過ぎるものは排除 文字化けなど
	    if ($bnstLength > $bnstMaxLength && $bnstMaxLength > 0) {
		Egnee::Logger::info("too long bunsetsu: $bnstLength\n");
		return 1;
	    }
	    return 1 if ($mrph->fstring =~ /\<小文字化\>/); # JUMAN による非正規表現への対応

	    # 未知語について KNP の文節境界を信用しない
	    if ($midasi =~ /^[ぁぃぅぇぉ]/) {
		return 1 unless (defined($mrphP));
		return 1 unless ($mrphP->fstring =~ /\<ひらがな\>/);
	    } elsif ($midasi =~ /^[ッァィゥェォャュョン]/) {
		return 1 unless (defined($mrphP));
		return 1 unless ($mrphP->fstring =~ /\<カタカナ\>/);
	    }
	    $mrphP = $mrph;
	}
    }
    return 0;
}

# 形態素から、Ngram を引くキーを作る
# すでに作ったものはキャッシュしておく
sub initIDList {
    my ($mrphList, $ngramList, $i) = @_;
    my $checkFB = 1;
    my $checkBB = 1;

    # backward
    # アルファベットなどの未定義語は SINGLESKIP なので
    # 改めて未定義語かどうかを調べる
    if ($i > 0 && !defined($ngramList->[$i - 1]) ) {
	my $mrph = $mrphList->[$i - 1];
	if (&MorphemeUtilities::isUndefined($mrph)) {
	    $checkBB = 0;
	} else {
	    &initID($mrphList->[$i - 1], $ngramList, $i - 1);
	}
    }

    # 自分
    # 未定義語のチェックはルールで済んでいるので省略できる
    unless (defined($ngramList->[$i])) {
	&initID($mrphList->[$i], $ngramList, $i);
    }

    # forward
    # 次の形態素が未定義語化は rule ではチェックしていないので先に調べておく
    # 未定義語なら、forward bigram のチェックをしない
    if ($i + 1 < scalar(@$mrphList)) {
	my $mrph = $mrphList->[$i + 1];
	if (&MorphemeUtilities::isUndefined($mrph)) {
	    $checkFB = 0;
	} else {
	    &initID($mrphList->[$i + 1], $ngramList, $i + 1);
	}
    }
    return ($checkFB, $checkBB);
}

# 一つの形態素の処理
sub initID {
    my ($mrph, $ngramList, $i) = @_;

    my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph, { revertVoicing => 1 });
    my $w = &Ngram::getWord($mrphO);
    my $struct = $ngramList->[$i] = { word => [], id => [] };
    push(@{$struct->{word}}, $w);
    push(@{$struct->{id}}, &Ngram::word2id($w));

    return unless ($mrphO->{doukei} && $mrph->fstring =~ /\<自立\>/);
    # 同形の処理
    # 付属語の場合は見出し語を見るので不要
    for (my $j = 0; $j < scalar(@{$mrphO->{doukei}}); $j++) {
	my $mrphO2 = $mrphO->{doukei}->[$j];

	# 同形は fstring を持たないので、明示的に「自立語」であると教える
	my $w = &Ngram::getWord($mrphO2, { isJiritu => 1 });
	push(@{$struct->{word}}, $w);
	push(@{$struct->{id}}, &Ngram::word2id($w));
    }
}

# $repnameNgram のカウントを更新
# $ngramList のデータを使うので不正確
# 実用的には「自動獲得」の形態素関係だけを更新すればいいかもしれない
sub updateNgram {
    my ($self, $repnameNgram, $ngramList, $bnstMap) = @_;

    my $uni = $repnameNgram->{uni};
    my $fbi = $repnameNgram->{fbi};
    my $bbi = $repnameNgram->{bbi};
    my $Bf = $repnameNgram->{Bf};
    my $Bb = $repnameNgram->{Bb};

    # 何をカウントするかは abstractLM.pl を参照
    for (my $i = 0, my $l = scalar(@$ngramList); $i < $l; $i++) {
	next unless (defined($ngramList->[$i]));
	my $struct = $ngramList->[$i];
	my $id = $struct->{id}->[0];
	my ($idM, $idA, $idAM); # 使い回す変数

	# unigram; repname
	if ($struct->{isRepname}) {
	    $idM = &Ngram::getMidasiID($id);
	    $uni->{&Ngram::compressID($idM)}++;
	    my $idMA = &Ngram::getAbstractClassID($idM);
	    if ($idM->[2] != $idMA->[2]) {
		$uni->{&Ngram::compressID($idMA)}++;
	    }
	}
	# bigram
	if ($struct->{isTarget}) {
	    # forward bigram
	    if (defined($ngramList->[$i + 1])) {
		my $idF = $ngramList->[$i + 1]->{id}->[0];
		my $idFA = &Ngram::getAbstractClassID($idF);
		$idM = $idM || &Ngram::getMidasiID($id);
		my $idFR = &Ngram::getRepnameID($idFA);
		my $kF = &Ngram::compressID($idFR);
		$fbi->{&Ngram::compressID($idM)}->{$kF}++;
	    }
	    # backward bigram
	    if ($i - 1 >= 0 && defined($ngramList->[$i - 1])) {
		my $idB = $ngramList->[$i - 1]->{id}->[0];
		$idA = &Ngram::getAbstractClassID($id);
		my $idBR = &Ngram::getRepnameID($idB);
		$idAM = &Ngram::getMidasiID($idA);
		my $kB = &Ngram::compressID($idBR);
		$bbi->{&Ngram::compressID($idAM)}->{$kB}++;
	    }
	}

	if ($bnstMap->[$i]->[1] == 0) {
	    $repnameNgram->{Bu}++;

	    # forward bigram の f(B, r1)
	    #   abstractClass + repname
	    # backward bigram の f(B, w0)
	    #   abstractClass + 代表表記除去
	    $idA = $idA || &Ngram::getAbstractClassID($id);
	    my $idAR = &Ngram::getRepnameID($idA);
	    $Bb->{&Ngram::compressID($idAR)}++;
	    if ($struct->{isTarget}) {
		$idAM = $idAM || &Ngram::getMidasiID($idA);
		$Bb->{&Ngram::compressID($idAM)}++;
	    }
	}
	if (defined($bnstMap->[$i + 1]) && $bnstMap->[$i + 1]->[1] == 0) {
	    # forward bigram の f(w0, B)
	    #   代表表記除去
	    # backward bigram の f(r-1, B)
	    #   repname
	    my $idR = &Ngram::getRepnameID($id);
	    $Bf->{&Ngram::compressID($idR)}++;
	    if ($struct->{isTarget}) {
		$idM = $idM || &Ngram::getMidasiID($id);
		$Bf->{&Ngram::compressID($idM)}++;
	    }
	}

    }
}

sub checkUnigram {
    my ($self, $repnameList, $repnameNgram, $ngramList, $i) = @_;

    my $id = $ngramList->[$i]->{id}->[0];
    my $idM = &Ngram::getMidasiID($id);
    my $uniC = $repnameNgram->{uni}->{&Ngram::compressID($idM)} || 0;
    if ($uniC <= 0) {
	# unigram がなければ問答無用で検出
	Egnee::Logger::info(sprintf("detect %d %s\tno unigram\n", $i, $ngramList->[$i]->{word}->[0]))
	    if ($self->{opt}->{detectZero});
	return (0, 1, 'UNI_ZERO');
    }
    return ($uniC, 0, undef);
}

sub checkForwardBigram {
    my ($self, $repnameList, $repnameNgram, $mrphList, $ngramList, $i, $bnstMap, $uniC) = @_;

    # 文末とのチェックは今のところ行なっていない。
    return (0, undef) if ($i + 1 >= scalar(@$mrphList));

    my $zeroFlag = 1; # すべてのバリエーションで forward bigram count が 0
    my $lFlag = 1;    # すべてのバリエーションで forward bigram likelihodd が閾値以下
    my $doSmoothing = ($self->{opt}->{smoothing} && $bnstMap->[$i + 1]->[1] == 0)? 1 : 0;

    my $w0 = $ngramList->[$i]->{word}->[0];
    my $id0 = $ngramList->[$i]->{id}->[0];
    my $id0M = &Ngram::getMidasiID($id0);
    my $k0 = &Ngram::compressID($id0M);
    my ($midasi, $repname, $class) = split(/-/, $w0);
    my $fbiW0 = $repnameNgram->{fbi}->{$k0};

    #  形態素   ID             状態                          例
    #  ----------------------------------------------------------------------------------
    #           $id0           w0 の初期状態                 来る-来る/くる-<動詞:基本形>
    #  w0       $id0M          代表表記を除去                来る--<動詞:基本形>
    #       *   $id0R          w0 の同形                     繰る-繰る/くる-<動詞:基本形>
    #       *   $id0RM         代表表記を除去                繰る--<動詞:基本形>
    #  w0'  *   $id0prime      $id0RM の代表表記入れ替え     くる--<動詞:基本形>
    #
    #       *   $idF           wf の初期状態
    #  wf   *   &Ngram::getAbstractClassID (&Ngram::getRepnameID ($idF))
    #                          見出しを除去, 活用型は無視
    #
    #
    #  カウント     計算箇所
    #  ------------------------------
    #  f(w0)        引数 $uniC
    #  f(w0, wf)    wf のループで計算
    #  f(w0')       最初に計算
    #  f(w0', wf)   wf のループで計算
    #
    #  smoothing:
    #  f(w0, B)     最初に計算
    #  f(B, wf)     wf のループで計算
    #  f(w0', B)    最初に計算

    # f(w0, B) / f(w0)
    my $b1P = (($repnameNgram->{Bf}->{$k0} || 0) + $PSEUDO_COUNT) / ($uniC + $PSEUDO_DENOM)
	if ($doSmoothing);

    # w0' は代表表記いり
    # 同形をすべて足し合わせる
    my $strW0prime = ''; # for debug print
    my $primeList = [];
    my $uniCprime = 0;
    my $b1Cprime = 0;
    # f(w0') と f(w0', B) のカウント
    for (my $j = 0; $j < scalar(@{$ngramList->[$i]->{id}}); $j++) {
	my $w0R = $ngramList->[$i]->{word}->[$j];
	my $id0R = $ngramList->[$i]->{id}->[$j];
	my $id0RM = &Ngram::getMidasiID($id0R);

	my ($midasi, $repname, $class) = split(/-/, $w0R);
	# 付属語やチェック対象でない代表表記を無視
	next unless (($id0R->[1] > 0 && defined($repnameList->{$repname})));
	my $list = $repnameList->{$repname}->{$midasi};
	next unless (defined($list));

	my $k0primeList = [];
	foreach my $genkei2 (@$list) {
	    $strW0prime .= $genkei2 . ' ';
	    my $id0prime = &Ngram::replaceMidasi($id0RM, $genkei2);
	    my $k0prime = &Ngram::compressID($id0prime);
	    push(@$k0primeList, $k0prime);

	    $uniCprime += $repnameNgram->{uni}->{$k0prime} || 0;
	    # smoothing
	    $b1Cprime += ($repnameNgram->{Bf}->{$k0prime} || 0) # f(w0', B)
		if ($doSmoothing);
	}
	push(@$primeList, $k0primeList);
    }

    # # TODO:
    # #   ま-間/ま-<普通名詞> の counterpart, 間-間/ま-<普通名詞> は、
    # #     間-間/あいだ-<時相名詞> に隠されるが、
    # #     これはチェック対象外なので 0 になる
    # #   みたところ代替怪しい表記なのでとりあえず検出
    # if ($uniCprime == 0) {
    # 	if ($self->{opt}->{detectZero}) {
    # 	    Egnee::Logger::info("backward: uniCprime is zero: $w0 ($strW0prime)\n");
    # 	    return (1, 'UNIC_ZERO');
    # 	} else {
    # 	    return (0, undef);
    # 	}
    # }

    my $b1Pprime = ($b1Cprime + $PSEUDO_COUNT) / ($uniCprime + $PSEUDO_DENOM)
	if ($doSmoothing); # f(w0', B) / f(w0')

    # wf の同形をすべて調べる
    for (my $j = 0; $j < scalar(@{$ngramList->[$i + 1]->{id}}); $j++) {
	my $idF = $ngramList->[$i + 1]->{id}->[$j];
	my $kf = &Ngram::compressID(&Ngram::getAbstractClassID(&Ngram::getRepnameID($idF)));

	my $fbiC = $fbiW0->{$kf} || 0;
	my $fbiP = ($fbiC + $PSEUDO_COUNT) / ($uniC + $PSEUDO_DENOM);

	my $b2P; # f(B, rf) / f(B)
	if ($doSmoothing) { # smoothing
	    $b2P = (($repnameNgram->{Bb}->{$kf} || 0) + $PSEUDO_COUNT) / ($repnameNgram->{Bu} + $PSEUDO_DENOM);

	    Egnee::Logger::info(sprintf("forward bigram before smoothing: %f (%f)\n", $fbiP, $b1P * $b2P))
		if ($self->{opt}->{debugSmoothing});
	    $fbiP = $lambda * $fbiP + (1 - $lambda) * $b1P * $b2P;
	    Egnee::Logger::info(sprintf("forward bigram after smoothing:  %f\n", $fbiP))
		if ($self->{opt}->{debugSmoothing});
	}

	if ($fbiP <= 0) {
	    Egnee::Logger::info(sprintf("\t%d %s %s\tno forward bigram\n", $i, $w0, $ngramList->[$i + 1]->{word}->[$j]));
	} else {
	    $zeroFlag = 0;

	    # f(w0', rf) のカウント
	    my $fbiCprime = 0;
	    foreach my $k0primeList (@$primeList) {
		foreach my $k0prime (@$k0primeList) {
		    $fbiCprime += $repnameNgram->{fbi}->{$k0prime}->{$kf} || 0;
		}
	    }
	    # f(w0', rf) / f(w0')
	    my $fbiPprime = ($fbiCprime + $PSEUDO_COUNT) / ($uniCprime + $PSEUDO_DENOM);

	    if ($doSmoothing) { # smoothing
		Egnee::Logger::info(sprintf("forward bigram before smoothing (prime): %f (%f)\n", $fbiPprime, $b1Pprime * $b2P))
		    if ($self->{opt}->{debugSmoothing});
		$fbiPprime = $lambda * $fbiPprime + (1 - $lambda) * $b1Pprime * $b2P;
		Egnee::Logger::info(sprintf("forward bigram after smoothing (prime):  %f\n", $fbiPprime))
		    if ($self->{opt}->{debugSmoothing});
	    }

	    my $likelihood = $fbiPprime / $fbiP;
	    if ($likelihood >= $likelihoodThres) {
		$lFlag = 0;
	    } else {
		Egnee::Logger::info(sprintf("\t%d %s(%s) %s\tforward bigram likelihood: %f\n",
					    $i, $w0, $strW0prime, $ngramList->[$i + 1]->{word}->[$j], $likelihood));
	    }
	}
    }
    my $detected = 0;
    my $feature = undef;
    if ($zeroFlag && $self->{opt}->{detectZero}) {
	# bigram がない時
	$detected = 1;
	$feature = 'FBI_ZERO';
    } elsif ($lFlag) {
	# likelihood がすべて基準越え
	$detected = 1;
	$feature = 'FBI_BALANCE';
    }
    return ($detected, $feature);
}

sub checkBackwardBigram {
    my ($self, $repnameList, $repnameNgram, $mrphList, $ngramList, $i, $bnstMap, $uniC) = @_;

    my $zeroFlag = 1; # すべてのバリエーションで backward bigram count が 0
    my $lFlag = 1;    # すべてのバリエーションで backward bigram likelihodd が閾値以下
    my $doSmoothing = ($self->{opt}->{smoothing} && $bnstMap->[$i]->[1] == 0)? 1 : 0;

    my $w0 = $ngramList->[$i]->{word}->[0];
    my $id0 = $ngramList->[$i]->{id}->[0];
    my $id0A = &Ngram::getAbstractClassID($id0);
    my $id0AM = &Ngram::getMidasiID($id0A);
    my $k0A = &Ngram::compressID($id0AM);
    my ($midasi, $repname, $class) = split(/-/, $w0);
    my $bbiW0 = $repnameNgram->{bbi}->{$k0A};
    # unigram の $uniC の値は使わない
    # backward なので活用形を無視した頻度を計算
    if ($id0->[2] != $id0A->[2]) {
	$uniC = $repnameNgram->{uni}->{$k0A}
    }

    #  形態素   ID             状態                          例
    #  ----------------------------------------------------------------------------------
    #           $id0           w0 の初期状態                 来る-来る/くる-<動詞:基本形>
    #           $id0A          活用形無視                    来る-来る/くる-<動詞>
    #  w0       $id0AM         代表表記を除去                来る--<動詞>
    #       *   $id0R          w0 の同形                     繰る-繰る/くる-<動詞:基本形>
    #       *   $id0RM         代表表記を除去                繰る--<動詞:基本形>
    #  w0'  *   $id0prime      $id0RM の代表表記入れ替え     くる--<動詞:基本形>
    #
    #       *   $idB           wb の初期状態
    #  wb   *   &Ngram::getAbstractClassID (&Ngram::getRepnameID ($idF))
    #                          見出しを除去, 活用型は無視
    #
    #
    #  カウント     計算箇所
    #  ------------------------------
    #  f(w0)        引数 $uniC
    #  f(w0, wf)    wf のループで計算
    #  f(w0')       最初に計算
    #  f(w0', wf)   wf のループで計算
    #
    #  smoothing:
    #  f(w0, B)     最初に計算
    #  f(B, wf)     wf のループで計算
    #  f(w0', B)    最初に計算

    # wb w0 の連接では
    # 1. wb は代表表記に統合
    # 2. w0 の活用型は無視

    # w0 は活用形を無視・代表表記を無視
    my $b1P; # f(B, w0) / f(w0)
    if ($doSmoothing) {
	$b1P = (($repnameNgram->{Bb}->{$k0A} || 0) + $PSEUDO_COUNT) / ($uniC + $PSEUDO_DENOM);
    }

    # w0' は代表表記いり
    # 同形をすべて足し合わせる
    my $strW0prime = ''; # for debug print
    my $primeList = [];
    my $uniCprime = 0;
    my $b1Cprime = 0;
    # f(w0') と f(B, w0') のカウント
    for (my $j = 0; $j < scalar(@{$ngramList->[$i]->{id}}); $j++) {
	my $w0R = $ngramList->[$i]->{word}->[$j];
	my $id0R = $ngramList->[$i]->{id}->[$j];
	my $id0A = &Ngram::getAbstractClassID($id0R);
	my $id0RMA = &Ngram::getMidasiID($id0A);

	my ($midasi, $repname, $class) = split(/-/, $w0R);
	# 付属語やチェック対象でない代表表記を無視
	next unless (($id0->[1] > 0 && defined($repnameList->{$repname})));
	my $list = $repnameList->{$repname}->{$midasi};
	next unless (defined($list));

	my $k0AprimeList = [];
	foreach my $genkei2 (@$list) {
	    $strW0prime .= $genkei2 . ' ';
	    # w0' も活用型は無視
	    # ただし repname の抽象化は行なわない
	    my $id0Aprime = &Ngram::replaceMidasi($id0RMA, $genkei2);
	    my $k0Aprime = &Ngram::compressID($id0Aprime);
	    push(@$k0AprimeList, $k0Aprime);

	    $uniCprime += $repnameNgram->{uni}->{$k0Aprime} || 0;
	    # smoothing
	    $b1Cprime += ($repnameNgram->{Bb}->{$k0Aprime} || 0) # f(B, w0') / f(w0')
		if ($doSmoothing);
	}
	push(@$primeList, $k0AprimeList);
    }

    # if ($uniCprime == 0) {
    # 	if ($self->{opt}->{detectZero}) {
    # 	    Egnee::Logger::info("backward: uniCprime is zero: $w0 ($strW0prime)\n");
    # 	    return (1, 'UNIC_ZERO');
    # 	} else {
    # 	    return (0, undef);
    # 	}
    # }

    my $b1Pprime = ($b1Cprime + $PSEUDO_COUNT) / ($uniCprime + $PSEUDO_DENOM)
	if ($doSmoothing); # f(w0', B) / f(w0')

    # 後向きチェックは文頭も調べる
    my $idBList = ($i > 0)? $ngramList->[$i - 1]->{id} : [&Ngram::bosID];
    # wb の同形をすべて調べる
    for (my $k = 0; $k < scalar(@$idBList); $k++) {
	my $idB = $idBList->[$k];
	my $kb = &Ngram::compressID(&Ngram::getRepnameID($idB));

	my $bbiC = $bbiW0->{$kb} || 0;
	my $bbiP = ($bbiC + $PSEUDO_COUNT) / ($uniC + $PSEUDO_DENOM);

	my $b2P; # f(rb, B) / f(B)
	if ($doSmoothing) {
	    $b2P = (($repnameNgram->{Bf}->{$kb} || 0) + $PSEUDO_COUNT) / ($repnameNgram->{Bu} + $PSEUDO_DENOM);

	    Egnee::Logger::info(sprintf("backward bigram before smoothing: %f (%f)\n", $bbiP, $b1P * $b2P))
		if ($self->{opt}->{debugSmoothing});
	    $bbiP = $lambda * $bbiP + (1 - $lambda) * $b1P * $b2P;
	    Egnee::Logger::info(sprintf("backward bigram after smoothing:  %f\n", $bbiP))
		if ($self->{opt}->{debugSmoothing});
	}

	if ($bbiP <= 0) {
	    Egnee::Logger::info(sprintf("\t%d %s %s\tno backward bigram\n", $i, $ngramList->[$i - 1]->{word}->[$k], $w0));
	} else {
	    $zeroFlag = 0;

	    # f(wb, w0') のカウント
	    my $bbiCprime = 0;
	    foreach my $k0AprimeList (@$primeList) {
		foreach my $k0Aprime (@$k0AprimeList) {
		    $bbiCprime += $repnameNgram->{bbi}->{$k0Aprime}->{$kb} || 0;
		}
	    }
	    # f(wb, w0') / f(w0')
	    my $bbiPprime = ($bbiCprime + $PSEUDO_COUNT) / ($uniCprime + $PSEUDO_DENOM);

	    if ($doSmoothing) { # smoothing
		Egnee::Logger::info(sprintf("backward bigram before smoothing: %f (%f)\n", $bbiPprime, $b1Pprime * $b2P))
		    if ($self->{opt}->{debugSmoothing});
		$bbiPprime = $lambda * $bbiPprime + (1 - $lambda) * $b1Pprime * $b2P;
		Egnee::Logger::info(sprintf("backward bigram after smoothing:  %f\n", $bbiPprime))
		    if ($self->{opt}->{debugSmoothing});
	    }

	    my $likelihood = $bbiPprime / $bbiP;
	    if ($likelihood >= $likelihoodThres) {
		$lFlag = 0;
	    } else {
		Egnee::Logger::info(sprintf("detect %d %s %s(%s)\tbackward bigram likelihood: %f\n",
					    $i, $ngramList->[$i - 1]->{word}->[$k], $w0, $strW0prime, $likelihood));
	    }
	}
    }
    my $detected = 0;
    my $feature = undef;
    if ($zeroFlag && $self->{opt}->{detectZero}) {
	# bigram がない時
	$detected = 1;
	$feature = 'BBI_ZERO';
    } elsif ($lFlag) {
	# likelihood がすべて基準越え
	$detected = 1;
	$feature = 'BBI_BALANCE';
    }
    return ($detected, $feature);
}

# debug
sub printDetection {
    my ($self, $knpResult, $mrphP, $mrph, $mrphN, $feature) = @_;
    my $buf = '';
    $buf .= join('', (map { $_->midasi } ($knpResult->mrph)), "\n");
    $buf .= "$feature\n";
    $buf .= $mrphP->spec if (defined($mrphP));
    $buf .=  "!" . $mrph->spec;
    $buf .= $mrphN->spec if (defined($mrphN));
    $buf .= "\n\n";
    Egnee::Logger::info($buf);
}

our $stopWordList = {
#    'いう-言う/よい-<動詞:基本形>' => 1, # 「というX」
    'よい-良い/よい-<イ形容詞:基本連用形>' => 2, #  副詞「よく」と曖昧
    'さらだ-新だ/さらだ-<ナ形容詞:ダ列文語連体形>' => 3, # 「更なる」がない
    'かける-懸ける/かける-<動詞:タ系連用テ形>' => 4, # 〜にかけてX
    'とる-取る/とる-<動詞:タ系連用テ形>' => 5, # 〜にとってX
    'せめる-攻める/せめる-<動詞:タ系連用テ形>' => 6, # 副詞「せめて」と曖昧
    'つく-付く/つく-<動詞:タ系連用テ形>' => 7, # 機能表現「ついて」
    'たつ-建つ/たつ-<動詞:音便条件形>' => 8, # Xたちゃ の誤認識

    '合せる-合わせる/あわせる-<動詞:基本連用形>' => 9, # 「合す」:子音動詞サ行との曖昧性
    '合わす-合わす/あわす-<動詞:命令形>' => 9, 

    'ため-為/ため-<副詞的名詞>' => 20,
    'おかげ-お陰/おかげ-<副詞的名詞>' => 21,
    'あと-後/あと-<副詞的名詞>' => 22,
    '何時も/いつも-<副詞>' => 23,

    'しがらむ-柵む/しがらむ-<動詞:基本連用形' => 30, # 「柵み」とは絶対に書かない
    'からに-辛煮/からに-<普通名詞>' => 31, # からには
};
our $stopWordMidasiList = {
    'いる' => 1,
    'ある' => 2, # 「連体詞」と曖昧
    'なる' => 3,
    'ない' => 4,
    'いう' => 5,

    'わかる' => 6,
    'わたる' => 7,
    'おける' => 8, # 「置ける」のみの登録で、「於ける」が登録されていないバイアス
    'につく' => 9, # 「、について」という表現が論文に多い
    'やる' => 9,   # 対応するのは「遣る」だけではない
    'なれる' => 9, # 「成れる」がない

    # 副詞
    'ごく' => 10,
    'まず' => 11,
    'ただ' => 12,
    'また' => 13,

    'まじめだ' => 100,
    'ずさんだ' => 101,

    # カタカナ
    # 'ページ' => 200, # 頁
    'ぼかす' => 200, # 暈す/ぼかす
};

# 付け焼き刃
sub isStopWord {
    foreach my $w (@_) {
	next unless (defined($w));

	return 1 if ($stopWordList->{$w});

	my ($midasi, $repname, $class) = split(/-/, $w);
	if ($repname) {
	    $midasi = (split(/\//, $repname))[1];
	}
	return 1 if ($stopWordMidasiList->{$midasi});
    }
    return 0;
}

1;
