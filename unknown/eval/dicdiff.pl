#!/bin/env perl
#
# JUMAN の辞書に関する統計情報を出す
#
use strict;
use utf8;

use IO::File;
use Getopt::Long;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 0 };
GetOptions($opt, 'verbose=i');

my $file1 = $ARGV[0];
$file1 = "$file1/output.dic" if ( -d $file1 );
die unless ( -f $file1 );
my $file2 = $ARGV[1];
$file2 = "$file2/output.dic" if ( -d $file2 );
die unless ( -f $file2 );

my $list1 = &loadDict($file1);
my $list2 = &loadDict($file2);

printf("1 total: %d\n", scalar(keys(%$list1)));
printf("2 total: %d\n", scalar(keys(%$list2)));
print("\n\n");


my $shared = '';my $ccc = 0;
my $only1 = ''; my $o1c = 0;
my $only2 = ''; my $o2c = 0;
while ((my $key = each(%$list1))) {
    my ($midasi, $pos) = split(/\:/, $key);

    if (defined($list2->{$key})) {
	$shared .= $list1->{$key};
	delete($list2->{$key});
	$ccc++;
    } else {
	$only1 .= $list1->{$key};
	$o1c++;
    }
}
while ((my $key = each(%$list2))) {
    $only2 .= $list2->{$key};
    $o2c++;
}

printf("shared:\t%d\n", $ccc);
printf("only 1:\t%d\n", $o1c);
printf("only 2:\t%d\n", $o2c);

if ($opt->{verbose} > 0) {
    printf("-----shared-----\n\n%s\n", $shared) if ($opt->{verbose} > 1 && $ccc > 0);
    printf("-----only1-----\n\n%s\n", $only1) if ($o1c > 0);
    printf("-----only2-----\n\n%s\n", $only2) if ($o2c > 0);
}
1;


sub loadDict {
    my ($file) = @_;

    my $f = IO::File->new($file) or die;
    $f->binmode(':utf8');

    my $list = {};
    while (my $line = $f->getline) {
	next if ($line =~ /^\;/);

	die unless ($line =~ /^\(([^\s]+)/);
	my $pos = $1;

	die unless ($line =~ /\(見出し語 ([^\)]+)/);
	my $midasi = $1;
	$list->{"$midasi:$pos"} = $line;
    }
    $f->close;
    return $list;
}

1;
