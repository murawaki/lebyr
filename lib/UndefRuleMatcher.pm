package UndefRuleMatcher;
#
# ルールと形態素列とのマッチングを取る
#
use strict;
use warnings;
use utf8;

use Storable qw/retrieve/;
use MorphemeUtilities;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $ruleFile = shift;

    my $self = {};
    bless ($self, $class);

    $self->{ruleList} = retrieve ($ruleFile) or die;

    return $self;
}

# ルールを適用
sub match {
    my ($self, $mrphP, $mrph, $mrphN) = @_;

    # ルール構造体:
    # [[$mrphP のルール, $mrph のルール, $mrphN のルール], $feature]
    #
    # 例:
    #  [[[1, [1, ['ひらがな']], [1, ['原形長', 1]]],
    #    [1, [1, ['ひらがな']], [1, ['原形長', 1]]],
    #    [1, [1, ['ひらがな']], [1, ['原形長', 1]]]],
    #   '一文字ひらがな連続']
    foreach my $rule (@{$self->{ruleList}}) {
	my ($constraints, $feature) = @$rule;
	my ($r0, $r1, $r2) = @$constraints;
	next unless (&_matchSub ($mrphP, $r0));
	next unless (&_matchSub ($mrph, $r1));
	next unless (&_matchSub ($mrphN, $r2));
	return $feature;
    }
    return undef;
}

sub _matchSub {
    my ($mrph, $mrphRule) = @_;

    if ($mrphRule eq 'ANY') {
	return 1;
    } elsif ($mrphRule eq 'NONEXIST') {
	return 0 if (defined ($mrph));
    } else {
	my $mflag = $mrphRule->[0];

	unless (defined ($mrph)) {
	    return !($mflag);
	}

	my $rv = 1;
	for (my $i = 1; $i < scalar (@$mrphRule); $i++) {
	    my ($sflag, $struct) = @{$mrphRule->[$i]};
	    my ($key, $value) = @$struct;

	    # hashref による switch の実現
	    my $srv = {
		# 特殊
		'未定義語' => sub { &MorphemeUtilities::isUndefined ($mrph) },
		'一文字漢字' => sub {
		    my $midasi = $mrph->midasi;
		    (length ($midasi) == 1 && $midasi =~ /\p{Han}/)? 1 : 0
		},
		'ひらがな' => sub {
		    my $midasi = $mrph->midasi;
		    ($midasi =~ /^(\p{Hiragana}|ー)+$/)? 1 : 0
		},
		'カタカナ' => sub {
		    my $midasi = $mrph->midasi;
		    ($midasi =~ /^(\p{Katakana}|ー)+$/)? 1 : 0
		},
		'見出し語長' => sub { (length ($mrph->midasi) == $value) },

		# Juman::Morpheme
		'見出し語' =>   sub { $mrph->midasi eq $value },
		'原形' =>       sub { $mrph->genkei eq $value },
		'品詞' =>       sub { $mrph->hinsi eq $value },
		'品詞細分類' => sub { $mrph->bunrui eq $value },
		'活用型' =>     sub { $mrph->katuyou1 eq $value },
		'活用形' =>     sub { $mrph->katuyou2 eq $value },

		# KNP::Morpheme
		'素性' => sub { ($mrph->fstring =~ /\<$value\>/)? 1 : 0 }
	    }->{$key}();

	    if ($srv != $sflag) {
		$rv = 0;
		last;
	    }
	}
	return $mflag == $rv;
    }
}


1;
