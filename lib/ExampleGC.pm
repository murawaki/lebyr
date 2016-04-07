package ExampleGC;
#
# ExampleGC: clean up old examples not used for a long time
#
use strict;
use warnings;
use utf8;

use Egnee::Logger;

our $defaultCheckThres = 10000; # GC を発動される用例数
our $defaultLimit      =  8000; # GC を発動させた後の圧縮された値

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	accumulator => shift,
	opt => shift,
    };
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{opt}->{checkThres} = $defaultCheckThres unless (defined($self->{opt}->{checkThres}));
    $self->{opt}->{limit}      = $defaultLimit unless (defined($self->{opt}->{limit}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});
    return $self;
}

sub run {
    my ($self) = @_;

    my $accumulator = $self->{accumulator};
    my $total = $accumulator->getTotal;
    return 0 if ($total < $self->{opt}->{checkThres});

    Egnee::Logger::info("now running GC...\n");
    Egnee::Logger::info("GC: [before] total $total\n");

    my $exampleList = $accumulator->getAllExamples;

    Egnee::Logger::info(sprintf("GC assert: collected total %d\n", scalar(@$exampleList)));

    # TODO: complete sorting is unnecessary
    my @sortedExampleList = sort { $a->{count} <=> $b->{count} } (@$exampleList);

    my $deleteList = [];
    my $deleteKatakanaList = {};

    my $dcount = 0; # assert

    my $length = scalar(@sortedExampleList);
    my $dlimit = $length - $self->{opt}->{limit};
    my $cur = -1;
    for (my $i = 0; $i < $length; $i++) {
	my $example = $sortedExampleList[$i];

	my $count = $example->{count};
	last if ($i > $dlimit && $count > $cur); # 一応同じ値のものを考慮

	if ($example->{type} eq 'カタカナ') {
	    my $pivot = $example->{pivot};
	    push(@{$deleteKatakanaList->{$pivot}}, $example);
	} else {
	    push(@$deleteList, $example);
	}
	$dcount++;

	$cur = $count;
    }

    Egnee::Logger::info("GC: delete $dcount examples\n");

    $accumulator->deleteExampleList($deleteList, $deleteKatakanaList);

    Egnee::Logger::info(sprintf("GC: [after] total %d\n", $accumulator->getTotal));

    return $dcount;
}

1;
