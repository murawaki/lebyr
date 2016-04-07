#!/bin/env perl
#
# usage: perl mergeDicts.pl --list=list --output=merged.dic --limit=10
#
# simply merge multiple dictionaries into a single one
# need to call postprocess.pl for final cleanup
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use IO::File;

use MorphemeGrammar;
use JumanDictionary;
use MorphemeUtilities;
use JumanDictionary::MorphemeEntry;
use JumanDictionary::MorphemeEntry::Annotated;

sub main {
    binmode(STDIN,  ':utf8');
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');

    my $opt = {};
    GetOptions($opt, 'debug', 'output=s', 'limit=i', 'df_thres=i', 'clean', 'list=s');
    die unless ($opt->{output});

    my $ino;
    if ($opt->{list}) {
	$ino = IO::File->new($opt->{list}) or die;
	$ino->binmode(':utf8');
    } else {
	$ino = \*STDIN;
    }
    my @fileList = map { chomp($_) and $_ } ($ino->getlines);
    if ($opt->{list}) {
	$ino->close;
    }

    my $registered = {};
    my $count = 0;
    foreach my $filePath (@fileList) {
	printf("%05d\t%s\n", $count++, $filePath) if ($opt->{debug});
	# 辞書を読み込み初期化
	&load($filePath, $registered, $opt);
	last if (defined($opt->{limit}) && $count >= $opt->{limit});
    }
    printf("%s files processed\n", $count) if ($opt->{debug});

    my $ofile = IO::File->new($opt->{output}, 'w') or die;
    $ofile->binmode(':utf8');
    while ((my ($key, $entry) = each(%$registered))) {
	$ofile->print($entry->{me}->serialize, "\n");
    }
    $ofile->close;
}

sub load {
    my ($fileName, $registered, $opt) = @_;

    my $meList = JumanDictionary::MorphemeEntry::Annotated->readAnnotatedDictionary($fileName);
    foreach my $me (@$meList) {
	my $mrph = $me->getJumanMorpheme;

	my $stem = ($mrph->katuyou1 eq '*')? $mrph->genkei : (&MorphemeUtilities::decomposeKatuyou($mrph))[0];
	my $posS = &MorphemeGrammar::getPOSName($mrph);
	my $key = ($posS)? "$stem:$posS" : "$stem:RESERVED";

	my $annotation = $me->{annotation};
	delete($annotation->{posS});
	delete($annotation->{curID});
	foreach my $key (keys(%{$annotation->{domain}})) {
	    $annotation->{domainF}++;
	}
	delete($annotation->{domain});

	if ($opt->{df_thres}) {
	    next if ($annotation->{df} < $opt->{df_thres});
	}
	my $entry = {
	    me => $me,
	    stem => $stem,
	    posS => $posS,
	};

	if ($opt->{clean}) {
	    foreach my $key (keys(%$annotation)) {
		# hash データは巨大なので消す
		if (ref($annotation->{$key})) {
		    delete($annotation->{$key});
		}
	    }
	}

	if ($posS && ($posS =~ /名詞/ || $posS =~ /ナ(?:ノ)形容詞/)
	    && !defined($me->{'意味情報'}->{'普サナ識別'})) {
	    $me->{annotation}->{fusana}->{$posS}++;
	}

	if (defined($registered->{$key})) {
	    &addHash($registered->{$key}->{me}->{annotation}, $entry->{me}->{annotation});
	} else {
	    $registered->{$key} = $entry;
	}
    }
}

sub addHash {
    my ($h1, $h2) = @_;
    while ((my $k = each(%$h2))) {
	if (ref($h2->{$k})) {
	    if (defined($h1->{$k})) {
		&addHash($h1->{$k}, $h2->{$k});
	    } else {
		$h1->{$k} = $h2->{$k};
	    }
	} else {
	    $h1->{$k} += $h2->{$k};
	}
    }
}

unless (caller) {
    &main;
}

1;
