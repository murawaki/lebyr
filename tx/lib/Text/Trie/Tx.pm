package Text::Trie::Tx;
use strict;
use warnings;
use Carp;
our $VERSION = sprintf "%d.%02d", q$Revision: 0.1 $ =~ /(\d+)/g;
our $DEBUG = 0;

require XSLoader;
XSLoader::load('Text::Trie::Tx', $VERSION);

sub open{
    my $pkg = shift;
    my $filename = shift;
    my $dpi = xs_open($filename);
    carp __PACKAGE__, " cannot open $filename" unless $dpi;
    bless \$dpi, $pkg;
}

sub DESTROY{
    if ($DEBUG){
	no warnings 'once';
	require Data::Dumper;
	local $Data::Dumper::Terse  = 1;
	local $Data::Dumper::Indent = 0;
	warn "DESTROY:", Data::Dumper::Dumper($_[0]);
    }
    xs_free(${$_[0]});
}

sub prefixSearch{
    return xs_prefixSearch(${$_[0]}, $_[1]);
}

sub commonPrefixSearch{
    return xs_commonPrefixSearch(${$_[0]}, $_[1]);
}

sub commonPrefixSearchID{
    return xs_commonPrefixSearchID(${$_[0]}, $_[1]);
}

sub predictiveSearch{
    return xs_predictiveSearch(${$_[0]}, $_[1]);
}

sub predictiveSearchID{
    return xs_predictiveSearchID(${$_[0]}, $_[1]);
}

sub reverseLookup{
    return xs_reverseLookup(${$_[0]}, $_[1]);
}

sub getKeyNum{
    return xs_getKeyNum(${$_[0]});
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Text::Trie::Tx - Perl interface to Tx by OKANOHARA Daisuke

=head1 SYNOPSIS

  use Text::Trie::Tx; 
  my $td     = Text::Trie::Tx->open("words.tx");
  my $idList = $td->commonPrefixSearchID($input);
  $td->close

=head1 DESCRIPTION

Tx is a library for a compact trie data structure by OKANOHARA Daisuke.
Tx requires 1/4 - 1/10 of the memory usage compared to the previous
implementations, and can therefore handle quite a large number of keys
(e.g. 1 billion) efficiently.

=head1 REQUIREMENT

Tx 0.04 or above.  Available at 

L<http://www-tsujii.is.s.u-tokyo.ac.jp/~hillbig/tx.htm>

To install, just

  fetch http://www-tsujii.is.s.u-tokyo.ac.jp/~hillbig/software/tx-0.12.tar.gz
  tar zxvf tx-0.12.tar.gz
  cd tx-0.12
  configure
  make
  sudo make install

=head2 EXPORT

None.

=head1 SEE ALSO

L<http://www-tsujii.is.s.u-tokyo.ac.jp/~hillbig/tx.htm>

=head1 AUTHOR

Dan Kogai, E<lt>dankogai@dan.co.jpE<gt>
MURAWAKI Yugo, E<lt>murawaki@nlp.kuee.kyoto-u.ac.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Dan Kogai
Copyright (C) 2008-2009 by MURAWAKI Yugo

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
