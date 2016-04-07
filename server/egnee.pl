#!/usr/bin/perl
use utf8;
use strict;
use warnings;

use IO::Dir;
use IO::File;
use Data::UUID;

use Egnee::GlobalConf;
use Egnee::Logger;
use MorphemeGrammar;
use Egnee;

my $confPath = '/home/murawaki/research/unknown/server/prefs';
my $logPath = '/home/murawaki/public_html/egnee/data/log';
my $historyPath = '/home/murawaki/public_html/egnee/data/history';
my $logBase = '/home/murawaki/public_html/egnee/log';
my $GC_INTERVAL = 100;
my $gcCount = 1;

my $egnee;
my $log;
my $history;
my $currentID;
my $eventQueue;

$SIG{INT} = sub {
    &closeOutput;
    exit 1;
};

sub openOutput {
    $log = IO::File->new($logPath, 'a');
    $log->autoflush(1);
    $log->binmode('utf8');
    Egnee::Logger::setLogOutput($log);

    $history = IO::File->new($historyPath, 'a');
    $history->autoflush(1);
    $history->binmode('utf8');
}

sub closeOutput {
    $log and $log->close; undef($log);
    $history and $history->close;
    undef($history);
}

sub appendHistory {
    my ($line) = @_;
    print $history (time, "\t", $line, "\n");
}

sub initEgnee {
    Egnee::GlobalConf::loadFile($confPath);
    $egnee = Egnee->new;

    $egnee->setDictionaryCallback (\&processEvent);
    $egnee->setExampleCallback (\&processEvent);

    &appendHistory("SERVER_START");
    return $egnee;
}

sub processTextInput {
    my ($input) = @_;

    # initialize
    $eventQueue = [];

    # TODO: 複数の文の処理
    my $sentence = $egnee->processRawString($input);
}

sub setResult {
    my ($sentence) = @_;

    my $data = '';
    if ($sentence->get('noisy', { direct => 1 })) {
	$data .= '怪しい文章だと思ったので解析してません。';
    } else {
	my $knpResult = $sentence->get('knp');
	foreach my $bnst ($knpResult->bnst) {
	    $data .= '| ';
	    foreach my $mrph ($bnst->mrph) {
		my $flag = ($mrph->imis =~ /自動獲得/)? 1 : 0;
		$data .= '<span class="acquired">' if ($flag);
		$data .= $mrph->midasi;
		$data .= '</span>' if ($flag);
		$data .= ' ';
	    }
	    $data .= '|';
	}
    }
    $data .= "\n";
    foreach my $event (@$eventQueue) {
	if ($event->{type} eq 'example') {
	    $data .= sprintf("「%s」が怪しいと思う。\n", $event->{string});
	} elsif ($event->{type} eq 'append') {
	    $data .= sprintf("「%s」を覚えた。\n", $event->{string});
	} elsif ($event->{type} eq 'decompose') {
	    $data .= sprintf("「%s」は冗長だから消した。\n", $event->{string});
        }
    }
    chomp($data);
    $data =~ s/\n/\<br\>\n/g;
    $data .= "\n";

    my $path = "$logBase/$currentID";
    my $f = IO::File->new($path, 'w') or die "Cannot output result\n";
    $f->binmode('utf8');
    $f->print($data);
    $f->close;

    &gcLog unless ($gcCount++ % $GC_INTERVAL);
}

sub processEvent {
    my ($event) = @_;

    push(@$eventQueue, $event);
    if ($event->{type} eq 'example') { # ExampleEvent
	$event->{string} = $event->{obj}->{pivot};
    } elsif ($event->{type} eq 'beforeChange') {
	; # do nothing
    } elsif ($event->{type} eq 'append') { # DictionaryChange
	my $me = $event->{obj};
	my $mrph = $me->getJumanMorpheme;
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	$event->{string} = $mrph->genkei . ':' . $posS;

	&appendHistory(sprintf("APPEND %s:%s", $mrph->genkei, $posS));
    } elsif ($event->{type} eq 'decompose') {
	my $me = $event->{obj};
	my $mrph = $me->getJumanMorpheme;
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	$event->{string} = $mrph->genkei . ':' . $posS;

	&appendHistory(sprintf("DECOMPOSE %s:%s", $mrph->genkei, $posS));
    } else {
	Egnee::Logger::warn("unsupported dictionary event type\n");
    }
}

sub getUUID {
    return $currentID = Data::UUID->new->create_str;
}

sub gcLog {
    my $dir = IO::Dir->new($logBase);
    my $list = [];
    while ((my $file = $dir->read)) {
	my $path = "$logBase/$file";
	next unless ( -f $path );

	push(@$list, [$path, (stat ($path))[9]]); # mtime
    }
    my @sorted = sort { $b->[1] <=> $a->[1] } (@$list);

    for (my $i = $GC_INTERVAL; $i < scalar(@sorted); $i++) {
	my $rmCmd = sprintf("rm -f %s\n", ($sorted[$i])->[0]);
	`$rmCmd`;
    }
}

1;
