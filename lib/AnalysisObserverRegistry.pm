package AnalysisObserverRegistry;

use strict;
use utf8;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	serviceList => {},
	serviceTable => [], # 順番の管理
	iterationPoint => 0,
	opt => shift,
	};

    # デフォルト値の設定
    $self->{opt}->{debug} = 0           unless (defined $self->{opt}->{debug});

    bless($self, $class);
    return $self;
}

sub add {
    my ($self, $serviceID, $analysisObserver) = @_;

    return undef if (defined($self->{serviceList}->{$serviceID}));

    $self->{serviceList}->{$serviceID} = $analysisObserver;
    push(@{$self->{serviceTable}}, $serviceID);
    
    return;
}

sub remove {
    my ($self, $serviceID) = @_;

    return undef if (defined($self->{serviceList}->{$serviceID}));
    delete($self->{serviceList}->{$serviceID});

    my $i;
    for ($i = 0; $i <= $#{$self->{serviceTable}}; $i++) {
	last if ($self->{serviceTable}->[$i] eq $serviceID);
    }
    return splice(@{$self->{serviceTable}}, $i, 1);
}

sub next {
    my ($self) = @_;

    # 一度 undef を返したあともう一度呼び出すと 0 から始まる仕様
    # 明示的に reset すべきかもしれない
    $self->{iterationPoint} = 0 if ($self->{iterationPoint} < 0);
    if ($self->{iterationPoint} > $#{$self->{serviceTable}}) {
	$self->{iterationPoint} = 0;
	return undef;
    }
    return $self->{serviceTable}->[$self->{iterationPoint}++];
}

sub get {
    my ($self, $serviceID) = @_;

    return $self->{serviceList}->{$serviceID};
}

1;
