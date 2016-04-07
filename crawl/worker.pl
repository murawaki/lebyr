#!/bin/env perl

use strict;
use warnings;
use utf8;

use Getopt::Long;
use Event::RPC::Client;
use IO::File;

use Egnee;
use Egnee::GlobalConf;
use MorphemeGrammar;
use Document::StandardFormat;

sub main {
    binmode(STDIN,  ':utf8');
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    my $opt = {
	master => 'localhost:20199',
	conf => '/home/murawaki/research/lebyr/prefs',
	safeMode => 0,
	doLoad => 0,
	debug => 0,
    gc_threshold => 10000,
    gc_limit => 8000,
    };
    GetOptions($opt, 'master=s', 'conf=s', 'dicdir=s', 'basedic=s', 'gc_threshold=s' ,'gc_limit=s', 'safeMode', 'debug');
    Egnee::GlobalConf::loadFile($opt->{conf});

    `mkdir -p $opt->{dicdir}`;
    if ($opt->{basedic}) {
	my $cmd = sprintf("cp %s %s/output.dic", $opt->{basedic}, $opt->{dicdir});
	`$cmd`;
	Egnee::GlobalConf::set('working-dictionary.do-load', 1);
    } else {
	Egnee::GlobalConf::set('working-dictionary.do-load', 0);
    }
    Egnee::GlobalConf::set('main.acquisition', 1);
    Egnee::GlobalConf::set('main.debug', $opt->{debug});
    Egnee::GlobalConf::set('working-dictionary.path', $opt->{dicdir});
    Egnee::GlobalConf::set('main.safe-mode', $opt->{safeMode});
    Egnee::GlobalConf::set('stem-finder.safe-mode', 1);
    Egnee::GlobalConf::set('ExampleGC.threshold', $opt->{gc_threshold});
    Egnee::GlobalConf::set('ExampleGC.limit', $opt->{gc_limit});
    Egnee::GlobalConf::set('standardformat-document.use-knp-annotation', 0);
    my $egnee = Egnee->new({ debug => $opt->{debug} });
    $egnee->addUsageMonitor({ suffix => 1, reset => $opt->{doLoad}, debug => $opt->{debug} });
    $egnee->setDictionaryCallback(\&processEvent);

    if (Egnee::GlobalConf::get('working-dictionary.do-load')) {
	$egnee->{dictionaryManager}->{workingDictionary}->update;
    }

    my ($host, $port) = split(/\:/, $opt->{master});
    my $PROXY_CLASS = 'CrawlerMaster::Proxy';
    my $client = Event::RPC::Client->new(
	host => $host,
	port => $port,

	error_cb => sub {
	    my ($client, $error) = @_;
	    print STDERR ("An RPC error occured: $error\n");
	    $client->disconnect;
	    exit;
	},
	classes => [ $PROXY_CLASS ],
	);
    $client->connect;
    my $obj = $PROXY_CLASS->new('WORKER');

    my $handler = sub {
	my ($signame) = @_;
	printf STDERR ("%s\n", $signame);
	$obj->close if (defined($obj));
	$client->disconnect if (defined($client));
	exit 1;
    };
    $SIG{INT} = $SIG{TERM} = $handler;

    # main loop
    eval {
	while (1) {
	    my ($cmd, $args) = $obj->requestJob;
	    if ($cmd eq 'PAGE') {
		printf STDERR ("PAGE: %s\n", $args);
		&processPage($egnee, $args);
	    } elsif ($cmd eq 'NOOP') {
		printf STDERR ("NOOP\n");
		sleep(55);
	    } elsif ($cmd eq 'SEND_DIC') {
		printf STDERR ("SEND_DIC: %s\n", $args);
		$egnee->{workingDictionary}->saveAsDictionary($args);
		$obj->notifyDicSave;
	    } elsif ($cmd eq 'STOP') {
		printf STDERR ("STOP\n");
		last;
	    } else {
		die("unsupported command\n");
	    }
	    sleep(1);
	}
    };
    if ($@) {
	printf STDERR ("error: %s", $@);
    }
    $obj->close;
    $client->disconnect;
}

sub processPage {
    my ($egnee, $pagePath) = @_;

    my $document = Document::StandardFormat->new($pagePath);
    my $sentence = $egnee->processDocument($document);
}

sub processEvent {
    my ($event) = @_;

    if ($event->{type} eq 'example') { # ExampleEvent
	# $event->{string} = $event->{obj}->{pivot};
    } elsif ($event->{type} eq 'beforeChange') {
	; # do nothing
    } elsif ($event->{type} eq 'append') { # DictionaryChange
	my $me = $event->{obj};
	my $mrph = $me->getJumanMorpheme;
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	$event->{string} = $mrph->genkei . ':' . $posS;
	printf STDERR ("APPEND %s:%s", $mrph->genkei, $posS);
    } elsif ($event->{type} eq 'decompose') {
	my $me = $event->{obj};
	my $mrph = $me->getJumanMorpheme;
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	$event->{string} = $mrph->genkei . ':' . $posS;
	printf STDERR ("DECOMPOSE %s:%s", $mrph->genkei, $posS);
    } else {
	printf STDERR ("unsupported dictionary event type\n");
    }
}

unless (caller) {
    &main;
}

1;
