#!/bin/env perl
#
# 検出対象代表表記のリストを入力として、
# 怪しい表記 -> 正しそうな表記 のマッピングを作る
#
# 怪しいヒューリスティクスの塊なので再検討が必要
#
use strict;
use utf8;
use warnings;

use Getopt::Long;
use Storable qw/retrieve nstore/;
use Dumpvalue;

binmode(STDIN, ':utf8');
binmode(STDOUT,':utf8');
binmode(STDERR, ':utf8');

# type
my $ALLKANJI = 1;
my $ALLHIRAGANA = 2;
my $ALLKATAKANAALPHA = 4;
my $OTHERS = 8;

my $KANJIVERB_AGAINST_KATAKANA = 16;

my $NAMETYPE_SHIFT = 6;

my $NORMAL = 16;
my $RELIABLE = 32;
my $UNRELIABLE = 64;

my $opt = {};
GetOptions($opt, 'repnames=s', 'output=s', 'debug');

die unless ( -f $opt->{repnames} );

my $repnameList = retrieve($opt->{repnames}) or die;

my $cfRepnameList = &buildRepnameList($repnameList);

nstore($cfRepnameList, $opt->{output}) or die;


sub buildRepnameList {
    my ($repnameList) = @_;

    my $cfRepnameList = {};
    while ((my $repname = each(%$repnameList))) {
	my $genkeiList = &tagGenkeiList($repnameList->{$repname});

	# mapping 元か先か
	# $RELIABLE    先
	# $UNRELIABLE  元
	# $ALLKANJI    先
	# $ALLHIRAGANA 元
	# $ALLKATAKANAALPHA 元 & 先
	# $OTHER       元
	my $from = [];
	my $to = [];
	my $both = [];

	while ((my ($genkei, $val) = each(%$genkeiList))) {
	    if ($val & $RELIABLE) {
		push(@$to, $genkei);
	    } elsif ($val & $UNRELIABLE) {
		push(@$from, $genkei);
	    } else {
		if ($val & $ALLKANJI) {
		    push(@$to, $genkei);
		} elsif ($val & $ALLHIRAGANA) {
		    push(@$from, $genkei);
		} elsif ($val & $ALLKATAKANAALPHA) {
		    push(@$both, $genkei);
		} else {
		    push(@$from, $genkei);
		}
	    }
	}

	if (scalar(@$to) + scalar(@$both) <= 0) {
	    if ($opt->{debug}) {
		print("warning: $repname dropped\n");
		Dumpvalue->new->dumpValue($genkeiList);
	    }
	} elsif (scalar(@$both) > 0) {
	    my $to2 = [];
	    push(@$to2, @$to);
	    push(@$to2, @$both);
	    foreach my $genkei (@$from) {
		$cfRepnameList->{$repname}->{$genkei} = $to2;
	    }
	    if (scalar(@$to) > 0) {
		foreach my $genkei (@$both) {
		    $cfRepnameList->{$repname}->{$genkei} = $to;
		}
	    }
	} else {
	    foreach my $genkei (@$from) {
		$cfRepnameList->{$repname}->{$genkei} = $to;
	    }
	}

	# assert
	foreach my $genkei (keys(%{$cfRepnameList->{$repname}})) {
	    if (scalar(@{$cfRepnameList->{$repname}->{$genkei}}) <= 0) {
		print("warning: no counter part $repname -> $genkei\n");
	    }
	}
    }
    return $cfRepnameList;
}

# 原形にタグ付け
sub tagGenkeiList {
    my ($genkeiList) = @_;

    my $allOther = 1;

    my $rv = {};
    foreach my $genkei (keys(%$genkeiList)) {
	my $val = $genkeiList->{$genkei};
	my $nameType = $val >> $NAMETYPE_SHIFT;
	$val -= $nameType << $NAMETYPE_SHIFT;

	# 漢字の条件をゆるめる
	if ($nameType & $OTHERS) {
	    $nameType = &loosenKanjiMatching($genkei, $nameType);
	}

	if ($nameType & $ALLKATAKANAALPHA
	    || $nameType & $ALLKANJI) {
	    $allOther = 0;
	}

	my $type = 0;
	if ($val < 1) {
	    $type |= $RELIABLE;
	} elsif ($val > 1) {
	    $type |= $UNRELIABLE;
	} else {
	    if ($nameType & $KANJIVERB_AGAINST_KATAKANA) {
		print("mark $genkei reliable\n");
		$type |= $RELIABLE;
	    } else {
		$type |= $NORMAL;
	    }
	}

	$rv->{$genkei} = $type | $nameType;
    }

    # 送り仮名のバリエーション
    # 起こす <-> 起す
    # 「起す」は漢字扱い
    # 「起こす」は OTHERS 扱い
    foreach my $genkei (keys(%$rv)) {
	my $val = $rv->{$genkei};
	next unless ($val & $OTHERS);
	next unless ($genkei =~ /\p{Hiragana}{2}$/);

	my $genkei2 = substr($genkei, 0, length($genkei) - 2) . substr($genkei, length($genkei) - 1, 1);
	next unless (defined($rv->{$genkei2}));

	my $val2 = $rv->{$genkei2};
	if ($val2 & $ALLKANJI) {
	    printf("propagate reliability flag %s <- %s\n", $genkei, $genkei2) if ($opt->{debug});

	    $rv->{$genkei} = ($val - $OTHERS) | $ALLKANJI;
	    $allOther = 0;
	}
    }


    # 送り仮名つきのものなどを選出
    if ($allOther) {
	my $ratedList = {};
	foreach my $genkei (keys(%$rv)) {
	    my $l = 0;
	    while ($genkei =~ /(\p{Han}+)/g) {
		$l += length($1);
	    }
	    push(@{$ratedList->{$l}}, $genkei);
	}
	return $rv if (scalar(keys(%$ratedList)) <= 1);

	my @sorted = sort { $b <=> $a } (keys(%$ratedList));
	foreach my $genkei (@{$ratedList->{$sorted[0]}}) {
	    $rv->{$genkei} |= $ALLKANJI;
	}
    }

    return $rv;
}

# ALLKANJI と判定されなかったものを
# 後付けで認定
sub loosenKanjiMatching {
    my ($genkei, $nameType) = @_;

    # 〜つく は自然な表記
    if ($genkei =~ /^(\p{Han}+)\p{Hiragana}?つく$/) {
	return $nameType | $ALLKANJI;
    }

    # 漢字を2文字以上含んでいればだいたい自然
    my $l = 0;
    while ($genkei =~ /(\p{Han}+)/g) {
	$l += length($1);
    }
    if ($l >= 2) {
	return $nameType | $ALLKANJI;
    }


    return $nameType;
}

1;
