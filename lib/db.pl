use strict;
use warnings;

use Encode;
use CDB_File;

our $enc = Encode::find_encoding('utf8');

sub openDB ($;$) {
    my ($path, $opt) = @_;
    $opt = {} unless (defined($opt));

    my ($hash, $db);
    $db = tie(%$hash, 'CDB_File', $path) or die;
    if ($opt->{filterKey}) {
	$db->filter_fetch_key(sub { $enc->decode($_) });
    }
    if ($opt->{filterValue}) {
	$db->filter_fetch_value(sub { $enc->decode($_) });
    }
    return wantarray? ($hash, $db) : $hash;
}

sub closeDB ($) {
    my ($hash) = @_;
    untie(%$hash);
}

sub createCDB ($$;$) {
    my ($hash, $path, $opt) = @_;
    $opt = {} unless (defined($opt));

    my $db = CDB_File->new($path, "$path.$$") or die "$!";
    if ($opt->{filterKey}) {
	if ($opt->{filterValue}) {
	    while ((my $key = each(%$hash))) {
		$db->insert($enc->encode($key), $enc->encode($hash->{$key}));
	    }
	} else {
	    while ((my $key = each(%$hash))) {
		$db->insert($enc->encode($key), $hash->{$key});
	    }
	}
    } else {
	if ($opt->{filterValue}) {
	    while ((my $key = each(%$hash))) {
		$db->insert($key, $enc->encode($hash->{$key}));
	    }
	} else {
	    while ((my $key = each(%$hash))) {
		$db->insert($key, $hash->{$key});
	    }
	}
    }
    $db->finish;
}

1;
