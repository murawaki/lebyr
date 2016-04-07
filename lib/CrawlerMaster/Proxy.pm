package CrawlerMaster::Proxy;
#
# proxy object for accessing to the singleton CrawlerMaster::Main
#
use strict;
use warnings;
no warnings qw/redefine/;
use utf8;

our $singleton;

sub setSingleton {
    $singleton = $_[1];
}

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = {
	type => shift,
    };
    bless($self, $class);
    if ($self->{type} eq 'WORKER') {
	$singleton->register($self);
    }
    return $self;
}

sub close {
    my ($proxy) = @_;
    $proxy->DESTROY;
}

sub DESTROY {
    my ($proxy) = @_;
    if ($proxy->{type} eq 'WORKER') {
	$singleton->unregister($proxy);
    }
}

sub appendJob {
    my ($proxy, $dir) = @_;
    return $singleton->appendJob($dir);
}

sub queueSize {
    my ($proxy) = @_;
    return $singleton->queueSize;
}

sub requestJob {
    my ($proxy) = @_;
    return $singleton->requestJob($proxy);
}

sub startMerge {
    my ($proxy, $path) = @_;
    return $singleton->startMerge($path);
}

sub notifyDicSave {
    my ($proxy) = @_;
    return $singleton->notifyDicSave($proxy);
}

sub mergeStatus {
    my ($proxy, $id) = @_;
    return $singleton->mergeStatus($id);
}

sub stopWorkers {
    my ($proxy) = @_;
    return $singleton->stopWorkers;
}

sub lastDir {
    my ($proxy) = @_;
    return $singleton->lastDir;
}

1;
