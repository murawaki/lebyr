package DocumentPool::Mixed;

use strict;
use utf8;
use base qw (DocumentPool);

# 複数の DocumentPool を使う
# 今のところ登録した順に DocumentPool#get を呼び出すのみ

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	poolList => [],
	pointer => 0,
	opt => shift
	};

    # デフォルト値の設定
    $self->{opt}->{debug} = 0           unless (defined $self->{opt}->{debug});

    bless ($self, $class);
    return $self;
}

sub get {
    my ($self) = @_;

    return undef if ($self->{pointer} > $#{$self->{poolList}});
    my $documentPool = $self->{poolList}->[$self->{pointer}];
    my $document = $documentPool->get ();
    return $document if (defined ($document));

    $self->{poolList}->[$self->{pointer}] = undef; # GC 対策
    $self->{pointer}++;
    return $self->get ();
}

# under construction
sub add {
    my ($self, $document) = @_;

    return;
}

sub isEmpty {
    my ($self) = @_;

    foreach my $documentPool (@{$self->{poolList}}) {
	next unless (defined ($documentPool)); # undef の可能性あり
	return 1 unless ($documentPool->isEmpty ());
    }
    return 0;
}

sub addDocumentPool {
    my ($self, $documentPool) = @_;

    push (@{$self->{poolList}}, $documentPool);
}

1;
