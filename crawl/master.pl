#!/bin/env perl
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Event::RPC::Server;
use Event::RPC::Loop::Event;
use IO::File;

use CrawlerMaster;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

sub main {
    my $opt = { port => 20199 };
    GetOptions($opt, 'port=i', 'crawlDir=s');

    my $master = CrawlerMaster->new($opt->{crawlDir});
    my $server = Event::RPC::Server->new(
	port => $opt->{port},
	classes => { $master->PROXY => {
	    new => '_constructor',
	    close => 1,
	    appendJob => 1,
	    queueSize => 1,
	    requestJob => 1,
	    startMerge => 1,
	    notifyDicSave => 1,
	    mergeStatus => 1,
	    stopWorkers => 1,
	    lastDir => 1,
		     }},
	loop => Event::RPC::Loop::Event->new,
	);
    $server->start;
}

unless (caller) {
    &main;
}

1;
