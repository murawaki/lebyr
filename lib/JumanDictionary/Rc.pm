package JumanDictionary::Rc;
#
# store jumanrc data
#
use strict;
use warnings;
use utf8;

use IO::File;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;

    my $baseFile = shift;
    my $self = {
	opt => shift
	};
    bless($self, $class);
    $self->load($baseFile);
    return $self;
}

sub load {
    my ($self, $path) = @_;

    my $f = IO::File->new($path) or die("jumanrc file $path not found");
    $f->binmode(':utf8');
    my @buf = $f->getlines;
    $self->{base} = \@buf;
    $f->close;
}

sub addDic {
    my ($self, $path) = @_;

    # find the last line of the dictionary path setting
    my $flag = 0;
    my $endIndex;
    for (my $i = 0, my $l = scalar(@{$self->{base}}); $i < $l; $i++) {
	if ($flag && $self->{base}->[$i] =~ /\)/) {
	    $endIndex = $i;
	    last;
	} elsif ($self->{base}->[$i] =~ /^\(辞書ファイル/) {
	    $flag = 1;
	}
    }

    my @buf = map { $_ } (@{$self->{base}}); # clone
    splice(@buf, $endIndex, 0, "\t$path\n");
    $self->{buf} = \@buf;
}

sub saveAs {
    my ($self, $path) = @_;

    my $f = IO::File->new($path, 'w') or die("$!");
    $f->binmode(':utf8');
    $f->print(join('', @{$self->{buf}}));
    $f->close;
}

1;
