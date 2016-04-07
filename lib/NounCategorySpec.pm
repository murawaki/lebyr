package NounCategorySpec;
#
# map each JUMAN morpheme to a noun category
#
use utf8;
use strict;
use warnings;

use base qw /Class::Data::Inheritable/;

__PACKAGE__->mk_classdata(id2class =>
    ['固有名詞その他', '人名', '組織名', '地名',
     '普通名詞その他', '人', '組織', '場所', '動物',
     ]);
__PACKAGE__->mk_classdata(LENGTH => 9);

our $bunruiList = {
    '固有名詞' => 0,
    '人名' => 1,
    '組織名' => 2,
    '地名' => 3,
};
our $COMMON_OTHER = 4;
our $catList = {
    '人' => 5,
    # 7
    '組織・団体' => 6,
    '場所-施設' => 7,
    '場所-施設部位' => 7,
    '場所-機能' => 7,
    '場所-自然 ' => 7,
    '場所-その他' => 7,
    '動物' => 8,
    # '動物-部位' => 8,
};

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub getClassFromID {
    return $_[0]->id2class->[$_[1]];
}

sub isProperByClass {
    my ($self, $class) = @_;

    $class = '固有名詞' if ($class eq '固有名詞その他');
    return (defined($bunruiList->{$class}))? 1 : 0;
}

# NOTE: do not check if $mrph belongs to a valid POS
sub getIDFromMrph {
    my ($self, $mrph) = @_;
    my $list = $self->getIDFromSingleMrph($mrph);

    if ($mrph->{doukei}) {
	for (my $i = 0; $i < scalar(@{$mrph->{doukei}}); $i++) {
	    my $list2 = $self->getIDFromSingleMrph($mrph->{doukei}->[$i]);
	    foreach my $id (keys(%$list2)) {
		$list->{$id} += $list2->{$id};
	    }
	}
    }
    return join('?', sort { $a <=> $b } (keys(%$list)));
}

sub getIDFromSingleMrph {
    my ($self, $mrph) = @_;

    my $idList = {};
    my $imis = $mrph->imis;
    if (defined(my $bunrui = $bunruiList->{$mrph->bunrui})) {
	my $genkei = $mrph->genkei;
	$idList->{$bunrui}++;
    } elsif ($imis =~ /カテゴリ\:([^\s\"]+)/) {
	# for common and sahen nouns
	foreach my $cat (split(/\;/, $1)) {
	    my $id = $catList->{$cat};
	    $idList->{(defined($id))? $id : $COMMON_OTHER}++;
	}
    } else {
	$idList->{$COMMON_OTHER}++;
    }
    return $idList;
}

1;
