package JumanDictionary::MorphemeVariantChecker;
#
# identify some (not all) variant morphemes
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	mainDictionary => shift,
	workingDictionary => shift,
	unihan => shift,
	opt => shift,
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

# 可能動詞から基本動詞への変換
our $kanouE = {
    'え' => ['う', {'母音動詞' => 1, '子音動詞ワ行' => 2}],
    'け' => ['く', {'子音動詞カ行' => 1}],
    'せ' => ['す', {'子音動詞サ行' => 1}],
    'て' => ['つ', {'子音動詞タ行' => 1}],
    # 'ね': 「死ねる」だけ?
    # 'へ'
    'め' => ['む', {'子音動詞マ行' => 1}],
    'れ' => ['る', {'子音動詞ラ行' => 1}],
    'げ' => ['ぐ', {'子音動詞ガ行' => 1}],
    # 'ぜ'
    # 'で'
    'べ' => ['ぶ', {'子音動詞バ行' => 1}]
    # 'ぺ'
};

# $opt:
#     expandVariants: 基本動詞の情報を元に表記揺れを展開
# 可能動詞か否かを判定する
# 戻り値
#  1: 可能動詞: $me を書き換える
#  0: そうでない
sub checkKanouVerb {
    my ($self, $me, $opt) = @_;
    $opt = {} unless (defined($opt));

    my $mrph = $me->getJumanMorpheme;
    my $posS = &MorphemeGrammar::getPOSName($mrph);
    return 0 if ($posS ne '母音動詞');

    my $midasi = $mrph->genkei;
    my $l = length($midasi);
    return 0 if ($l <= 2);
    my $c = substr($midasi, $l -2, 1);
    # カタカナの場合はとりあえず無視
#     if ($c =~ /\p{Katakana}/) {
# 	$c = Unicode::Japanese->new($c)->kata2hira->getu;
#     }
    my $tmp = $kanouE->{$c};
    return 0 unless (defined($tmp));
    my ($kihonS, $kihonPOSList) = @$tmp;
    my $kihonMidasi = substr($midasi, 0, $l -2) . $kihonS;

    my $voc1 = $self->{mainDictionary}->getMorpheme
	($kihonMidasi, { '品詞' => '動詞', '活用型' => $kihonPOSList });
    my $voc2 = $self->{workingDictionary}->getMorpheme
	($kihonMidasi, { '品詞' => '動詞', '活用型' => $kihonPOSList });
    my $voc = [];
    push(@$voc, @$voc1) if (defined($voc1));
    push(@$voc, @$voc2) if (defined($voc2));
    return 0 if (scalar(@$voc) <= 0);
    return 0 if (scalar(@$voc) > 1); # 曖昧な時は何もしない

    my $kihonME = $voc->[0];

    # 読みがわかってなかった場合は、基本動詞の情報で補完
    unless ($me->{'読み'} =~ /^(\p{Hiragana}|ヴ)*$/) {
	if ($kihonME->{'読み'} =~ /^(\p{Hiragana}|ヴ)*$/) {
	    my $yomi = &makeKanouVerb($kihonME->{'読み'});
	    $me->{'読み'} = $yomi if (defined($yomi));
	}
    }

    # 代表表記も補完
    unless ($me->{'意味情報'}->{'代表表記'}) {
	if ($kihonME->{'意味情報'}->{'代表表記'}) {
	    my ($a1, $b1) = split(/\//, $kihonME->{'意味情報'}->{'代表表記'});
	    my $a2 = &makeKanouVerb($a1);
	    my $b2 = &makeKanouVerb($b1);
	    $me->{'意味情報'}->{'代表表記'} =  "$a2/$b2" if (defined($a2) && defined($b2));
	}
    }

    # 表記揺れも補完
    if ($opt->{expandVariants}) {
	my $midasiList = {};
	my $midasiFlag = 1;
	foreach my $midasi2 (keys(%{$kihonME->{'見出し語'}})) {
	    my $newMidasi = &makeKanouVerb($midasi2);
	    unless ($newMidasi) {
		$midasiFlag = 0;
		last;
	    }
	    # スコアも引き継ぐ
	    $midasiList->{$newMidasi} = $kihonME->{'見出し語'}->{$midasi2};
	}
	if ($midasiFlag) {
	    $me->{'見出し語'} = $midasiList;
	}
    } else {
	# スコアは引き継ぐ
	$me->{'見出し語'}->{$midasi} = $kihonME->{'見出し語'}->{$kihonMidasi};
    }

    # 意味情報: 可能動詞
    if ($kihonME->{'意味情報'}->{'代表表記'}) {
	$me->{'意味情報'}->{'可能動詞'} = $kihonME->{'意味情報'}->{'代表表記'};
    } else {
	$me->{'意味情報'}->{'可能動詞'} = "$kihonMidasi/". &MorphemeUtilities::makeYomiFromMidasi($kihonMidasi);
    }
    $me->{'意味情報'}->{'既知語帰着'} = '可能動詞';
    return 1;
}

our $u2e = {
    'う' => 'え', 'く' => 'け', 'す' => 'せ', 'つ' => 'て',
    # 'ぬ' => 'ね',
    # 'ふ' => 'へ',
    'む' => 'め', 'る' => 'れ',
    'ぐ' => 'げ',
    # 'ず' => 'ぜ',
    # 'づ' => 'で',
    'ぶ' => 'べ'
    # 'ぷ' => 'ぺ'
};

# 基本動詞の原形から可能動詞の原形を作る
sub makeKanouVerb {
    my ($oyomi) = @_;

    my $l = length($oyomi);
    my $c = substr($oyomi, $l - 1, 1);
    my $e = $u2e->{$c};
    return undef unless ($e);
    return substr($oyomi, 0, length ($oyomi) - 1) . $e . 'る';
}

sub checkKanjiVariants {
    my ($self, $me) = @_;

    my @midasiList = keys(%{$me->{'見出し語'}});
    return if (scalar(@midasiList) > 1);
    my $midasi = $midasiList[0];

    my $variants = $self->enumVariants($midasi);
    return unless (scalar(@$variants) > 0);

    my @voc = $self->findVariants($me, $variants);
    return if (scalar(@voc) == 0);

    if (scalar(@voc) > 1) {
	Egnee::Logger::info("! leave ambiguous entry\n");
	if ($self->{opt}->{debug}) {
	    foreach my $tmp (@voc) {
		my ($me2, $v) = @$tmp;
		Egnee::Logger::info("$midasi -> $v\n");
	    }
	}
	return;
    }

    my ($kihonME, $kihonMidasi) = @{$voc[0]};
    if (defined ($kihonME->{'品詞細分類'})) {
	# ひとまず人名、地名、組織名は無視
	return if ($kihonME->{'品詞細分類'} eq '人名');
	return if ($kihonME->{'品詞細分類'} eq '地名');
	return if ($kihonME->{'品詞細分類'} eq '組織名');

	# それ以外の細分類は基本動詞のものを流用
	$me->{'品詞細分類'} = $kihonME->{'品詞細分類'};
    }

    # 読みがわかってなかった場合は、基本動詞の情報で補完
    unless ($me->{'読み'} =~ /^(\p{Hiragana}|ヴ)*$/) {
	if ($kihonME->{'読み'} =~ /^(\p{Hiragana}|ヴ)*$/) {
	    $me->{'読み'} = $kihonME->{'読み'};
	}
    }
    
    # スコアも引き継ぐ
    $me->{'見出し語'}->{$midasi} = $kihonME->{'見出し語'}->{$kihonMidasi};

    foreach my $key (keys(%{$kihonME->{'意味情報'}})) {
	$me->{'意味情報'}->{$key} = $kihonME->{'意味情報'}->{$key};
    }

    $me->{'意味情報'}->{'既知語帰着'} = '異体字';
    Egnee::Logger::info("kanji variation: $midasi -> $kihonMidasi\n");
}

# 異体字による候補列挙 (組み合わせ)
sub enumVariants {
    my ($self, $midasi) = @_;

    my $unihan = $self->{unihan};
    my $variants = [];
    my @cList = split(//, $midasi);
    for (my $i = 0; $i < scalar(@cList); $i++) {
	my $c = $cList[$i];
	if ($unihan->{$c}) {
	    my @news = ();
	    foreach my $c2 (keys(%{$unihan->{$c}})) {
		foreach my $v (@$variants) {
		    my $v2 = substr($v, 0, $i) . $c2 . substr($v, $i + 1);
		    push(@news, $v2);
		}
		my $v2 = substr($midasi, 0, $i) . $c2 . substr($midasi, $i + 1);
		push(@news, $v2);
	    }
	    push(@$variants, @news);
	}
    }
    return $variants;
}

# 異表記が辞書にあるか調べる
sub findVariants {
    my ($self, $me, $variants) = @_;

    my $mainDictionary = $self->{mainDictionary};
    my $voc = {};
    foreach my $v (@$variants) {
	my $constraints = { '品詞' => $me->{'品詞'} };
	if ($me->{'品詞'} ne '名詞') { # 名詞の細分類は区別しない
	    $constraints->{'活用型'} = $me->{'活用型'};
	}
	my $voc2 = $mainDictionary->getMorpheme($v, $constraints);
	next unless (defined($voc2));
	foreach my $me2 (@$voc2) {
	    my $key = $me2->{'意味情報'}->{'代表表記'};
	    unless (defined($key)) {
		$key = (keys(%{$me2->{'見出し語'}}))[0] . ':' .
		    (defined($me->{'品詞細分類'}))? $me->{'品詞細分類'} : $me->{'活用型'};
	    }
	    $voc->{$key} = [$me2, $v]; # 重複対策
	}
    }
    return values(%$voc);
}

1;
