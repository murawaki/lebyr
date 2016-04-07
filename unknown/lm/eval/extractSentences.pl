#!/bin/env perl
#
# 対象文書から文だけを抜き出す
#
use strict;
use warnings;
use utf8;

use Encode;
use Getopt::Long;

use Egnee::GlobalConf;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { conf => "/home/murawaki/research/lebyr/prefs" };
GetOptions($opt, 'conf=s', 'dir=s', 'spec=s', 'debug');

die unless ( -d $opt->{dir} );
$opt->{conf} = $opt->{spec} if (defined($opt->{spec})); # backward compatibility
my $inputDir = $opt->{dir};

&init;

use DocumentPool::DirectoryBased;
my $documentPool = DocumentPool::DirectoryBased->new($inputDir, { debug => 1 });
##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################
my $document;
while (($document = $documentPool->get)) {
    my $documentID = $document->getAnnotation('documentID');
#     # 適当に文書を飛ばす
#     # XML の読み込みは行なっているので、
#     # 速度はそれほど向上しない
#     if (rand () > 0.1) {
# 	printf STDERR ("skip $documentID\n");
# 	next;
#     }
    printf STDERR ("document\t%s\n", $documentID) if ($opt->{debug});
    printf("#document\t%s\n", $documentID) if ($documentID);

    my $sentenceList = $document->getAnalysis('sentence');
    next unless (defined ($sentenceList));
    my $iterator = $sentenceList->getIterator;
    while ((my $sentence = $iterator->nextNonNull)) {
	my $rawstring = $sentence->get('raw');
	print($rawstring);
    }
}

# 諸々の初期化
sub init {
    Egnee::GlobalConf::loadFile($opt->{conf});
    Egnee::GlobalConf::set('standardformat-document.use-knp-annotation', 1);
}

1;
