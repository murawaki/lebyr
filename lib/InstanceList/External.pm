package InstanceList::External;
#
# instance list stored at external files
#
use strict;
use warnings;
use utf8;

use IO::File;

use LanguageModel::Util;

our $BLOCK = 2000000;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	json => shift,
	tmpdir => shift || '/tmp',
	fcount => 0,
	status => 'INIT', # or READ or WRITE
    };
    bless($self, $class);
    return $self;
}

sub DESTROY {
    my ($self) = @_;
    if ($self->{status} eq 'WRITE' || $self->{status} eq 'READ') {
	$self->{f}->close;
    }
    if (defined($self->{fpath})) {
	`rm -f $self->{fpath}`;
    }
    delete($self->{json});
}

sub append {
    my ($self, $instance) = @_;
    if ($self->{status} eq 'INIT') {
	$self->{fpath} = sprintf("%s/train.%s.%s", $self->{tmpdir}, $$, $self->{fcount});
	$self->{f} = IO::File->new($self->{fpath}, 'a') or die;
	$self->{f}->binmode(':utf8');
	$self->{status} = 'WRITE';
    }
    $self->{f}->printf("%s\n", $self->{json}->encode($instance));
}

sub shuffle {
    my ($self) = @_;
    if ($self->{status} eq 'WRITE' || $self->{status} eq 'READ') {
	$self->{f}->close;
	$self->{status} = 'INIT';
    }
    printf STDERR ("start shuffling\n");

    my $fpath2 = sprintf("%s/train.%s.%s", $self->{tmpdir}, $$, ++$self->{fcount});
    my $wc = `cat $self->{fpath} | wc -l`;
    my $c = int($wc / $BLOCK);
    my $d = (($wc % $BLOCK > 0)? 1 : 0);
    $c++ if ($d > 0);
    my $fList = {};
    for (my $i = 0; $i < $c; $i++) {
	printf STDERR ("block $i\n");

	my $ftmp = $fpath2 . '.' . $i;
	my $cmd;
	if ($i == 0) {
	    $cmd = sprintf("head -n %d %s", $BLOCK, $self->{fpath});
	} elsif ($i + 1 == $c && $d > 0) {
	    $cmd = sprintf("tail -n %d %s", $wc % $BLOCK, $self->{fpath});
	} else {
	    $cmd = sprintf("head -n %d %s | tail -n %s", $BLOCK * ($i + 1), $self->{fpath}, $BLOCK);
	}
	printf STDERR ("$cmd | shuf > $ftmp\n");
	`$cmd | shuf > $ftmp`;
	$fList->{$i} = $ftmp;
	if ($? != 0) {
	    die("shuf failed");
	}
    }
    printf STDERR ("now merging blocks\n");
    my $out = IO::File->new($fpath2, 'w');
    foreach my $idx (keys(%$fList)) {
	$fList->{$idx} = IO::File->new($fList->{$idx});
    }
    while (scalar(keys(%$fList)) > 0) {
	my $list = [keys(%$fList)];
	LanguageModel::Util::shuffle($list);
	foreach my $idx (@$list) {
	    my $line = $fList->{$idx}->getline;
	    if (defined($line)) {
		$out->print($line);
	    } else {
		$fList->{$idx}->close;
		delete($fList->{$idx});
	    }
	}
    }
    $out->close;
    # # avoid in-memory shuffle (to be accurate it's just random sorting)
    # `cat -n $self->{fpath} | sort --random-sort -T $self->{tmpdir} | cut -f 2- > $fpath2`;
    # `shuf $self->{fpath} > $fpath2`;
    printf STDERR ("done\n");
    `rm -f $self->{fpath}`;
    `rm -f $fpath2.*`;
    $self->{fpath} = $fpath2;
}

sub reset {
    my ($self) = @_;
    if ($self->{status} eq 'WRITE') {
	$self->{f}->close;
	$self->{status} = 'INIT';
    } elsif ($self->{status} eq 'READ') {
	$self->{f}->seek(0, 0);
    }
}

sub next {
    my ($self) = @_;
    if ($self->{status} eq 'WRITE') {
	$self->{f}->close;
	$self->{status} = 'INIT';
    }
    if ($self->{status} eq 'INIT') {
	$self->{f} = IO::File->new($self->{fpath}) or die;
	$self->{f}->binmode(':utf8');
	$self->{status} = 'READ';	
    }
    my $line = $self->{f}->getline;
    return undef unless(defined($line));
    return $self->{json}->decode($line);
}

1;
