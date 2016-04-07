package Sentence;

use strict;
use warnings;
use utf8;

our $registry;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	data => shift || {}
	};
    bless($self, $class);
    return $self;
}

sub add {
    ($_[0])->{data} = $_[1];
}

sub get {
    my ($self, $type, $opt) = @_;
    # $opt:
    #   direct: not resolve dependency

    my $data = $self->{data}->{$type};
    return $data if (defined($data));

    return undef if ($opt && $opt->{direct});
    return undef unless ($registry);
    # dependency resolution
    my $analyzer = $registry->get($type);
    unless (defined($analyzer)) {
	return undef;
    }
    my $depList = $registry->getDependencyList($type);
    my $source;
    for (my $i = 0; $i < scalar(@$depList); $i++) {
	my $depType = $depList->[$i];
	my $source = $self->get($depType);
	next unless (defined($source));

	my $data = $analyzer->exec($source, $depType);
	if (defined($data)) {
	    return $self->set($type, $data);
	}
    }
    return undef;
}

sub set {
    my ($self, $type, $data) = @_;
    return $self->{data}->{$type} = $data;
}

# class method
sub setAnalyzerRegistry {
    my ($this, $registry2) = @_;
    $registry = $registry2;
}

1;
