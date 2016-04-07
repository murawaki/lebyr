package JumanDictionary::Mixed;
#
# treat a set of (static) dictionaries as a single dictionary
#
use strict;
use warnings;
use utf8;
use base qw/JumanDictionary/;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	list => [],
	opt => shift
    };
    bless($self, $class);
    return $self;
}
sub close {}

sub add {
    my ($self, $dic) = @_;
    push(@{$self->{list}}, $dic);
}

=head2 getMorpheme ($midasi, $constraints)

登録済みの形態素を引く。存在すればリストで返す。なければ undef。

引数
  $midasi: 見出し語
  $constraints (optional): 見出し語以外の制約

=cut
sub getMorpheme {
    my ($self, $midasi, $constraints) = @_;

    my $rv = [];
    foreach my $dic (@{$self->{list}}) {
	my $mList = $dic->getMorpheme($midasi, $constraints);
	push(@$rv, @$mList) if (defined($mList));
    }
    return (scalar(@$rv) > 0)? $rv : undef;
}

sub getAllMorphemes {
    my ($self) = @_;

    my $rv = [];
    foreach my $dic (@{$self->{list}}) {
	my $mList = $dic->getAllMorphemes;
	push(@$rv, @$mList) if (defined($mList));
    }
    return $rv;
}

############################################################
#               This dictionary is read-only               #
############################################################
sub addMorpheme {
    return ($_[0])->errorStatic;
}
sub removeMorpheme {
    return ($_[0])->errorStatic;
}
sub clear {
    return ($_[0])->errorStatic;
}
sub saveAsDictionary {
    return ($_[0])->errorStatic;
}
sub update {
    return ($_[0])->errorStatic;
}
sub errorStatic {
    warn("dictionary not writable\n");
}

1;
