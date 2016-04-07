####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package SExpression::Parser;
use vars qw ( @ISA );
use strict;

@ISA= qw ( Parse::Yapp::Driver );
use Parse::Yapp::Driver;

#line 9 "SExpression/Parser.yp"

use SExpression::Cons;


sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			"(" => 1,
			'SYMBOL' => 2,
			'NUMBER' => 5,
			'STRING' => 7
		},
		DEFAULT => -1,
		GOTOS => {
			'sexpression' => 4,
			'expression' => 3,
			'list' => 6
		}
	},
	{#State 1
		ACTIONS => {
			"(" => 1,
			'SYMBOL' => 2,
			'NUMBER' => 5,
			'STRING' => 7
		},
		GOTOS => {
			'expression' => 8,
			'list_interior' => 9,
			'list' => 6
		}
	},
	{#State 2
		DEFAULT => -4
	},
	{#State 3
		DEFAULT => -2
	},
	{#State 4
		ACTIONS => {
			'' => 10
		}
	},
	{#State 5
		DEFAULT => -3
	},
	{#State 6
		DEFAULT => -6
	},
	{#State 7
		DEFAULT => -5
	},
	{#State 8
		ACTIONS => {
			"(" => 1,
			'SYMBOL' => 2,
			"." => 12,
			'NUMBER' => 5,
			'STRING' => 7
		},
		DEFAULT => -10,
		GOTOS => {
			'expression' => 8,
			'list_interior' => 11,
			'list' => 6
		}
	},
	{#State 9
		ACTIONS => {
			")" => 13
		}
	},
	{#State 10
		DEFAULT => 0
	},
	{#State 11
		DEFAULT => -9
	},
	{#State 12
		ACTIONS => {
			"(" => 1,
			'SYMBOL' => 2,
			'NUMBER' => 5,
			'STRING' => 7
		},
		GOTOS => {
			'expression' => 14,
			'list' => 6
		}
	},
	{#State 13
		DEFAULT => -7
	},
	{#State 14
		DEFAULT => -8
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'sexpression', 0, undef
	],
	[#Rule 2
		 'sexpression', 1,
sub
#line 16 "SExpression/Parser.yp"
{ $_[0]->YYAccept; return $_[1]; }
	],
	[#Rule 3
		 'expression', 1, undef
	],
	[#Rule 4
		 'expression', 1,
sub
#line 20 "SExpression/Parser.yp"
{ $_[0]->handler->new_symbol($_[1]) }
	],
	[#Rule 5
		 'expression', 1,
sub
#line 21 "SExpression/Parser.yp"
{ $_[0]->handler->new_string($_[1]) }
	],
	[#Rule 6
		 'expression', 1, undef
	],
	[#Rule 7
		 'list', 3,
sub
#line 26 "SExpression/Parser.yp"
{ $_[2] }
	],
	[#Rule 8
		 'list_interior', 3,
sub
#line 31 "SExpression/Parser.yp"
{ $_[0]->handler->new_cons($_[1], $_[3]) }
	],
	[#Rule 9
		 'list_interior', 2,
sub
#line 32 "SExpression/Parser.yp"
{ $_[0]->handler->new_cons($_[1], $_[2]) }
	],
	[#Rule 10
		 'list_interior', 1,
sub
#line 33 "SExpression/Parser.yp"
{ $_[0]->handler->new_cons($_[1], undef) }
	]
],
                                  @_);
    bless($self,$class);
}

#line 42 "SExpression/Parser.yp"


sub set_input {
    my $self = shift;
    my $input = shift or die(__PACKAGE__ . "::set_input called with 0 arguments");
    $self->YYData->{INPUT} = $input;
}

sub set_handler {
    my $self = shift;
    my $handler = shift or die(__PACKAGE__ . "::set_handler called with 0 arguments");
    $self->YYData->{HANDLER} = $handler;
}

sub handler {
    my $self = shift;
    return $self->YYData->{HANDLER};
}

sub unparsed_input {
    my $self = shift;
    return substr($self->YYData->{INPUT}, pos($self->YYData->{INPUT}));
}


my %quotes = (q{'} => 'quote',
              q{`} => 'quasiquote',
              q{,} => 'unquote');


sub lexer {
    my $self = shift;

    $self->YYData->{INPUT} or return ('', undef);

#     my $symbol_char = qr{[*!\$[:alpha:]\p{Hiragana}\p{Katakana}\p{Han}\?<>=/+:_{}-]};
#    my $symbol_char = qr{[*!\$\p{InNonNumControl}\p{InCJKSymbolsAndPunctuation}\?<>=/+:_{}-]};
#    my $symbol_char = qr{([*!\$[:alpha:]\?<>=/+:_{}-]|\p{InCJKSymbolsAndPunctuation}|\p{InHalfwidthAndFullwidthForms}|\p{InLatin1Supplement}|\p{InLetterlikeSymbols}|\p{InHiragana}|\p{InKatakana})};

    for($self->YYData->{INPUT}) {
	# \s だと全角スペースもマッチするので [ \t\n\r] を使う
        $_ =~ /\G [ \t\n\r]* (?: ; .* [ \t\n\r]* )* /gcx;   # ignore comment

	# \d では全角数字も認識されてしまうので駄目
        /\G ([+-]? [0-9]+ (?:[.][0-9]*)?) /gcx
        || /\G ([+-]? [.] [0-9]+) /gcx
          and return ('NUMBER', $1);

	# 記号の扱いがうっとうしい
	my $str = $_;
	my $symbol = '';
	my $sym_re = qr{[*!\$\?<>=/+:_{}-]};
	my $pos = pos;
	my $i = $pos;
	while (1) {
	    my $c = substr ($str, $i, 1);
	    my $o = ord ($c);

	    if ($c =~ /$sym_re/ || $o >= 0x0080) {
		$symbol .= $c;
	    } elsif ($i > $pos && $c =~ /\d|\./) {
		$symbol .= $c;
	    } else {
		last;
	    }
	    last unless (++$i < length ($str));
	}
	if (length ($symbol)) {
	    pos = $i;
	    return ('SYMBOL', $symbol);
	}
	pos = $pos;

        /\G (\| [^|]* \|) /gcx
          and return ('SYMBOL', $1);

        /\G " ([^"\\]* (?: \\. [^"\\]*)*) "/gcx
          and return ('STRING', $1 || "");

        /\G ([().])/gcx
          and return ($1, $1);

#         /\G ([`',]) /gcx
#           and return ('QUOTE', $quotes{$1});

        return ('', undef);
    }
}

sub error {
    my $self = shift;
    my ($tok, $val) = $self->YYLexer->($self);
    die("Parse error near: '" . $self->unparsed_input . "'");
    return undef;
}

sub parse {
    my $self = shift;
    return $self->YYParse(yylex => \&lexer, yyerror => \&error);
}

1;
