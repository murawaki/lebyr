#!/bin/env perl
#
# track noun features
#
package Example;

use strict;
use utf8;
use warnings;

my $TYPE_THRES = 100;
my $CORE_THRES = 20;

our $nonCoreRegions;
sub setNonCoreRegions {
    $nonCoreRegions = $_[1];
}

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	name => shift,
	classList => {},
	featureList => {},
	coreCount => 0,
	upToDate => 1,   # for lazy evaluation of coreCount after merging
    };
    bless($self, $class);
    return $self;
}

sub isComplete {
    my ($self) = @_;
    if (scalar(keys(%{$self->{featureList}})) >= $TYPE_THRES) {
	unless ($self->{upToDate}) {
	    $self->calcCoreCount;
	}
	return 1 if ($self->{coreCount} >= $CORE_THRES);
    }
    return 0;
}

# reset coreCount
sub calcCoreCount {
    my ($self) = @_;
    $self->{coreCount} = 0;
    while ((my ($fid, $v) = each(%{$self->{featureList}}))) {
	unless (($fid >= $nonCoreRegions->[0]->[0] && $fid <= $nonCoreRegions->[0]->[1])
		|| ($fid >= $nonCoreRegions->[1]->[0] && $fid <= $nonCoreRegions->[1]->[1])) {
	    $self->{coreCount}++;
	}
    }
    $self->{upToDate} = 1;
}

sub add {
    my ($self, $classString, $fid) = @_;
    foreach my $c (split(/\?/, $classString)) {
	$self->{classList}->{$c}++;
    }
    if (defined($self->{featureList}->{$fid})) {
	$self->{featureList}->{$fid}++;
    } else {
	$self->{featureList}->{$fid} = 1;
	unless (($fid >= $nonCoreRegions->[0]->[0] && $fid <= $nonCoreRegions->[0]->[1])
		|| ($fid >= $nonCoreRegions->[1]->[0] && $fid <= $nonCoreRegions->[1]->[1])) {
	    $self->{coreCount}++;
	}
    }
}

sub merge {
    my ($self, $example) = @_;
    while ((my ($c, $v) = each(%{$example->{classList}}))) {
	no warnings qw(uninitialized);
	$self->{classList}->{$c} += $v;
    }
    while ((my ($fid, $v) = each(%{$example->{featureList}}))) {
	no warnings qw(uninitialized);
	$self->{featureList}->{$fid} += $v;
    }
    $self->{upToDate} = 0;  # re-calc coreCount when necessary
}

1;


package main;

use strict;
use utf8;
use warnings;

# use Example;
use Getopt::Long;
use IO::File;
# use PerlIO::via::Bzip2; # MEMORY LEAK!!!!
use Storable qw/retrieve nstore/;
use Text::Bayon;

binmode(STDIN,  ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $opt = { acquired => 0, verbose => 1, both => 1 };
GetOptions($opt, 'debug',
	   'verbose=i',
	   'input=s', 'dir=s', 'start=i', 'end=i',
	   'compressed', 'fDB=s', 'acquired', 'both!');

my $limited;
if (defined($opt->{start}) || defined($opt->{end})) {
    $limited = 1;
    $opt->{start} = -1 unless (defined($opt->{start}));
    $opt->{end} = 0xFFFFFFFF unless (defined($opt->{end}));
} else {
    $limited = 0;
}

# global vars
my $currentDomain = '';
my $domainCount = 0;
my $CLUSTERING_INTERVAL = 1000;
my $clusteringCount = 0;
my $CLUSTERING_CLEAR_INTERVAL = 10;
my $wholeStruct = {};  # domain -> name := example
my $structDomain = {};
my $structPage = {};
my $ngList = {};

die unless (defined($opt->{'fDB'}));
die unless ( -f $opt->{'fDB'} );
printf STDERR ("loading %s\n", $opt->{fDB}) if ($opt->{debug});
my $fDB = retrieve($opt->{fDB}) or die;
Example->setNonCoreRegions(&getFDBRegions($fDB));

if ($opt->{input}) {
    &processFile($opt->{input});
} else {
    my $counter = 0;
    opendir(my $dirh, $opt->{dir}) or die;
    foreach my $ftmp (sort {$a cmp $b} (readdir($dirh))) {
	# next unless ($ftmp =~ /\.out$/);
	next unless ( -f "$opt->{dir}/$ftmp" );
	if ($limited) {
	    if ($ftmp =~ /(\d+)/) {
		my $num = $1;
		next if ($num < $opt->{start} || $num > $opt->{end});
	    } else {
		next;
	    }
	}

	print STDERR ("examine $ftmp\n") if ($opt->{debug});

	&processFile("$opt->{dir}/$ftmp");

	$counter++;
    }
    &onPageChanged;
    &onDomainChanged;
    print STDERR ("$counter files processed\n") if ($opt->{debug});
}

1;

sub processFile {
    my ($filePath) = @_;

    my $f = &iterInit($filePath);
    while ((my $tmp = &iterNext($f))) {
	no warnings qw(uninitialized);

	my ($name, $classString, $ftype, $fname) = @$tmp;
	my $fid = $fDB->{$ftype}->{$fname};
	next unless (defined($fid));

	my $example = $structPage->{$name};
	unless (defined($example)) {
	    $example = $structPage->{$name} = Example->new($name);
	}
	$example->add($classString, $fid);
    }
    &onPageChanged;
    &iterClose ($f);
}

sub onPageChanged {
    while ((my ($name, $example) = each(%$structPage))) {
	if ($example->isComplete) {
	    &printExample($example, "page");
	} else {
	    my $example2 = $structDomain->{$name};
	    if ($example2) {
		$example2->merge($example);
		if ($example2->isComplete) {
		    &printExample($example2, "domain");
		    delete($structDomain->{$name});
		}
	    } else {
		$structDomain->{$name} = $example;
	    }
	}
    }
    $structPage = {};
}

sub onDomainChanged {
    my $isCleared = 1;
    while ((my ($name, $example) = each(%$structDomain))) {
	if ($example->isComplete) {
	    &printExample($example, "domain");
	} else {
	    no warnings qw/uninitialized/;

	    $wholeStruct->{$currentDomain}->{$name} = $example;
	    $isCleared = 0;
	}
    }
    $structDomain = {};
    $ngList = {};
    unless ($isCleared) {
	unless (++$domainCount % $CLUSTERING_INTERVAL) {
	    &doClustering;
	}
    }
}

sub doClustering {
    my $bayon = Text::Bayon->new; # renew every time
    my $domainVector = {};
    while ((my ($domain, $exampleList) = each(%$wholeStruct))) {
	my $t = $domainVector->{$domain} = {};
	while ((my ($name, $example) = each(%$exampleList))) {
	    $t->{$name} = scalar(keys(%{$example->{featureList}}));
	}
    }
    my ($clusterList) = $bayon->clustering($domainVector,
					   { number => 10, point => 1, clvector_size => 800 });
    foreach my $cluster (@$clusterList) {
	next unless (defined ($cluster));
	next unless (scalar (@$cluster) > 1);
	my $nounList = {};
	my $noun2domain = {};
	foreach my $tmp (@$cluster) {
	    my ($domain) = @$tmp;
	    my $exampleList = $wholeStruct->{$domain};
	    while ((my ($name, $example) = each(%$exampleList))) {
		push(@{$noun2domain->{$name}}, $domain);
		if (defined($nounList->{$name})) {
		    $nounList->{$name}->merge($example);
		} else {
		    $nounList->{$name} = $example;
		}
	    }
	}
	while ((my ($name, $example) = each(%$nounList))) {
	    if ($example->isComplete) {
		&printExample($example, "cluster");
		foreach my $domain (@{$noun2domain->{$name}}) {
		    delete($wholeStruct->{$domain}->{$name});
		}
	    }
	}
    }
    foreach my $domain (keys(%$wholeStruct)) {
	if (scalar(keys(%{$wholeStruct->{$domain}})) <= 0) {
	    delete($wholeStruct->{$domain});
	    printf STDERR ("domain %s cleared\n", $domain) if ($opt->{debug});
	}
    }
    printf STDERR ("there remain %d domains\n", scalar(keys(%$wholeStruct))) if ($opt->{debug});
    unless (++$clusteringCount % $CLUSTERING_CLEAR_INTERVAL) {
	printf STDERR ("clear whole struct\n") if ($opt->{debug});
	$wholeStruct = {};
    }
}

sub printExample {
    my ($example, $type) = @_;

    my $name = $example->{name};
    my $isNG = (!$opt->{acquired} && defined($ngList->{$name}))? '$' : '';
    my $classString = join ('?', sort { $a cmp $b } (keys(%{$example->{classList}})) );
    my $fidString = join ("\t", map { $_ . ':' . $example->{featureList}->{$_} } sort { $a <=> $b } (keys(%{$example->{featureList}})) );
    print("$isNG$name\t$classString\t$type\t$fidString\n");
}

sub iterInit {
    my ($filepath) = @_;
    my $input;
    if ($opt->{compressed}) {
	open($input, '-|', "bzcat $filepath");
	binmode($input, ':utf8');
    } else {
	open($input, "<:utf8", $filepath) or die;
    }
    return $input;
}

sub iterNext {
    my ($f) = @_;
    while (1) {
	my $line = $f->getline;
	return undef unless (defined($line));

	chomp ($line);
	if ($line =~ /^\#document\s([^\s]+)\s([^\s]+)/) {
	    my ($documentID, $domain) = ($1, $2);
	    &onPageChanged;
	    if ($domain ne $currentDomain) {
		&onDomainChanged;
		$currentDomain = $domain;
	    }
	    next;
	} elsif ($line =~ /^\$ (.+)/) {
	    $ngList->{$1}++;
	    next;
	} elsif ($line =~ /^\#/) {
	    next;
	}
	my @tmp = split(/\s/, $line);
	unless ($opt->{both}) {
	    if ($opt->{acquired}) {
		next unless ($tmp[0] =~ /\*$/);
		chop($tmp[0]);
	    } else {
		next if ($tmp[0] =~ /\*$/);
	    }
	}
	return \@tmp;
    }
}

sub iterClose {
    my ($f) = @_;
    $f->close;
}

sub getFDBRegions {
    my ($fDB) = @_;

    my ($min, $max) = (1E100, 0);
    while ((my ($fname, $fid) = each(%{$fDB->{'next'}}))) {
	$min = $fid if ($fid < $min);
	$max = $fid if ($fid > $max);
    }
    my $regions = [[$min, $max]];
    ($min, $max) = (1E100, 0);
    while ((my ($fname, $fid) = each(%{$fDB->{'prev'}}))) {
	$min = $fid if ($fid < $min);
	$max = $fid if ($fid > $max);
    }
    push(@$regions, [$min, $max]);
    return $regions;
}
