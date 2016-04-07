#!/bin/env perl
#
# identify variant morphemes using edit distance and distributional similarity
#
use strict;
use warnings;
use utf8;

use Getopt::Long;
use CalcSimilarityByCF;

use JumanDictionary;
use JumanDictionary::Mixed;
use JumanDictionary::Static;
use JumanDictionary::Util;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = {
    'debug' => 0,
    'tmpdir' => '/tmp',
    'autodic' => '/home/murawaki/research/lebyr/data/autodicraw',
    'midbNoun' => '/cedar1/local/nlp/perlmodule/CalcSimilarityByCF/db/all-compound-1-201101-mi',
    'midbPred' => '/cedar1/local/nlp/perlmodule/CalcSimilarityByCF/db/all-verb-201101-mi',
};
my $dicList = ['/home/murawaki/research/lebyr/data/dic',
	       '/home/murawaki/research/lebyr/data/wikipediadic'];
# HACK
my $stopWords = {
    'ちょー' => 1,
    'おばー' => 2,
    'ゲンさん' => 3,
};


sub main {
    GetOptions($opt, 'tmpdir=s', 'autodic=s', 'midbNoun=s', 'midbPred=s', 'mixed', 'debug');
    my ($mainDictionary, $workingDictionary) = &loadDic;
    my $staticList = $mainDictionary->getAllMorphemes;
    my $dynamicList = $workingDictionary->getAllMorphemes;

    my $dbPath = $opt->{tmpdir} . '/sim.db';
    use JumanDictionary::EditDistance;
    my $edit = JumanDictionary::EditDistance->new({ deleteOnExit => 1, debug => $opt->{debug} });
    $edit->buildFilterDB($dbPath, $staticList);
    # $edit->openFilterDB($dbPath);

    my $cscfNoun = CalcSimilarityByCF->new({});
    $cscfNoun->TieMIDBfile($opt->{midbNoun});
    my $cscfPred = CalcSimilarityByCF->new({});
    $cscfPred->TieMIDBfile($opt->{midbPred});
    $edit->setCSCF($cscfNoun, $cscfPred);
    foreach my $me (@$dynamicList) {
	next if ($stopWords->{(keys(%{$me->{'見出し語'}}))[0]});
	$edit->mergeVariant($me, $workingDictionary);
    }

    $workingDictionary->saveAsDictionary;
    # $workingDictionary->update;
}

sub loadDic {
    my $mainDictionary;
    if ($opt->{mixed}) {
	$mainDictionary = JumanDictionary::Mixed->new;
	foreach my $dic (@$dicList) {
	    $mainDictionary->add(JumanDictionary::Static->new($dic));
	}
    } else {
	$mainDictionary = JumanDictionary::Static->new($dicList->[0]);
    }
    my $workingDictionary = JumanDictionary->new($opt->{autodic},
						 { writable => 1, annotation => 0, doLoad => 1 });
    return ($mainDictionary, $workingDictionary);
}

unless (caller) {
    &main;
}

1;
