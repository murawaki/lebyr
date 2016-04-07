#!/bin/env perl
#
# 得られた格フレームをマージする
#
use strict;
use utf8;

use Getopt::Long;
use IO::File;
use PerlIO::via::Bzip2;
use TinySVM;

binmode (STDIN,  ':utf8');
binmode (STDOUT, ':utf8');
binmode (STDERR, ':utf8');

my $opt = { verbose => 1, freq => 0, thres => 5, type => 'one-versus-rest' };
GetOptions ($opt, 'debug', 'input=s', 'modeldir=s', 'compressed', 'freq!', 'thres=i', 'type=s');

my $modelSpecList =
    [{ type => '人名', path => 'person.ne.model' },
     { type => '人', path => 'person.cat.model' },
     { type => '地名', path => 'location.ne.model' },
     { type => '場所-施設;場所-自然', path => 'location.cat.model' },
     { type => '組織名', path => 'organization.ne.model' },
     { type => '組織・団体', path => 'organization.cat.model' },
     { type => 'その他', path => 'other.model' },
    ];

my $modelGroupASpecList =
    [{ type => 'person', path => 'person.model',
       subpath => 'person.ne-cat.model', positive => '人名', negative => '人' },
     { type => 'location', path => 'location.ne.model',
       subpath => 'location.ne-cat.model', positive => '地名', negative => '場所-施設;場所-自然' },
     { type => 'organization', path => 'organization.ne.model',
       subpath => 'organization.ne-cat.model', positive => '組織名', negative => '組織・団体' },
     { type => 'その他', path => 'other.model' },
    ];

my $partialTypeList = {
    '人名' => '人', '人' => '人名',
    '地名' => '場所-施設;場所-自然', '場所-施設' => '地名', '場所-自然' => '地名',
    '組織名' => '組織・団体', '組織・団体' => '組織名',
};

my $modelGroupBSpecList =
    [{ type => 'ne', path => 'ne.model',
       subgroup =>
	   [{ type => '人名', path => 'ne.person.model' },
	    { type => '地名', path => 'ne.location.model' },
	    { type => '組織名', path => 'ne.organization.model' }
	    ]},
     { type => 'cat', path => 'cat.model',
       subgroup =>
	   [{ type => '人', path => 'cat.person.model' },
	    { type => '場所-施設;場所-自然', path => 'cat.location.model' },
	    { type => '組織・団体', path => 'cat.organization.model' }
	    ]},
     { type => 'その他', path => 'other.model' },
    ];

if ($opt->{type} eq 'one-versus-rest') {
    foreach my $modelSpec (@$modelSpecList) {
	my $filepath = $opt->{modeldir} . '/' . $modelSpec->{path};
	-f $filepath or die ("$filepath not found\n");

	my $m = TinySVM::Model->new;
	$m->read ($filepath);
	$modelSpec->{model} = $m;
    }
} elsif ($opt->{type} eq 'one-versus-rest-groupedA') {
    foreach my $modelSpec (@$modelGroupASpecList) {
	my $filepath = $opt->{modeldir} . '/' . $modelSpec->{path};
	-f $filepath or die ("$filepath not found\n");

	my $m = TinySVM::Model->new;
	$m->read ($filepath);
	$modelSpec->{model} = $m;

	if ($modelSpec->{subpath}) {
	    my $filepath = $opt->{modeldir} . '/' . $modelSpec->{path};
	    -f $filepath or die ("$filepath not found\n");

	    my $m = TinySVM::Model->new;
	    $m->read ($filepath);
	    $modelSpec->{submodel} = $m;
	}
    }
} elsif ($opt->{type} eq 'one-versus-rest-groupedB') {
    foreach my $modelSpec (@$modelGroupBSpecList) {
	my $filepath = $opt->{modeldir} . '/' . $modelSpec->{path};
	-f $filepath or die ("$filepath not found\n");

	my $m = TinySVM::Model->new;
	$m->read ($filepath);
	$modelSpec->{model} = $m;

	if ($modelSpec->{subgroup}) {
	    foreach my $subModelSpec (@{$modelSpec->{subgroup}}) {
		my $filepath = $opt->{modeldir} . '/' . $subModelSpec->{path};
		-f $filepath or die ("$filepath not found\n");

		my $m = TinySVM::Model->new;
		$m->read ($filepath);
		$subModelSpec->{model} = $m;
	    }
	}
    }
}


my $ok = 0;
my $total = 0;
my $partial = 0;

my $filepath = $opt->{input};
my $input = IO::File->new ($filepath, 'r') or die;
$input->binmode (($opt->{compressed})? ':via(Bzip2):utf8' : ':utf8');
while ((my $line = $input->getline)) {
    chomp;
    my @tmp = split (/\s/, $line);

    my $type = shift (@tmp);
    my $repname = shift (@tmp);

    next unless (scalar (@tmp) >= $opt->{thres});

    my $feature = join (' ', (map { my ($k, $v) = split (/\:/, $_); "$k:1" } (@tmp))) . "\n";

    my ($maxType, $maxV);
    if ($opt->{type} eq 'one-versus-rest') {
	($maxType, $maxV) = &classifyOneVersusRest ($feature);
    } elsif ($opt->{type} eq 'one-versus-rest-groupedA') {
	($maxType, $maxV) = &classifyOneVersusRestGroupedA ($feature);
    } elsif ($opt->{type} eq 'one-versus-rest-groupedB') {
	($maxType, $maxV) = &classifyOneVersusRestGroupedB ($feature);
    }

    $total++;
    my $answer;
    if ($maxType eq $type || $maxType =~ /\;$type/ || $maxType =~ /$type\;/) {
	$ok++;
	$answer = 'ok';
    } else {
	$answer = 'bad';

	my $partialType = $partialTypeList->{$type};
	if ($maxType eq $partialType) {
	    print ("partial $maxType $type\n");
	    $partial++;
	}
    }
    printf ("%s %s %s, %s %f\n", $answer, $repname, $type, $maxType, $maxV);
}
$input->close;

printf ("%f (%d / %d)\t(%d / %d)\n", $ok / $total, $ok, $total, $partial, $total - $ok);

sub classifyOneVersusRest {
    my ($feature) = @_;

    my $maxV = -1e1024;
    my $maxType;
    foreach my $modelSpec (@$modelSpecList) {
	my $r = $modelSpec->{model}->classify ($feature);

	# printf ("%s : %g\n", $modelSpec->{type}, $r);

	if ($r > $maxV) {
	    $maxV = $r;
	    $maxType = $modelSpec->{type};
	}
    }
    return ($maxType, $maxV);
}

sub classifyOneVersusRestGroupedA {
    my ($feature) = @_;

    my $maxV = -1e1024;
    my $maxModelSpec;
    foreach my $modelSpec (@$modelGroupASpecList) {
	my $r = $modelSpec->{model}->classify ($feature);

	if ($r > $maxV) {
	    $maxV = $r;
	    $maxModelSpec = $modelSpec;
	}
    }
    my $maxType;
    if ($maxModelSpec->{submodel}) {
	$maxV = $maxModelSpec->{submodel}->classify ($feature);
	$maxType = ($maxV >= 0)? $maxModelSpec->{positive} : $maxModelSpec->{negative};
    } else {
	$maxType = $maxModelSpec->{type};
    }

    return ($maxType, $maxV);
}


sub classifyOneVersusRestGroupedB {
    my ($feature) = @_;

    my $maxV = -1e1024;
    my $maxModelSpec;
    foreach my $modelSpec (@$modelGroupBSpecList) {
	my $r = $modelSpec->{model}->classify ($feature);

	if ($r > $maxV) {
	    $maxV = $r;
	    $maxModelSpec = $modelSpec;
	}
    }
    my $maxType;

    if ($maxModelSpec->{subgroup}) {
	$maxV = -1e1024;
	foreach my $modelSpec (@{$maxModelSpec->{subgroup}}) {
	    my $r = $modelSpec->{model}->classify ($feature);

	    if ($r > $maxV) {
		$maxV = $r;
		$maxModelSpec = $modelSpec;
	    }
	}
    }
    $maxType = $maxModelSpec->{type};

    return ($maxType, $maxV);
}

1;
