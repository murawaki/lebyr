#!/usr/bin/env perl
#
# load JUMAN's manually constructed dictionary, and
# aggregate morphemes by repname
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Storable qw/nstore/;
use Dumpvalue;

use MorphemeUtilities;
use JumanDictionary::Static;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# keep: store deleted repnames (for debugging)
my $opt = {};
GetOptions($opt, 'output=s', 'keep', 'debug');

my $mainDicDir = '/home/murawaki/research/lebyr/data/dic';
my $mainDictionary = JumanDictionary::Static->new($mainDicDir);

my $stopRepnameList = {
    '頁/ぺーじ' => 1,
    'Ｔシャツ/てぃーしゃつ' => 1,

    '何/なに' => 10, # 数詞「何 (なん)」と被る

    '着熟す/きこなす' => 50,

    # adverbs
    '皆/みんな' => 100,
    '共に/ともに' => 101,
    '正に/まさに' => 102,
    '殊に/ことに' => 103,
    '余り/あまり' => 104,

    # adverb onomatopoeia
    'ふわり/ふわり' => 150, # ふんわり も
    'シュン/しゅん' => 160,
    'ストン/すとん' => 160,
};

# type
my $ALLKANJI = 1;
my $ALLHIRAGANA = 2;
my $ALLKATAKANAALPHA = 4;
my $OTHERS = 8;

my $KANJIVERB_AGAINST_KATAKANA = 16;

my $NAMETYPE_SHIFT = 6;

my $adverbList = {}; # debug

# load MorphemeEntry with some filtering
my ($repnameList, $gobiLengthList) = &loadMEList($mainDictionary);

my $deleted = {};
foreach my $repname (keys(%$repnameList)) {
    my @nameList = keys(%{$repnameList->{$repname}});
    if (scalar(@nameList) <= 1) {
	# no orthographic variant
	printf("drop %s (no variant)\n", $repname) if ($opt->{debug});

	delete($repnameList->{$repname});
	next;
    }

    my $gobiLength = $gobiLengthList->{$repname};

    my $allOne = 1;           # スコアが 1 以下のみ

    my $longHiragana = 0;
    my $allHiragana = 1;      # ひらがな表記のみ e.g. そこら
    my $allKatakanaAlpha = 1; # カタカナ・アルファベット表記のみ

    my $katakanaVerbList = [];
    my $kanjiVerbList = [];

    my @nameTypeList;
    foreach my $name (@nameList) {
	my $stem = substr($name, 0, length($name) - $gobiLength);
	my $nameType = &getNameType($stem);

	$repnameList->{$repname}->{$name} += $nameType << $NAMETYPE_SHIFT;

	$allHiragana = 0 if ($nameType != $ALLHIRAGANA);
	$allKatakanaAlpha = 0 if ($nameType != $ALLKATAKANAALPHA);

	if ($gobiLength > 0) {
	    if ($nameType == $ALLKATAKANAALPHA) {
		push(@$katakanaVerbList, $name);
	    } elsif ($nameType != $ALLHIRAGANA) {
		push(@$kanjiVerbList, $name);
	    }
	}

	if ($nameType eq $ALLHIRAGANA) {
	    $longHiragana = (length($stem) >= 4)? 1 : 0;
	}

	$allOne = 0 if ($repnameList->{$repname}->{$name} > 1);
	push(@nameTypeList, $nameType);
    }

    # おちる, オチる, 落ちる について「落ちる」は信頼できる
    if (scalar(@$katakanaVerbList) > 0 && scalar (@$kanjiVerbList) > 0) {
	foreach my $name (@$kanjiVerbList) {
	    $repnameList->{$repname}->{$name} += $KANJIVERB_AGAINST_KATAKANA << $NAMETYPE_SHIFT;
	}
    }

    if ($allKatakanaAlpha || $allHiragana) {
	# カタカナ表記のみ
	printf ("drop %s (all %s)\n", $repname, ($allKatakanaAlpha)? 'katakana-alphabet' : 'hiragana') if ($opt->{debug});

	$deleted->{$repname} = $repnameList->{$repname} if ($allHiragana);
	delete($repnameList->{$repname});
	next;	
    }

    if ($allOne) {
	# すべての表記のスコアが 1 以下

	# ひらがなが十分に長い
	# 語幹が 2 以下なら調べる
	my $longFlag = 1;
	for (my $i = 0; $i < scalar(@nameList); $i++) {
	    if ($nameTypeList[$i] == $ALLHIRAGANA &&
		length($nameList[$i]) - $gobiLength < 3) {
		$longFlag = 0;
	    }
	}

	if ($longFlag) {
	    printf("drop %s (unambiguous)\n", $repname) if ($opt->{debug});

	    $deleted->{$repname} = $repnameList->{$repname};
	    delete($repnameList->{$repname});
	    next;
	} else {
	    printf("keep %s (ambiguous)\n", $repname) if ($opt->{debug});
	}
    }
    if ($longHiragana) {
	printf("drop %s (long hiragana)\n", $repname) if ($opt->{debug});

	$deleted->{$repname} = $repnameList->{$repname};
	delete($repnameList->{$repname});
	next;	
    }
}

if ($opt->{debug}) {
    print("adverb list\n");
    foreach my $repname (keys(%$adverbList)) {
	next unless ($repnameList->{$repname});
	print("\t$repname\n");
	Dumpvalue->new->dumpValue($repnameList->{$repname});
	print("\n");
    }
}

if ($opt->{debug}) {
    Dumpvalue->new->dumpValue($repnameList);
}

if ($opt->{keep}) {
    $repnameList->{deleted} = $deleted;
}

if ($opt->{output}) {
    nstore($repnameList, $opt->{output}) or die;
}



sub loadMEList {
    my ($mainDictionary) = @_;

    my $repnameList = {};
    my $gobiLengthList = {};

    # 複数の箇所で同じ代表表記が定義されているかもしれないので、
    # 最初に全部読み込む
    foreach my $me (@{$mainDictionary->getAllMorphemes}) {
	next if (&isBadME($me));

	my $repname = $me->{'意味情報'}->{'代表表記'};
	if ($stopRepnameList->{$repname}) {
	    printf("drop %s (stop word)\n", $repname) if ($opt->{debug});	    
	    next;
	}

	if ($me->{'品詞'} eq '副詞') {
	    $adverbList->{$repname} = 1;

	    if ($repname =~ /^\p{Katakana}\p{Katakana}リ\//) {
		printf("drop %s (onomatopoeia)\n", $repname) if ($opt->{debug});	    
		next;
	    }
	    if ($repname =~ /^\p{Katakana}\p{Katakana}と\//) {
		printf("drop %s (onomatopoeia)\n", $repname) if ($opt->{debug});	    
		next;
	    }
	}

	foreach my $midasi (keys(%{$me->{'見出し語'}})) {
	    $repnameList->{$repname}->{$midasi} = $me->{'見出し語'}->{$midasi};
	}

	# 語尾の長さを調べておく
	if ($me->{'品詞'} eq '動詞' || $me->{'品詞'} eq '形容詞') {
	    my $repnameA = (split(/\//, $repname))[0];
	    my $mrph = $me->getJumanMorpheme($repnameA);
	    my ($stem, $ending) = &MorphemeUtilities::decomposeKatuyou($mrph);
	    $gobiLengthList->{$repname} = length($ending);
	} else {
	    $gobiLengthList->{$repname} = 0;
	}
    }
    return ($repnameList, $gobiLengthList);
}


# 対象外の ME を除く
sub isBadME {
    my ($me) = @_;

    # 備考
    # 名詞性名詞接尾辞には ｋｍ など特殊なものがある

    return 1 unless (defined($me->{'意味情報'}->{'代表表記'}));
    if (defined($me->{'品詞細分類'})) {
	return 1 if ($me->{'品詞細分類'} eq '人名');
	return 1 if ($me->{'品詞細分類'} eq '地名');
	return 1 if ($me->{'品詞細分類'} eq '組織名');
	return 1 if ($me->{'品詞細分類'} eq '固有名詞');
    }
    return 0;
}

sub getNameType {
    my ($str) = @_;

    return $ALLKANJI    if ($str =~ /^\p{Han}+$/);
    return $ALLHIRAGANA if ($str =~ /^[\p{Hiragana}ー]+$/);
    return $ALLKATAKANAALPHA if ($str =~ /^[\p{Katakana}ーＡ-Ｚａ-ｚ０-９]+$/);
    return $OTHERS;
}

1;
