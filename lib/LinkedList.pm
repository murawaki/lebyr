package LinkedList;
#
# 単なる LinkedList だが、実体はただの配列
# 歯抜けを許す
#
use strict;
use warnings;
use utf8;

use ListIterator;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	list => [],
	};
    bless ($self, $class);
    return $self;
}

# 最後に追加
sub append {
    my ($self, $data) = @_;
    return push (@{$self->{list}}, $data);
}

# 特定の番号に入れる
sub insert {
    my ($self, $id, $data) = @_;
    return $self->{list}->[$id] = $data;
}

# 削除
sub remove {
    my ($self, $id) = @_;

    return 0 if ($id > $#{$self->{list}} || $id < 0);
    if ($id == $#{$self->{list}}) {
	pop (@{$self->{list}});       # length を減らす
    } else {
	undef ($self->{list}->[$id]); # 歯抜け
    }
    return 1;
}

sub get {
    my ($self, $id) = @_;
    return $self->{list}->[$id];
}

sub removeAll {
    my ($self) = @_;
    $self->{list} = [];
}

sub length {
    return scalar (@{($_[0])->{list}});
}

sub getIterator {
    return ListIterator->new ($_[0]);
}

1;
