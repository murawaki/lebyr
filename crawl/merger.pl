#!/bin/env perl
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Event::RPC::Client;
use IO::File;

sub main {
    binmode(STDIN,  ':utf8');
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    my $opt = { master => 'localhost:20199',
		tmpdir => '/yew/murawaki/crawl-data-daily/merge',
		startdate => `date -d yesterday +%Y%m%d` };
    GetOptions($opt, 'master=s', 'tmpdir=s', 'startdate=s');

    `mkdir -p $opt->{tmpdir}`;

    my ($host, $port) = split(/\:/, $opt->{master});
    my $PROXY_CLASS = 'CrawlerMaster::Proxy';
    my $client = Event::RPC::Client->new(
	host => $host,
	port => $port,

	error_cb => sub {
	    my ($client, $error) = @_;
	    print "A RPC error occured: $error\n";
	    $client->disconnect;
	    exit;
	},
	classes => [ $PROXY_CLASS ],
	);
    $client->connect;
    my $obj = $PROXY_CLASS->new('MERGER');

    my $handler = sub {
	my ($signame) = @_;
	printf STDERR ("%s\n", $signame);
	$client->disconnect if (defined($client));
	exit 1;
    };
    $SIG{INT} = $SIG{TERM} = $handler;

    {
	my $lastDir = $obj->lastDir;
	my $f = IO::File->new($opt->{tmpdir} . '/LASTDIR', 'w');
	$f->printf("%s\n", $lastDir);
	$f->close;
    }

    # collect dictionaries
    my $id = $obj->startMerge($opt->{tmpdir});
    while (1) {
	my ($status, $opt) = $obj->mergeStatus($id);
	if ($status eq 'COMPLETE') {
	    last;
	} elsif ($status eq 'ERROR') {
	    die($opt);
	} else {
	    printf STDERR ("%s %s\n", $status, $opt);
	}
	sleep(5);
    }

    # todo: real merge
    printf("done!\n");
}

unless (caller) {
    &main;
}

1;
