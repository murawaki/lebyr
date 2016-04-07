package ExampleList;

use strict;
use utf8;
use warnings;

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	istream => shift,
	opt => shift,
    };
    bless ($self, $class);
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    $self->{istream}->close if ($self->{istream});
    $self->{ostream}->close if ($self->{ostream});
}

sub setIStream {
    ($_[0])->{istream} = $_[1];
}

sub setOStream {
    ($_[0])->{ostream} = $_[1];
}

sub reset {
    my ($self) = @_;
    $self->{istream}->seek (0, 0);
}

sub readNext {
    my ($self) = @_;
    my $line = $self->{istream}->getline;
    unless (defined ($line)) {
	# $self->reset;
	return;
    }

    chomp ($line);
    my @tmp = split (/\s/, $line);
    my $example = {
	name => shift (@tmp),
	id => shift (@tmp),
	from => shift (@tmp),
    };
    # my @list = map { my @a = split (/\:/, $_); \@a } (@tmp);
    my @list = map { my @a = split (/\:/, $_); [$a[0], 1] } (@tmp);
    $example->{featureList} = \@list;
    return $example;
}

sub writeNext {
    my ($self, $example) = @_;
    return unless (defined ($self->{ostream}));

    $self->{ostream}->printf ("%s\t%s\t%s\t%s\n",
			      $example->{name},
			      $example->{id},
			      $example->{from},
			      join ("\t", map { $_->[0] . ':' . $_->[1] } (@{$example->{featureList}})) );
}

sub readClose {
    my ($self) = @_;
    return unless (defined ($self->{istream}));
    $self->{istream}->close;
    undef ($self->{istream});
}

sub writeClose {
    my ($self) = @_;
    return unless (defined ($self->{ostream}));
    $self->{ostream}->close;
    undef ($self->{ostream});
}

sub randomSelect {
    my ($self, $example) = @_;

    my $id = $example->{id};
    if (index ($id, '?') >= 0) {
	# randomly select id
	my @idList = split (/\?/, $id);
	my $i = int (rand (scalar (@idList)));
	$id = $idList[$i];
	$example->{id} = $id;
    }
    return $example;
}

1;
