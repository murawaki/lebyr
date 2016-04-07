#!/usr/bin/perl
use utf8;
use strict;
use warnings;

use Socket qw/AF_UNIX SOCK_STREAM PF_UNSPEC/;
use Encode qw/encode_utf8 decode_utf8/;
use IO::Handle; # thousands of lines just for autoflush :-(

use Egnee::Util qw/dynamic_use/;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $EOD = "__EOD__";

# DEFAULT SETTINGS
my $port = 10956;


socketpair(my $child, my $parent, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
$child->autoflush(1);
$parent->autoflush(1);

if (my $pid = fork) { # parent
    close ($parent);

    $SIG{INT} = sub {
	$child->close;
	waitpid($pid, 0);
	exit 1;
    };

    &parentMain($child);
    close($child);
    waitpid($pid, 0);
} else { # child
    die "cannot fork: $!\n" unless (defined($pid));
    close($child);

    &childMain($parent);
    close($parent);
    exit;
}

1;


sub parentMain {
    my ($child) = @_;

    $SIG{PIPE} = sub {
	print("ignore SIGPIPE\n");
    };

    dynamic_use('IO::Select');
    dynamic_use('IO::Socket::INET');

    my $listener = IO::Socket::INET->new(LocalPort => $port, Listen => 10, Proto => 'tcp', ReuseAddr  => 1)
	or die "cannot make a server socket\n";

    my $selector = IO::Select->new($listener);

    # main loop
    while (1) {
	my @ready = $selector->can_read;
	foreach my $sock (@ready) {
	    if ($sock == $listener) {
		my $newSock = $listener->accept;

		printf("server $$ accept\n");

		$selector->add($newSock);
	    } else {
		my $input = $sock->getline;
		chomp($input);

		printf("server $$ received: %s\n", $input);
		# $sock->printf("server received: %s\n", $input);

		my $hasResponce = &processCommandParent($input, $sock, $child);
		if ($hasResponce) {
		    chomp(my $line = $child->getline);
		    $sock->print("$line\n");
		    # $sock->printf("server received from child: %s\n", $line);
		}

		$selector->remove($sock);
		$sock->close;
	    }
	}
    }
    printf("server $$ got out of the loop\n");
}

sub processCommandParent {
    my ($input, $sock, $child) = @_;

    my @args = split(/\s+/, $input);
    if (scalar(@args) <= 0) {
	$sock->print("ERROR no command given\n");
	return 0;
    }
    my $command = shift(@args);

    if ($command eq 'TEXT') {
	my $data = '';
	while (my $line = $sock->getline) {
	    chomp($line);
	    printf("parent $$ got line\n");
	    last if ($line eq $EOD);

	    $data .= "$line\n";
	}
	print("parent $$ got data\n");

	$child->print("TEXT\n");
	$child->print($data);
	$child->print("$EOD\n");
	$child->flush;

	print("parent $$ sent data to child\n");

	return 1;
    }
    if ($command eq 'BATCH') {
	print("parent $$ start sending batch data\n");

	$child->print("BATCH\n");
	my $count = 0;
	while (my $line = $sock->getline) {
	    $count++;
	    chomp($line);
	    printf("parent $$ got line\n");
	    $child->print("$line\n");
	    last if ($line eq $EOD);
	}
	$child->print("$EOD\n");
	$child->flush;

	print("parent $$ sent $count lines to child\n");
	return 0;
    }

    $sock->print("ERROR unsupported command $command\n");
    return 0;
}

sub childMain {
    my ($parent) = @_;

    require 'egnee.pl';
    &openOutput;
    my $egnee = &initEgnee;
    print("child $$ loading done\n");

    while (my $line = $parent->getline) {
	chomp($line);

	# print("child $$ received $line\n");

	# skip error check
	my @args = split(/\s+/, $line);
	my $command = shift(@args);

	if ($command eq 'TEXT') {
	    printf("child $$ reading data\n");

	    my $data = '';
	    while (my $line = $parent->getline) {
		chomp($line);
		printf("child $$ got line\n");
		last if ($line eq $EOD);

		$data .= "$line\n";
	    }

	    printf("child $$ got data\n");
	    my $input = decode_utf8($data);

	    my $id = &getUUID;
	    $parent->print("SET_ID $id\n");
	    $parent->flush;

	    $egnee->info("SET_ID $id\n");
	    $egnee->info("rawstring: $input\n");
	    my $sentence = &processTextInput($input);
	    &setResult($sentence);
	} elsif ($command eq 'BATCH') {
	    printf("child $$ reading batch data\n");
	    &appendHistory('BATCH_START');

	    while (my $line = $parent->getline) {
		chomp($line);
		printf("child $$ got line\n");
		last if ($line eq $EOD);

		my $input = decode_utf8($line);
		$egnee->info("rawstring: $input\n");
		&processTextInput("$input\n");
	    }
	    &appendHistory('BATCH_END');
	}
    }
    &closeOutput;
}
