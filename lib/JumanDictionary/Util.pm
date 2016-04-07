package JumanDictionary::Util;

use strict;
use warnings;
use utf8;

use List::Util qw/min/;
use Unicode::Japanese;


our $hira2roman = {
                   'ぁ' => 'aa.', 'あ' => 'a.',  'ぃ' => 'ii.', 'い' => 'i.',  'ぅ' => 'uu.', 'う' => 'u.',  'ぇ' => 'ee.',
    'え' => 'e.',  'ぉ' => 'oo.', 'お' => 'o.',  'か' => 'ka.', 'が' => 'ga.', 'き' => 'ki.', 'ぎ' => 'gi.', 'く' => 'ku.',
    'ぐ' => 'gu.', 'け' => 'ke.', 'げ' => 'ge.', 'こ' => 'ko.', 'ご' => 'go.', 'さ' => 'sa.', 'ざ' => 'za.', 'し' => 'si.',
    'じ' => 'zi.', 'す' => 'su.', 'ず' => 'zu.', 'せ' => 'se.', 'ぜ' => 'ze.', 'そ' => 'so.', 'ぞ' => 'zo.', 'た' => 'ta.',
    'だ' => 'da.', 'ち' => 'ti.', 'ぢ' => 'di.', 'っ' => 'Q.',  'つ' => 'tu.', 'づ' => 'du.', 'て' => 'te.', 'で' => 'de.',
    'と' => 'to.', 'ど' => 'do.', 'な' => 'na.', 'に' => 'ni.', 'ぬ' => 'nu.', 'ね' => 'ne.', 'の' => 'no.', 'は' => 'ha.',
    'ば' => 'ba.', 'ぱ' => 'pa.', 'ひ' => 'hi.', 'び' => 'bi.', 'ぴ' => 'pu.', 'ふ' => 'hu.', 'ぶ' => 'bu.', 'ぷ' => 'pu.',
    'へ' => 'he.', 'べ' => 'be.', 'ぺ' => 'pe.', 'ほ' => 'ho.', 'ぼ' => 'bo.', 'ぽ' => 'po.', 'ま' => 'ma.', 'み' => 'mi.',
    'む' => 'mu.', 'め' => 'me.', 'も' => 'mo.', 'ゃ' => 'Ya.', 'や' => 'ya.', 'ゅ' => 'Yu.', 'ゆ' => 'yu.', 'ょ' => 'Yo.',
    'よ' => 'yo.', 'ら' => 'ra.', 'り' => 'ri.', 'る' => 'ru.', 'れ' => 're.', 'ろ' => 'ro.', 'ゎ' => 'Wa.', 'わ' => 'wa.',
    'ゐ' => 'wi.', 'ゑ' => 'we.', 'を' => 'wo.', 'ん' => 'N.',
    # 'ー' => 'R.',
    'ヵ' => 'Ka.', 'ヴ' => 'vu.',
};

our $replaceList = [
    # DEFAULT: 1.0
    ['ー', '〜', 0.2],
    ['ー', '～', 0.2],
    ['〜', '～', 0.2], # 301C FF5E
    ['あ', 'ぁ', 0.3],
    ['い', 'ぃ', 0.3],
    ['う', 'ぅ', 0.3],
    ['え', 'ぇ', 0.3],
    ['お', 'ぉ', 0.3],
    ['わ', 'ゎ', 0.3],
    ['か', 'ヵ', 0.3], # no hiragana counterpart
    ['つ', 'っ', 0.5],
    ['や', 'ゃ', 0.3],
    ['ゆ', 'ゅ', 0.3],
    ['よ', 'ょ', 0.3],
];

our $replaceScore = {};
foreach my $tmp (@$replaceList) {
    my ($a, $b, $cost) = @$tmp;
    $replaceScore->{$a}->{$b} = $replaceScore->{$b}->{$a} = $cost;
}

our $longSignList = { 'ー' => 1, '～' => 1, '〜' => 1 };
our $prolongedList = { # pre -> [replaced, cost]
    'か' => ['あ', 0.3], 'ば' => ['あ', 0.3], 'ま' => ['あ', 0.3], 'ゃ' => ['あ', 0.3],
    'い' => ['い', 0.3], 'き' => ['い', 0.3], 'し' => ['い', 0.3], 'ち' => ['い', 0.3],
    'に' => ['い', 0.3], 'ひ' => ['い', 0.3], 'じ' => ['い', 0.3], 'け' => ['い', 0.3],
    'せ' => ['い', 0.3], 'て' => ['い', 0.3], 'へ' => ['い', 0.3], 'め' => ['い', 0.3],
    'れ' => ['い', 0.3], 'げ' => ['い', 0.3], 'ぜ' => ['い', 0.3], 'で' => ['い', 0.3],
    'べ' => ['い', 0.3], 'ぺ' => ['い', 0.3],
    'お' => ['う', 0.3], 'こ' => ['う', 0.3], 'そ' => ['う', 0.3], 'と' => ['う', 0.3],
    'の' => ['う', 0.3], 'ほ' => ['う', 0.3], 'も' => ['う', 0.3], 'よ' => ['う', 0.3],
    'ろ' => ['う', 0.3], 'ご' => ['う', 0.3], 'ぞ' => ['う', 0.3], 'ど' => ['う', 0.3],
    'ぼ' => ['う', 0.3], 'ぽ' => ['う', 0.3], 'ょ' => ['う', 0.3],
    'え' => ['え', 0.3], 'ね' => ['え', 0.3],
};
# ai -> e:, ae -> e:
# minus
our $aiList = { # normal -> [merged-single, cost]
    'あい' => ['え', -0.6], 'あえ' => ['え', -0.6],
    'かい' => ['け', -0.6], 'かえ' => ['け', -0.6], 'がい' => ['げ', -0.6], 'がえ' => ['げ', -0.6],
    'さい' => ['せ', -0.6], 'さえ' => ['せ', -0.6], 'ざい' => ['ぜ', -0.6], 'ざえ' => ['ぜ', -0.6],
    'たい' => ['て', -0.6], 'たえ' => ['て', -0.6], 'だい' => ['で', -0.6], 'だえ' => ['で', -0.6],
    'ない' => ['ね', -0.6], 'なえ' => ['ね', -0.6],
    'はい' => ['へ', -0.1], 'はえ' => ['へ', -0.1], # ???
    'ばい' => ['べ', -0.6], 'ばえ' => ['べ', -0.6], 'ぱい' => ['ぺ', -0.6], 'ぱえ' => ['ぺ', -0.6],
    'まい' => ['め', -0.6], 'まえ' => ['め', -0.6],
    'やい' => ['や', -0.6], 'やえ' => ['や', -0.6],
    'らい' => ['れ', -0.6], 'らえ' => ['れ', -0.6],
};


our $indelScore = {
    # DEFAULT: 1.0
    'ー' => 0.3,
    '〜' => 0.3,
    '～' => 0.3,
    'っ' => 0.3,
};

sub calcNormalizedEditDistance {
    my ($a, $b) = @_;

    # my $uA = Unicode::Japanese->new($a)->kata2hira->getu;
    # my $uB = Unicode::Japanese->new($b)->kata2hira->getu;
    # return &calcLevenshteinDistance($uA, $uB) / min(length($uA), length($uB));
    # return &calcLevenshteinDistance($a, $b) / min(length($a), length($b));
    return &calcLevenshteinDistance($a, $b);
}

sub calcLevenshteinDistance {
    my ($str1, $str2) = @_;

    my $l1 = length($str1);
    my $l2 = length($str2);
    my $chart = [];
    foreach my $i (0 .. $l1) {
	$chart->[$i] = [];
	foreach my $j (0 .. $l2) {
	    $chart->[0]->[$j] = $j;
	}
	$chart->[$i]->[0] = $i;

    }

    my $p1 = '';
    for my $i (1 .. $l1) {
	my $c1 = substr($str1, $i - 1, 1);
	my $p2 = '';
	for my $j (1 .. $l2) {
	    my $c2 = substr($str2, $j - 1, 1);
	    my $cost;
	    if ($c1 eq $c2) {
		$cost = 0;
	    } else {
		$cost = &getReplacementScore($c1, $c2, $p1, $p2);
	    }
	    $chart->[$i]->[$j] = min(
		$chart->[$i - 1]->[$j] + &getInDelScore($c1),  # insertion
		$chart->[$i]->[$j - 1] + &getInDelScore($c2),  # deletion
		$chart->[$i - 1]->[$j - 1] + $cost);           # substitution
	    $p2 = $c2;
	}
	$p1 = $c1;
    } 
    return $chart->[$l1]->[$l2];
}

sub getReplacementScore {
    my ($c1, $c2, $p1, $p2) = @_;
    my $repScore = $replaceScore->{$c1}->{$c2} || 1;
    my $prelonged = 1;
    my $aiScore = 1;

    # e.g. 1: かあ 2:か～
    if ($p1 eq $p2) {
	if (defined($longSignList->{$c2})) {
	    my $tmp = $prolongedList->{$p1};
	    if (defined($tmp)) {
		my ($c1A, $score) = @$tmp;
		$prelonged = $score if ($c1 eq $c1A);
	    }
	} elsif (defined($longSignList->{$c1})) {
	    my $tmp = $prolongedList->{$p1};
	    if (defined($tmp)) {
		my ($c2A, $score) = @$tmp;
		$prelonged = $score if ($c2 eq $c2A);
	    }
	}
    } elsif (defined($aiList->{$p1 . $c1}) && defined($longSignList->{$c2})) {
	my ($p2A, $score) = @{$aiList->{$p1 . $c1}};
	$aiScore = $score if ($p2 eq $p2A);
    } elsif (defined($aiList->{$p2 . $c2}) && defined($longSignList->{$c1})) {
	my ($p1A, $score) = @{$aiList->{$p2 . $c2}};
	$aiScore = $score if ($p1 eq $p1A);
    }
    return min($repScore, $prelonged, $aiScore);
}

sub getInDelScore {
    my ($c) = @_;

    return $indelScore->{$c} || 1;
}

sub getRepname {
    my ($me) = @_;

    my $ref = $me->{'意味情報'}->{'代表表記'};
    return $ref if (defined($ref));
    return sprintf("%s/%s", (keys(%{$me->{'見出し語'}}))[0], $me->{'読み'});
}

sub romanize {
    my ($hira) = @_;
    my $roman = '';
    foreach my $c (split(//, $hira)) {
	if (defined($longSignList->{$c})) {
	    my $added = 0;
	    if (length($roman) >= 2) {
		my $v = substr($roman, length($roman) - 2);
		if ($v =~ /[aeiou]\./) {
		    $roman .= $v;
		    $added = 1;
		}
	    }
	    unless ($added) {
		$roman .= 'R.';
	    }
	} else {
	    $roman .= $hira2roman->{$c} || $c;
	}
    }
    return $roman;
}

1;
