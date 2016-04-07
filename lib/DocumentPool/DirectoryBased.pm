package DocumentPool::DirectoryBased;

use strict;
use utf8;
use warnings;

use Egnee::Logger;
use IO::Dir;
use Document::StandardFormat;
use Document::KNP;

# iterate over files in the specified directory

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {
	status => 0,
	dir => shift,
	opt => shift
    };

    # default values
    $self->{opt}->{debug} = 0 unless (defined($self->{opt}->{debug}));
    $self->{opt}->{recursive} = 1 unless (defined($self->{opt}->{recursive}));
    $self->{opt}->{tmpdir} = '/tmp' unless (defined($self->{opt}->{tmpdir}));

    bless($self, $class);
    Egnee::Logger::setLogger($self->{opt}->{debug});

    unless ( -d $self->{dir} ) {
	$self->{status} = -1;
    }
    return $self;
}

# get the file list at initialization
sub init {
    my ($self) = @_;

    $self->{documents} = [];
    $self->{pointer} = 0;

    my $dirPathList = [$self->{dir}];
    while ((my $dirPath = shift(@$dirPathList))) {
	my $dir = IO::Dir->new($dirPath) or die;
	my $dirList = [];
	foreach my $ftmp (sort {$a cmp $b} ($dir->read)) {
	    my $filePath = $dirPath . '/' . $ftmp;
	    next if ($filePath =~ /\.$/); # self
	    if ( -d $filePath && $self->{opt}->{recursive}) {
		push(@$dirList, $filePath);
	    } else {
		# treat an xml file as a StandardFormat
		if ($ftmp =~ /([^\/]*)\.xml$/) {
		    push(@{$self->{documents}}, { type => 'sf', path => $filePath, name => $1 });
		} elsif ($ftmp =~ /([^\/]*)\.xml\.gz$/) {
		    push(@{$self->{documents}}, { type => 'sfcomp', path => $filePath, name => $1 });
		} elsif ($ftmp =~ /([^\/]*)\.knp$/) {
		    push(@{$self->{documents}}, { type => 'knp', path => $filePath, name => $1 });
		} elsif ($ftmp =~ /([^\/]*)\.knp.gz$/) {
		    push(@{$self->{documents}}, { type => 'knpcomp', path => $filePath, name => $1 });
		}
	    }
	}
	$dir->close;
	unshift(@$dirPathList, @$dirList); # ordered, depth-first search
    }
    $self->{status} = 1;
}

sub get {
    my ($self) = @_;

    return undef if ($self->{status} < 0);
    $self->init if ($self->{status} == 0); # lazy evaluation

    return undef if ($self->{pointer} > $#{$self->{documents}});

    my $fstruct = $self->{documents}->[$self->{pointer}++];

    Egnee::Logger::info("document: $self->{dir}/$fstruct->{name}\n");

    # loading a StandardFormat
    # the problem dies when it fails to load the file
    # as we do not handle exceptions
    my $document;
    if ($fstruct->{type} eq 'sf') {
	$document = Document::StandardFormat->new($fstruct->{path});
    } elsif ($fstruct->{type} eq 'sfcomp') {
	my $tmpfile = $self->{opt}->{tmpdir} . '/' . $fstruct->{name} . '.xml';
	`gunzip -fc $fstruct->{path} > $tmpfile`;
	$document = Document::StandardFormat->new($tmpfile);
	unlink($tmpfile);
    } elsif ($fstruct->{type} eq 'knp') {
	$document = Document::KNP->new($fstruct->{path});
    } elsif ($fstruct->{type} eq 'knpcomp') {
	my $tmpfile = $self->{opt}->{tmpdir} . '/' . $fstruct->{name} . '.knp';
	$document = Document::KNP->new($tmpfile);
	unlink($tmpfile);
    } else {
	# ignore; keep going
	return $self->get;
    }
    $document->setAnnotation('documentID', $fstruct->{name});
    return $document;
}

# under construction
sub add {
    my ($self, $document) = @_;
    return;
}

sub isEmpty {
    my ($self) = @_;

    return ($#{$self->{documents}} >= 0);
}

1;
