package ExampleList::Cached;
use strict;
use utf8;
use warnings;
use base qw/ExampleList/;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	list => [],
	index => 0
    };
    bless ($self, $class);
    return $self;
}

sub DESTROY {
}

sub readClose {}
sub writeClose {}
sub setIStream {}
sub setOStream {}

sub writeNext {
    my ($self, $example) = @_;
    push (@{$self->{list}}, $example);
}

sub reset {
    my ($self) = @_;
    $self->{index} = 0;
}

sub readNext {
    my ($self) = @_;
    my $example = $self->{list}->[$self->{index}++];
    if ($example) {
	return $example;
    } else {
	$self->reset;
	return undef;
    }
}

1;
