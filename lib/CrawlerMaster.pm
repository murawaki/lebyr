package CrawlerMaster;

use strict;
use warnings;
no warnings qw/redefine/;
use utf8;

use IO::Dir;
use Data::UUID;
use Scalar::Util qw/refaddr/;
use base qw /Class::Data::Inheritable/;

use CrawlerMaster::Proxy;

__PACKAGE__->mk_classdata(PROXY => 'CrawlerMaster::Proxy');
__PACKAGE__->mk_classdata(PAGE_MODE => 1);
__PACKAGE__->mk_classdata(MERGE_MODE => 2);
__PACKAGE__->mk_classdata(STOP_MODE => 3);

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	mode => __PACKAGE__->PAGE_MODE,
	currentList => undef,
	jobQueue => [],
	workers => {}, # refaddr -> objref
	opt => shift,
    };
    $self->{opt}->{recursive} = 1 unless (defined($self->{opt}->{recursive}));
    $self->{opt}->{rmDir} = 1 unless (defined($self->{opt}->{rmDir}));
    bless($self, $class);
    $self->PROXY->setSingleton($self);
    return $self;
}

sub register {
    my ($self, $proxy) = @_;

    printf STDERR ("register %s\n", refaddr($proxy));

    $self->{workers}->{refaddr($proxy)} = $proxy;
}

sub unregister {
    my ($self, $proxy) = @_;

    printf STDERR ("unregister %s\n", refaddr($proxy));

    delete($self->{workers}->{refaddr($proxy)});
}

sub appendJob {
    my ($self, $dirPath) = @_;

    printf STDERR ("append $dirPath\n");

    # NOTE: does not check duplicates
    unless ( -d $dirPath ) {
	return ("ERROR", "no such directory found: $dirPath");
    }
    push(@{$self->{jobQueue}}, $dirPath);
    return ("OK");
}

sub queueSize {
    my ($self) = @_;
    return scalar(@{$self->{jobQueue}});
}

sub requestJob {
    my ($self, $proxy) = @_;

    printf STDERR ("request: %s\n", refaddr($proxy));

    my $pageMode = 0;
    if ($self->{mode} == $self->MERGE_MODE) {
	my $wid = refaddr($proxy);
	my $status = $self->{merge}->{status}->{$wid};
	if (!defined($status)) {
	    # ask the worker to send its dic
	    $self->{merge}->{status}->{$wid} = 1;
	    my $dicpath = sprintf("%s/%s.dic", $self->{merge}->{basedir}, $wid);
	    push(@{$self->{merge}->{dicList}}, $dicpath);
	    printf STDERR ('send dic: %s\n', $dicpath);
	    return ('SEND_DIC', $dicpath);
	} else {
	    if ($status == 1) {
		printf STDERR ("something wrong with dictionary merge (wid: %s)\n", $wid);
	    }
	    $pageMode = 1;
	}
    }
    if ($pageMode || $self->{mode} == $self->PAGE_MODE) {
	my $path = $self->nextFile;
	if (defined($path)) {
	    return ('PAGE', $path);
	} else {
	    return ('NOOP');
	}
    } elsif ($self->{mode} == $self->STOP_MODE) {
	return ('STOP');
    } else {
	return ('ERROR', "under construction\n");
    }
}

sub startMerge {
    my ($self, $path) = @_;

    printf STDERR ("start merge\n");

    unless ($self->{mode} == $self->PAGE_MODE) {
	return ('ERROR', "merge in progress");
    }
    $self->{mode} = $self->MERGE_MODE;
    $self->{merge} = { 
	basedir => $path,
	id => Data::UUID->new->create_str,
	dicList => [], # unused
	status => {},
    };
    return $self->{merge}->{id};
}

sub notifyDicSave {
    my ($self, $proxy) = @_;

    my $wid = refaddr($proxy);
    $self->{merge}->{status}->{$wid} = 2;
    my ($status, $opt) = $self->mergeStatus;
    if ($status eq 'COMPLETE') {
	$self->{mergeDone}->{$self->{merge}->{id}} = 1;
	$self->{mode} = $self->PAGE_MODE;
    }
}

sub mergeStatus {
    my ($self, $id) = @_;

    if (defined($id)) {
	printf STDERR ("merge status: %s\n", $id);
	unless ($self->{mode} == $self->MERGE_MODE) {
	    if ($self->{mergeDone}->{$id}) {
		return ("COMPLETE");
	    } else {
		return ("ERROR", "not in the merge mode");
	    }
	}
    }

    # worker might be killed immediately after the merge request
    # the status check is based on the list of __current__ workers
    my $statusAgg = [0, 0, 0];
    while (my $wid = each(%{$self->{workers}})) {
	my $status = $self->{merge}->{status}->{$wid} || 0;
	$statusAgg->[$status]++;
    }
    if ($statusAgg->[0] + $statusAgg->[1] <= 0) {
	return ("COMPLETE");
    } else {
	return ("IN_PROGRESS", sprintf("%d started, %d requested, %d complete", @$statusAgg));
    }
}

sub stopWorkers {
    my ($self) = @_;
    $self->{mode} = $self->STOP_MODE;
}

sub lastDir {
    my ($self) = @_;
    return $self->{lastDir};
}

sub nextFile {
    my ($self) = @_;
    my $fileList = $self->{currentList};
    unless (defined($fileList) && scalar(@$fileList) > 0) {
	while (scalar(@{$self->{jobQueue}}) > 0) {
	    if (defined($self->{lastDir}) && $self->{opt}->{rmDir}) {
		my $cmd = sprintf("rm -rf %s &", $self->{lastDir});
		printf STDERR ("%s\n", $cmd);
		`$cmd`; # background process
	    }
	    my $dir = $self->{lastDir} = shift(@{$self->{jobQueue}});
	    $fileList = $self->{currentList} = $self->expandDir($dir);
	    last if (scalar(@$fileList) > 0);
	}
    }
    if (defined($fileList) && scalar(@$fileList) > 0) {
	return shift(@$fileList);
    } else {
	return undef;
    }
}

sub expandDir {
    my ($self, $dirPath) = @_;

    printf STDERR ("expand $dirPath\n");

    my $fileList = [];
    my $dirPathList = [$dirPath];
    while ((my $dirPath = shift(@$dirPathList))) {
	my $dir = IO::Dir->new($dirPath) or next;
	my $dirList = [];
	foreach my $ftmp (sort {$a cmp $b} ($dir->read)) {
	    my $filePath = $dirPath . '/' . $ftmp;
	    next if ($filePath =~ /\.$/); # self
	    if ( -d $filePath && $self->{opt}->{recursive}) {
		push(@$dirList, $filePath);
	    } elsif ($ftmp =~ /([^\/]*)\.xml(?:\.gz)?$/) {
		push(@$fileList, $filePath);
	    }
	}
	$dir->close;
	unshift(@$dirPathList, @$dirList); # ordered, depth-first search
    }
    return $fileList;
}

1;
