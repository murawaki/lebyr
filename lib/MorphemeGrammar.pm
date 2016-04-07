package MorphemeGrammar;
#
# specify the morphology-level grammar spec
#
use utf8;
use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw /$posList $posInclusion $separatorBunrui $separators $IMIS $entityTagList $fusanaID2pos/;

use Unicode::Japanese;

# semantic labels assigned to acquired morphemes
our $IMIS = {
    FUSANA => '普サナ識別',
    MAYBE_ADVERB => '副詞識別',
    NODECOMPOSITON => '分割禁止',
};

# "X末尾" tags assigned to suffix-like morphemes
# used for candidate enumeration
our $entityTagList = {
    '人名' => 1,
    '地名' => 2,
    '住所' => 3,
    '組織名' => 4
};

# morphemes that terminate rear boundary search
our $separatorBunrui = {
    '句点' => 1,
    '読点' => 2,
    '括弧始' => 3,
    '括弧終' => 4
};
# 特殊-記号 の中には、後方境界探索を打ち切ると微妙な例が含まれるので、独自に列挙する
# Unicode への変換が怪しい
# val: 1: open
#      2: closed
#      3: others
our $separators = {
    '≪' => 1, # shift
    '≫' => 2, # shift
    '\：' => 3,
    '；' => 3,
    '？' => 3,
    '！' => 3,
    '\／' => 3,
    '\\' => 3,
    '…' => 3
};

# POS tagset for acquisition
#   constraints: 満たすべき JUMAN の文法制約
#       複数指定した場合は、値の小さいものがデフォルト
#   bareStem: 語幹単独で出現できるか
#   stemConstraints: 語幹の制約を記述したサブルーチン
#       引数は $stem。
#
# その他の品詞:
#   時相名詞などが特殊な場合に付与される
our $posList = {
    '母音動詞' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '母音動詞' => 1 }
		     },
	stemConstraints => \&isVowelVerb,
	bareStem => 1
    },
    '子音動詞カ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞カ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞ガ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞ガ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞サ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞サ行' => 1 }
		     }
	# 制約なし
    },
    '子音動詞タ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞タ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞バ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞バ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞マ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞マ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞ラ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞ラ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    '子音動詞ワ行' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { '子音動詞ワ行' => 1 }
		     },
	stemConstraints => \&isConsonantVerb
    },
    'サ変動詞' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { 'サ変動詞' => 1 }
		     },
	stemConstraints => \&isSahenVerb
    },
    'ザ変動詞' => {
	constraints => { hinsi => { '動詞' => 1 },
			 katuyou1 => { 'ザ変動詞' => 1 }
		     }
    },
    'イ形容詞' => {
	constraints => { hinsi => { '形容詞' => 1 },
			 katuyou1 => { 'イ形容詞アウオ段' => 1, 'イ形容詞イ段' => 2 }
		     },
	stemConstraints => \&isIAdjective,
	internalAmbiguity => 'katuyou1',
	# イ形容詞も語幹単独で出現し得るが、感動詞的用法に限られるので除外
	# 単独ではないが、複合語の一部として語幹が出てくることはある
    },
    '普通名詞' => {
	constraints => { hinsi => { '名詞' => 1 },
			 bunrui => { '普通名詞' => 1, 'サ変名詞' => 2 }
		     },
	meMatchConstraints => { '品詞' => { '名詞' => 1, '副詞' => 2 } },
	bareStem => 1,
	internalAmbiguity => 'bunrui',
	fusana => 1,
	maybeAdverb => 1,
    },
    '副詞' => {
	constraints => { hinsi => { '副詞' => 1 },
		     },
	meMatchConstraints => { '品詞' => { '名詞' => 1, '副詞' => 2 } }, # 一応
	bareStem => 1,
	fusana => 1,
	maybeAdverb => 1,
    },
    'ナ形容詞' => {
	constraints => { hinsi => { '形容詞' => 1 },
			 katuyou1 => { 'ナ形容詞' => 1, 'ナノ形容詞' => 2 }
		     },
	bareStem => 1,
	internalAmbiguity => 'katuyou1',
	fusana => 1,
	maybeAdverb => 1,
    },
};

# 包含関係にあると認められる品詞の組
our $posInclusion = {
    '普通名詞' => {
	'ナ形容詞' => 2,
	'母音動詞' => 3,
	'副詞' => 4,
    }
};

our $fusanaID2pos = ['普通名詞', 'サ変名詞', 'ナ形容詞', 'ナノ形容詞'];

# 「品詞」から引く
our $posPerHinsi = {};
while ((my ($posS, $struct) = each(%$posList))) {
    my $hinsiList = $struct->{constraints}->{hinsi};
    foreach my $hinsi (keys(%$hinsiList)) {
	push(@{$posPerHinsi->{$hinsi}}, $posS);
    }
}


# 形態素に対応する MorphemeGrammar の品詞を返す
# 暫定的に特殊な名詞は普通名詞扱い
sub getPOSName {
    my ($mrph, $level) = @_;
    $level = 0 unless (defined($level));

    # サ変動詞「する」を例外とする
    return undef if (($mrph->repname || '') eq 'する/する');

    # 品詞で絞り込んで高速化
    my $hinsi = $mrph->hinsi;
    my $posListLimited = $posPerHinsi->{$hinsi};
    foreach my $posS (@$posListLimited) {
	if (&matchMrph2Constraints($mrph, $posList->{$posS}->{constraints})) {
	    if ($level == 0) {
		return $posS;
	    } else {
		my $subPOS = &getSubPOSName($mrph, $posS);
		return (defined($subPOS))? $subPOS : $posS;
	    }
 	}
    }
    return '普通名詞' if ($hinsi eq '名詞');
    return undef;
}

sub getSubPOSName {
    my ($mrph, $posS) = @_;

    my $struct = $posList->{$posS};
    return unless (defined($struct));
    my $type = $struct->{internalAmbiguity};
    return unless (defined($type));
    if ($type eq 'bunrui') {
	return $mrph->bunrui;
    } elsif ($type eq 'katuyou1') {
	return $mrph->katuyou1;
    } else {
	return;
    }
}

# 形態素が制約を満たすか調べる
sub matchMrph2Constraints {
    my ($mrph, $constraints) = @_;

  outer:
    foreach my $type (keys(%$constraints)) {
	# do not use 'each' as the iteration might not reach end
	my $valList = $constraints->{$type};
	my $mval = $mrph->$type || '';
	foreach my $cval (keys(%$valList)) {
	    next outer if ($mval eq $cval);
	}
	return 0;
    }
    return 1;
}


our $iHiragana = {
    'い' => 1, 'き' => 2, 'し' => 0, 'ち' => 4, 'に' => 5, # 「し」は除外 サ変動詞を 「〜しる」とする副作用を防ぐため
    'ひ' => 6, 'み' => 7, 'り' => 8, 'ぎ' => 9, 'じ' => 10,
    'ぢ' => 11, 'び' => 12, 'ぴ' => 13
};
our $eHiragana = {
    'え' => 1, 'け' => 2, 'せ' => 3, 'て' => 4, 'ね' => 5,
    'へ' => 6, 'め' => 7, 'れ' => 8, 'げ' => 9, 'ぜ' => 10,
    'で' => 11, 'べ' => 12, 'ぺ' => 13
};

# 母音動詞の語幹は i か e でおわるという制約のチェック
sub isVowelVerb {
    my ($stem) = @_;

    # 語幹の最後の一文字
    my $c = substr($stem, length($stem) - 1, 1);
    if ($c =~ /\p{Hiragana}/) {
	; # そのまま
    } elsif ($c =~ /\p{InKatakana}/) {
	# \p{Katakana} だと「ー」が含まれない
	# the following characters belong to Common
	# 309B..309C KATAKANA-HIRAGANA VOICED SOUND MARK..KATAKANA-HIRAGANA SEMI-VOICED SOUND MARK
	# 30A0       ゠ KATAKANA-HIRAGANA DOUBLE HYPHEN
	# 30FB       ・ KATAKANA MIDDLE DOT
        # 30FC       ー KATAKANA-HIRAGANA PROLONGED SOUND MARK
	$c = Unicode::Japanese->new ($c)->kata2hira->getu;
    } else {
	# ok for characters with unknown reading
	return 1;
    }
    return ($iHiragana->{$c} || $eHiragana->{$c})? 1 : 0;
}

# 漢語由来の子音動詞サ行以外の動詞は「っ」、「ん」、「ー」で終らない
sub isConsonantVerb {
    my ($stem) = @_;

    return ($stem =~ /[ッンっんー]$/)? 0 : 1;
}

# イ形容詞: 「さむーい」を一応許容
sub isIAdjective {
    my ($stem) = @_;

    return ($stem =~ /[ッンっん]$/)? 0 : 1;
}

# 獲得対象のサ変動詞は1文字漢語に限定
sub isSahenVerb {
    my ($stem) = @_;
    return 0 if (length($stem) > 1);
    return ($stem =~ /\p{Han}/)? 1 : 0;
}

sub isPOSConsistent {
    my ($hinsi1, $bunrui1, $type1, $hinsi2, $bunrui2, $type2) = @_;

    if (($hinsi1 eq '名詞' or ($bunrui1 || '') =~ /ナノ?形容詞/)
	and ($hinsi2 eq '名詞' or ($bunrui2 || '') =~ /ナノ?形容詞/)) {
	return 1;
    }
    return 0 if ($hinsi1 ne $hinsi2);
    return 0 if (defined($bunrui1) and $bunrui1 ne $bunrui2);
    if (defined($type1)) {
	return 1 if ($type1 eq $type2);
	return 1 if ($type1 =~ /^ナノ?形容詞$/ and $type2 =~ /^ナノ?形容詞$/);
	return 1 if ($type1 =~ /^イ形容詞/ and $type2 =~ /^イ形容詞/);
	return 0;
    } else {
	return 1;
    }
}

1;
