package DictionaryTester;

# 自動獲得辞書の評価

use strict;
use utf8;
use base qw (AnalysisObserver);

use Juman;
use IDList;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	requiredAnalysis => 'raw',
	registered => {},
	opt => shift
    };

    # デフォルト値の設定
    $self->{opt}->{debug} = 0           unless (defined($self->{opt}->{debug}));
    # $self->{opt}->{interactive} = 1     unless (defined($self->{opt}->{interactive}));
    $self->{opt}->{'test-jumanrc'} = "/home/murawaki/.jumanrc.exp2"
	unless (defined($self->{opt}->{'test-jumanrc'}));

    bless($self, $class);

    $self->init;

    return $self;
}

sub init {
    my ($self) = @_;

    $self->{countOrg} = $self->{countExp} = 0;

    $self->{jumanOrg} = Juman->new;
    $self->{jumanExp} = Juman->new( -Rcfile => $self->{opt}->{'test-jumanrc'} );
}


#
# 一つの serviceID、あるいはリスト
#
sub getRequiredAnalysis {
    my ($self) = @_;

    return $self->{requiredAnalysis};
}

sub onDataAvailable {
    my ($self, $document) = @_;

    my $rawData = $document->getAnalysis('raw');
    return unless (defined($rawData));

    # my $jumanOrg = new Juman;
    # my $jumanExp = new Juman( -Rcfile => $self->{opt}->{'test-jumanrc'} );
    my $jumanOrg = $self->{jumanOrg};
    my $jumanExp = $self->{jumanExp};

    my $sentence;
    while (($sentence = $rawData->next()) ne IDList->STOP_ITERATION) {
	my $resultOrg = $jumanOrg->analysis($sentence);
	my $resultExp = $jumanExp->analysis($sentence);

	unless (defined($resultOrg) && defined($resultExp)) {
	    if ($self->{opt}->{debug}) {
		printf STDERR ("no juman result: %s\n", $sentence);
	    }
	    next;
	}
	my @mrphListOrg = $resultOrg->mrph;
	my @mrphListExp = $resultExp->mrph;

	# 簡易チェック
	# if (scalar (@mrphListOrg) != scalar(@mrphListExp)) {
	# print ("# $sentence\n");
	# }

	$self->{countOrg} += scalar(@mrphListOrg);
	$self->{countExp} += scalar(@mrphListExp);

	if (&getDiffFromResults(\@mrphListOrg, \@mrphListExp)) {
	    printf("# sentence: %s\n", $sentence);

# 	    if ($self->{opt}->{interactive}) {
# 		while (<STDIN>) {
# 		    chomp;
# 		    my $input = $_;

# 		    if ($input =~ /^\s*$/) {
# 			last;
# 		    }
# 		    print ("$input\n");
# 		}
# 	    }

	    print("\n");
	}

    }
    return;
}

sub getDiffFromResults {
    my ($mrphListOrg, $mrphListExp) = @_;

    my $i = 0; my $j = 0;
    my ($posOrg, $posExp) = (0, 0);

    my $rv = 0;

    my $endFlag = 0; # 1 bit 目が org, 2 bit 目が exp
    while (1) {
	my $mrphOrg;
	my $mrphExp;

	if ($posOrg == $posExp) {
	    unless ($endFlag & 1) {
		$mrphOrg = $mrphListOrg->[$i++];
		if (defined ($mrphOrg)) {
		    $posOrg += length ($mrphOrg->midasi);
		} else {
		    $endFlag += 1;
		}
	    }
	    unless ($endFlag & 2) {
		$mrphExp = $mrphListExp->[$j++];
		if (defined ($mrphExp)) {
		    $posExp += length ($mrphExp->midasi);
		} else {
		    $endFlag += 2;
		}
	    }	
	    if ($posOrg != $posExp) {
		$rv = 1;
		printf ("< %s", $mrphOrg->spec);
		printf ("> %s", $mrphExp->spec);
	    } else {
		if (defined ($mrphExp) && $mrphExp->imis =~ /自動獲得/) {
		    $rv = 1;
		    printf ("< %s", $mrphOrg->spec);
		    printf ("> %s", $mrphExp->spec);		    
		}
	    }
	} else {
	    if ($posOrg > $posExp) {
		$mrphExp = $mrphListExp->[$j++];
		if (defined ($mrphExp)) {
		    $posExp += length ($mrphExp->midasi);
		} else {
		    $endFlag += 2;
		}
		printf ("> %s", $mrphExp->spec);
	    } else {
		$mrphOrg = $mrphListOrg->[$i++];
		if (defined ($mrphOrg)) {
		    $posOrg += length ($mrphOrg->midasi);
		} else {
		    $endFlag += 1;
		}
		printf ("< %s", $mrphOrg->spec);
	    }
	}

# 	if ($endFlag & 1) {
# 	    $mrphOrg = $mrphListOrg->[$i++];
# 	    if (defined ($mrphOrg)) {
# 		$posOrg += length ($mrphOrg->midasi);
# 	    } else {
# 		$endFlag += 1;
# 	    }
# 	}
# 	while ($posExp >= $posOrg) {
# 	    $mrphExp = $mrphListExp->[$j++];
#  	    if (defined ($mrphExp)) {
#  		$posExp += length ($mrphExp->midasi);
#  	    } else {
#  		$endFlag += 2;
#  	    }
# 	}

	last if ($endFlag >= 3);
    }
    return $rv;
}

sub save {
    my ($self) = @_;

    printf ("# number of sentence of org: %d\n", $self->{countOrg});
    printf ("# number of sentence of exp: %d\n", $self->{countExp});
}

1;
