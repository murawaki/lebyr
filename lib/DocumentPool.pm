package DocumentPool;

use strict;
use warnings;
use utf8;

# holder for a single document

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	opt => shift,
    };
    # default settings
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));

    bless($self, $class);
    return $self;
}

sub get {
    my ($self) = @_;

    my $document = pop(@{$self->{documentList}});
    return $document;
}

sub add {
    my ($self, $document) = @_;

    push(@{$self->{documentList}}, $document);
    return;
}

sub isEmpty {
    my ($self) = @_;

    return (scalar(@{$self->{documentList}}) > 1)? 0 : 1;
}


1;
