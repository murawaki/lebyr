#!/bin/env perl
#
#

use strict;
use utf8;

use Encode;
use Getopt::Long;
use XML::LibXML;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my %opt;
GetOptions (\%opt, 'debug');
# die ("Option Error!\n") if (!$opt{in} || !$opt{out});


##################################################
#                                                #
#                  main routine                  #
#                                                #
##################################################

my $buf = '';
while (<STDIN>) {
    $buf .= $_;
}

my $parser = new XML::LibXML;
my $doc = $parser->parse_string ($buf);

#binmode (STDOUT, ':bytes');
#print $doc->toString ();
#binmode (STDOUT, ':utf8');
my $nodeList = $doc->getElementsByTagName ('Text');
return undef if (!$nodeList);

#my $sList = $nodeList->get_node (0)->getElementsByTagName ('S');
#my @rv;
#my $sNode;
#while (($sNode = $sList->iterator ())) {
foreach my $sNode ($nodeList->get_node (0)->getElementsByTagName ('S')) {
    next if ($sNode->getAttribute ('is_Japanese_Sentence') ne '1');
    print "ID=", $sNode->getAttribute ('Id'), "\n";

#     my $rawstring = $sNode->getElementsByTagName ('RawString')->get_node (0);
#     foreach my $node ($rawstring->getChildNodes) {
# 	print $node->string_value (), "\n";
#     }

    my $annotation = $sNode->getElementsByTagName ('Annotation')->get_node (0);
#    foreach my $node ($annotation->getChildNodes) {
# 	print $node->string_value ();
#    }

    print $annotation->textContent () if ($annotation);
#    push (@rv, $sNode->getElementsByTagName ('Annotation')->get_node (0));
#    last; # debug
}

print "\n";

1;
