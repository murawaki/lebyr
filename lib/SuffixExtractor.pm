package SuffixExtractor;

use strict;
use warnings;
use utf8;

use Egnee::Logger;
use MorphemeUtilities;
use MorphemeGrammar;

our $bnstMaxLength = 15; # 文節の最大長によるノイズ除去; -1 のときは制限なし

# 獲得対象の自立語
our $usedHinsi = { '動詞' => 1, '名詞' => 2, '形容詞' => 3 };

# 文節末から探索して、マッチしたら破棄する自立語の品詞
our $badHinsi = { '副詞' => 1, 
		  '未定義語' => 2,  # filter を使わない場合用
};


sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift
    };
    # default settings
    $self->{opt}->{markAcquired} = 0  unless (defined($self->{opt}->{markAcquired}));
    $self->{opt}->{excludeDoukei} = 0 unless (defined($self->{opt}->{excludeDoukei}));
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}


# SentenceBasedAnalysisObserverRegistry に登録しているので、document が渡される
# sub onDocumentChange {
#     my ($self, $document) = @_;
# }

# SentenceBasedAnalysisObserverRegistry に登録しているので、sentence が渡される
sub onSentenceAvailable {
    my ($self, $sentence) = @_;

    my $knpResult = $sentence->get('knp');
    # 不適書くな文は除く
    return if ($self->isNoisySentence($knpResult));

    my @bnstList = $knpResult->bnst;
    for (my $i = 0, my $iL = scalar(@bnstList); $i < $iL; $i++) {
	my $bnst = $bnstList[$i];
	my $bnstN = $bnstList[$i + 1];

	my ($mrphS, $startPoint, $opOpt) = $self->getTargetMrph($bnst);
	next unless (defined($mrphS));

	my $struct = $self->extractSuffix($mrphS, $startPoint, $bnst, $bnstN, $opOpt);
	if (defined($struct)) {
	    no warnings 'syntax';
	    # suffix TAB 品詞 TAB 活用形 TAB 原形 TAB 追加情報
	    printf("%s\t%s\t%s\t%s\t%s\n",
		   $struct->{suffix},
		   $struct->{posS},
		   $struct->{katuyou2},
		   $struct->{genkei},
		   $struct->{additional} || '');

	    # 次の文節を飛ばす
	    if ($struct->{doSkipNext}) {
		$i++;
	    }
	}
    }
}

#
# suffix 抽出対象の自立語を文節から探す
#
sub getTargetMrph {
    my ($self, $bnst, $opt) = @_;

    # $opt:
    #  all:  副詞、未定義語も対象にする

    my @mrphList = $bnst->mrph;
    my $startPoint = -1;
    my $mrphS; # 自立語形態素
    my $doCheckNextBnst = 1; # 次の文節を suffix に加えるチェックをするか

    # 末尾から前へ
    # マッチしたら return
    # 閉じ括弧などによって若干の取りこぼしがあるかも知れないが
    # 無視できる範囲
    for (my $j = $#mrphList; $j >= 0; $j--) {
	my $mrph = $mrphList[$j];

	if ($mrph->hinsi eq '接尾辞' || $mrph->hinsi eq '特殊') {
	    $doCheckNextBnst = 0;
	    next;
	}
	if ($mrph->fstring =~ /<付属>/) {
	    # 「する」などを例外視する
	    if ($mrph->fstring =~ /\<付属動詞候補/) {
		$doCheckNextBnst = 0;
	    }
	    next;
	}

	# 品詞変更を差し戻す
	my $mrphO = &MorphemeUtilities::getOriginalMrph($mrph);
	my $hinsi = $mrphO->hinsi;

	# いきなり接頭辞が来ることはないと思うが一応
	if ($hinsi eq '接頭辞') {
	    return undef;
	}

	if ($usedHinsi->{$hinsi} || $badHinsi->{$hinsi}) {
	    my $posS;
	    unless ($badHinsi->{$hinsi}) { # 論外なら最初から調べない
		$posS = &MorphemeGrammar::getPOSName($mrphO);
	    }

	    # 獲得対象外の動詞など
	    unless (defined($posS)) {
		return undef unless ($opt->{all});
	    }
	    if ($self->{opt}->{excludeDoukei}) {
		return undef unless ($self->isSafeDoukei($mrphO, $posS));
	    }

	    $startPoint = $j;
	    $mrphS = $mrphO;
	    # $mrphO ではなく $mrph を調べて品詞変更で名詞化している場合も対象にする
	    unless ($mrph->hinsi eq '名詞' || $mrphS->katuyou1 eq 'ナ形容詞') {
		$doCheckNextBnst = 0;
	    }
	    return ($mrphS, $startPoint,
		    { posS => $posS,
		      doCheckNextBnst => $doCheckNextBnst });
	}
    }
    return undef;
}

# make sure that all doukei mrphs has the same POS
sub isSafeDoukei {
    my ($self, $mrphO, $posS) = @_;

    foreach my $doukei ($mrphO->doukei) { # can be empty
	my $posS2 = &MorphemeGrammar::getPOSName($doukei);
	return 0 if (!defined($posS2) || $posS ne $posS2);
    }
    return 1;
}

#
# $startPoint 以降の形態素を合成して suffix を作る
# ここでは個々の形態素が付属語か否かはチェックしない
#
sub extractSuffix {
    my ($self, $mrphS, $startPoint, $bnst, $bnstN, $opOpt) = @_;

    my ($gokan, $gobi) = &MorphemeUtilities::decomposeKatuyou($mrphS);
    my $katuyou2 = ($mrphS->katuyou2)? $mrphS->katuyou2 : '*';

    # 前から後ろに付属語をつなげる
    # my $mrph = $mrphList[$startPoint];
    # my @posStack = ($mrph->hinsi);
    my @mrphList = $bnst->mrph;
    my $suffix = $gobi;
    for (my $j = $startPoint + 1, my $jL = scalar(@mrphList); $j < $jL; $j++) {
	my $mrphN = $mrphList[$j];

	# 後付け設定
	# 名詞に活用形の代替物を設定する
	if ($j == $startPoint + 1 && $katuyou2 eq '*') {
	    $katuyou2 = $mrphN->genkei;
	}

	# 追加前に終了する条件
	# ここに載せる条件は
	# $doCheckNextBnst == 0
	# となっているのを確認すべき
	last if ($mrphN->hinsi eq '特殊');

	$suffix .= $mrphN->midasi;
    }
    my $skipNextFlag = 0;
    if ($opOpt->{doCheckNextBnst} && $bnstN) {
	my ($suffix2, $katuyou22) = &mergeNextBnst($suffix, $bnstN);
	if ($suffix ne $suffix2) {
	    $skipNextFlag = 1; # skip one bunsetsu loop

	    $suffix = $suffix2;
	    $katuyou2 = $katuyou22 if ($katuyou2 eq '*');
	}
    }
    # 打ち切りにより空になることがある
    if (length ($suffix) > 0) {
	my $struct = {
	    suffix => $suffix,
	    katuyou2 => $katuyou2,
	    genkei => $mrphS->genkei,
	    doSkipNext => $skipNextFlag
	};
	# mark acquired morphemes with '*'
	if ($self->{opt}->{markAcquired}
	    && $mrphS->imis =~ /自動獲得/) {
	    $struct->{genkei} .= '*';
	}
	if ($opOpt->{posS}) {
	    $struct->{posS} = $opOpt->{posS};
	    $struct->{additional} = &MorphemeGrammar::getSubPOSName($mrphS, $opOpt->{posS});
	}
	return $struct;
    }
    return undef;
}


# ;;; 「計画をする」「変換をやる」「紹介を行う」
# ( ( ?* < ( ?* [名詞 * * * * ((サ変))] [助詞 * * * を] [特殊]* ) > ) ( < ( [* * * * (する できる やる 行う 行なう)] ?* ) > ) ( ?* ) 
#   Ｔマージ← &形態素付属化 &伝搬:-1:係 &伝搬:-1:レベル &伝搬:-1:ID &伝搬:-1:Ｔ基本句分解 )
# 
# ;;; 「変換ができる」
# ( ( ?* < ( ?* [名詞 * * * * ((サ変))] [助詞 * * * が] [特殊]* ) > ) ( < ( [* * * * (できる)] ?* ) > ) ( ?* ) 
#   Ｔマージ← &形態素付属化 &伝搬:-1:係 &伝搬:-1:レベル &伝搬:-1:ID &伝搬:-1:Ｔ基本句分解 )
#
# する できる やる 行う 行なう
# できる
# なる
our $postprocessVerbs = {
    'する' => 1,
    'できる' => 1,
    'やる' => 1,
    '行う' => 1,
    '行なう' => 1,
    'なる' => 2,
};

# サ変名詞の直後のみ付属語になるもの
# ( ( ?* [* * * * * ((サ変))] [特殊 括弧終]* )
#         ( [動詞 * * * (する 出来る できる 致す いたす 為さる なさる 
#                        下さる くださる 頂く いただく 頂ける いただける 
#                        願う ねがう 願える ねがえる)] )
#         ( ?* ) 付属 )
# ( ( ?* [* * * * * ((サ変))] [特殊 括弧終]* )
#         ( [形容詞 * * * (可能だ 不可能だ)] ) ( ?* ) 付属 )
#
# すぎる/過ぎる はナノ形容詞の前では動詞性接尾辞だが名詞のあとでは動詞
# 要検討: がる (「刈る」と解釈される)
#
our $sahenFuzoku = {
    '動詞' => {
	'する' => 1, '出来る' => 2, 'できる' => 2, '致す' => 3, 'いたす' => 3,
	'為さる' => 4, 'なさる' => 4, '下さる' => 5, 'くださる' => 5,
	'頂く' => 6, 'いただく' => 6, '頂ける' => 7, 'いただける' => 7,
	'願う' => 8, 'ねがう' => 8, '願える' => 9, 'ねがえる' => 9,

	'すぎる' => 10, '過ぎる' => 11,
    },
    '形容詞' => {
	'可能だ' => 1, '不可能だ' => 2,
    },
};

sub mergeNextBnst {
    my ($suffix, $bnst) = @_;

    my @mrphList = $bnst->mrph;
    my $mrphS = $mrphList[0];
    if (length($suffix) > 0) {
	# postprocess で「サ変名詞」が特別扱いされる
	# 長さ優先の suffix matching においてバイアスになるので、
	# 他の候補も長さをのばす
	return $suffix unless ($postprocessVerbs->{$mrphS->genkei});
    } else {
	# サ変名詞に後続する場合のみに付属語扱いされるバイアスの対策
	my $tmp = $sahenFuzoku->{$mrphS->hinsi};
	return $suffix unless (defined($tmp) && defined($tmp->{$mrphS->genkei}));
    }

    for (my $j = 0, my $jL = scalar(@mrphList); $j < $jL; $j++) {
	my $mrphN = $mrphList[$j];

	# 追加前に終了する条件
	last if ($mrphN->hinsi eq '特殊');
	$suffix .= $mrphN->midasi;
    }
    # mergeNextBnst が呼び出されるのは名詞とナ形容詞
    # ナ形容詞の場合は活用形がある。
    # 従って、katuyou2 ではなく genkei を活用形として返す
    return ($suffix, $mrphS->genkei);
}

# TODO: UnknwownWordDetector#isNoisySentence との統合
#
#
# 使いたくない文を排除する
# 戻り値: 1: 採用
#         0: 不採用
sub isNoisySentence {
    my ($self, $knpResult) = @_;

    my @bnstList = $knpResult->bnst;
    my $yougenCount = 0;

    # 文字化け対策
    if ($knpResult->spec =~ /\\x[0-9A-F]{2}/m) {
	Egnee::Logger::warn("corrupt knp result\n");
	return 1;
    }

    for (my $i = 0, my $iL = scalar(@bnstList); $i < $iL; $i++) {
	my $bnst = $bnstList[$i];
	my @mrphList = $bnst->mrph;

	my $bnstLength = 0;
	for (my $j = 0, my $jL = scalar(@mrphList); $j < $jL; $j++) {
	    my $mrph = $mrphList[$j];
	    my $midasi = $mrph->midasi; 

	    ####################################################
	    #                                                  #
	    #  一つでもマッチする形態素があると排除する条件群  #
	    #                                                  #
	    ####################################################
	    return 1 if ($midasi eq '　'); # ノイズの原因となるので全角スペースを含む文は一律排除
	    return 1 if ($mrph->fstring =~ /\<自動認識\>/); # オノマトペの自動認識も怪しい
	    return 1 if ($mrph->fstring =~ /\<小文字化\>/);   # JUMAN による非正規表現への対応
	    return 1 if (&MorphemeUtilities::isUndefined($mrph));
	    # 動詞性接尾辞「る」がタ系連用テ形以外に後続する時は未知語のはず
	    my $mrphPrev;
	    return 1 if ($j > 0 && ($mrphPrev = $mrphList[$j - 1])
			 && $mrphPrev->katuyou2 ne 'タ系連用テ形'
			 && $mrph->bunrui eq '動詞性接尾辞'
			 && $mrph->genkei eq 'る');
	    # 形容詞性名詞接尾辞「い」は未定義語にしか後続しないので
	    # この条件が有効になることはないと思われるが、一応残す
	    return 1 if ($mrph->bunrui eq '形容詞性名詞接尾辞'
			 && $mrph->genkei eq 'い');

	    $bnstLength += length($midasi);
	    $yougenCount++ if ($mrph->hinsi eq '動詞' || $mrph->hinsi eq '形容詞');

	}
	# 1 文節が長過ぎるものは排除
	return 1 if ($bnstLength > $bnstMaxLength && $bnstMaxLength > 0);
    }
    # 動詞が含まれていない文は多分変
    return 1 if ($yougenCount <= 0);
    return 0;
}

1;
