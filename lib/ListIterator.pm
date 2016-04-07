package ListIterator;
#
# 歯抜けを許す List
#
use strict;
use warnings;
use utf8;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	list => shift,
	cur => 0
    };

    # デフォルト値の設定
    $self->{opt}->{debug} = 0 unless (defined $self->{opt}->{debug});

    bless ($self, $class);
    return $self;
}

sub next {
    my ($self) = @_;
    return $self->{list}->get ($self->{cur}++);
}

sub nextNonNull {
    my ($self) = @_;
    while ($self->hasNext) {
	my $data = $self->next;
	return $data if (defined ($data));
    }
    return undef;
}

sub hasNext {
    my ($self) = @_;
    return ($self->{list}->length > $self->{cur})? 1 : 0;
}

sub reset {
    ($_[0])->{cur} = 0;
}

1;
