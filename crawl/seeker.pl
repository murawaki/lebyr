#!/bin/env perl
use strict;
use warnings;
use utf8;

use Getopt::Long;
use Event::RPC::Client;
use IO::Dir;
use POSIX;

sub main {
    binmode(STDIN,  ':utf8');
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    my $opt = { master => 'localhost:20199',
		basedir => '/yew/crawler/crawl-data-daily/xml',
		tmpdir => '/yew/murawaki/crawl-data-daily/tmp',
		startdate => `date -d yesterday +%Y%m%d` };
    GetOptions($opt, 'master=s', 'basedir=s', 'tmpdir=s', 'startdate=s');

    my ($host, $port) = split(/\:/, $opt->{master});
    my $PROXY_CLASS = 'CrawlerMaster::Proxy';
    my $client = Event::RPC::Client->new(
	host => $host,
	port => $port,

	error_cb => sub {
	    my ($client, $error) = @_;
	    print "An RPC error occured: $error\n";
	    $client->disconnect;
	    exit;
	},
	classes => [ $PROXY_CLASS ],
	);
    $client->connect;
    my $obj = $PROXY_CLASS->new('SEEKER');

    my $handler = sub {
	my ($signame) = @_;
	printf STDERR ("%s\n", $signame);
	$client->disconnect if (defined($client));
	exit 1;
    };
    $SIG{INT} = $SIG{TERM} = $handler;

    my $date = $opt->{startdate};
    my $time = &date2time($date);
    my $count = 0;

    # main loop
    eval {
	while (1) {
	    if ($date > &yesterday) {
		printf STDERR ("in the head; sleep\n");
		sleep(60 * 30);
		next;
	    }

	    my $dirpath = $opt->{basedir} . '/' . $date;
	    if ( -d "$dirpath" ) {
		unless ( -f "$dirpath.done" ) {
		    printf STDERR ("data in progress; sleep\n");
		    sleep(60 * 30);
		    next;
		}

		my $tgzList = [];
		my $dir = IO::Dir->new($dirpath) or die;
		foreach my $ftmp (sort {$a cmp $b} ($dir->read)) {
		    my $filePath = $dirpath . '/' . $ftmp;
		    if ($ftmp =~ /([^\/]*)\.tar\.gz$/) {
			push(@$tgzList, $filePath);
		    }
		}
		while (scalar(@$tgzList) > 0) {
		    if ($obj->queueSize > 3) {
			printf STDERR ("sufficient number of jobs in queue; sleep\n");
			sleep(60);
			next;
		    }
		    my $tgzFile = shift(@$tgzList);
		    my $tmpdir = $opt->{tmpdir} . '/' . $date . '-' . $count++;
		    printf STDERR ("mkdir -p $tmpdir\n");
		    `mkdir -p $tmpdir`;
		    my $cmd = sprintf("tar -z -x -C %s -f %s", $tmpdir, $tgzFile);
		    printf STDERR ("$cmd\n");
		    `$cmd`;
		    $obj->appendJob($tmpdir);
		    sleep(2);
		}
	    } else {
		printf STDERR ("directory $dirpath not found; skip\n");
	    }
	    sleep(5);
	    $time = &nextDayInTime($time);
	    $date = &time2date($time);
	    printf STDERR ("date: $date\n");
	}
    };
    if ($@) {
	printf STDERR ("error: %s", $@);
    }
    $client->disconnect;
}

sub yesterday {
    return `date -d yesterday +%Y%m%d`;
}

sub date2time {
    my ($date) = @_;
    return POSIX::mktime(0, 0, 0, substr($date, 6, 2), substr($date, 4, 2) - 1, substr($date, 0, 4) - 1900);
}

sub time2date {
    my ($time) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
    return sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
}

sub nextDayInTime {
    my ($time) = @_;
    return $time + 60 * 60 * 24;
}

unless (caller) {
    &main;
}

1;
