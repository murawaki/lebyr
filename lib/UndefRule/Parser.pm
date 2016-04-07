####################################################################
#
#    This file was generated using Parse::Yapp version 1.05.
#
#        Don't edit this file, use source file instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
####################################################################
package UndefRule::Parser;
use vars qw ( @ISA );
use strict;

@ISA= qw ( Parse::Yapp::Driver );
use Parse::Yapp::Driver;

#line 9 "Parser.yp"



sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    my($self)=$class->SUPER::new( yyversion => '1.05',
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			"(" => 1
		},
		DEFAULT => -1,
		GOTOS => {
			'rule' => 2
		}
	},
	{#State 1
		ACTIONS => {
			"(" => 4
		},
		GOTOS => {
			'match_rule' => 3
		}
	},
	{#State 2
		ACTIONS => {
			'' => 5
		}
	},
	{#State 3
		ACTIONS => {
			'SYMBOL' => 6
		}
	},
	{#State 4
		ACTIONS => {
			"|" => 8,
			"^" => 7,
			"*" => 10,
			"[" => 11
		},
		GOTOS => {
			'mrph_expression' => 9,
			'sub_rule' => 12
		}
	},
	{#State 5
		DEFAULT => 0
	},
	{#State 6
		ACTIONS => {
			")" => 13
		}
	},
	{#State 7
		ACTIONS => {
			"[" => 11
		},
		GOTOS => {
			'mrph_expression' => 14
		}
	},
	{#State 8
		DEFAULT => -5
	},
	{#State 9
		DEFAULT => -7
	},
	{#State 10
		DEFAULT => -4
	},
	{#State 11
		ACTIONS => {
			"(" => 18,
			"^" => 17
		},
		GOTOS => {
			'mrph_rule_list' => 16,
			'mrph_rule' => 15
		}
	},
	{#State 12
		ACTIONS => {
			"|" => 8,
			"^" => 7,
			"*" => 10,
			"[" => 11
		},
		GOTOS => {
			'mrph_expression' => 9,
			'sub_rule' => 19
		}
	},
	{#State 13
		DEFAULT => -2
	},
	{#State 14
		DEFAULT => -6
	},
	{#State 15
		DEFAULT => -9
	},
	{#State 16
		ACTIONS => {
			"(" => 18,
			"^" => 17,
			"]" => 21
		},
		GOTOS => {
			'mrph_rule' => 20
		}
	},
	{#State 17
		ACTIONS => {
			"(" => 22
		}
	},
	{#State 18
		ACTIONS => {
			'SYMBOL' => 23
		}
	},
	{#State 19
		ACTIONS => {
			"|" => 8,
			"^" => 7,
			"*" => 10,
			"[" => 11
		},
		GOTOS => {
			'mrph_expression' => 9,
			'sub_rule' => 24
		}
	},
	{#State 20
		DEFAULT => -10
	},
	{#State 21
		DEFAULT => -8
	},
	{#State 22
		ACTIONS => {
			'SYMBOL' => 25
		}
	},
	{#State 23
		ACTIONS => {
			'SYMBOL' => 26,
			")" => 29,
			'NUMBER' => 28
		},
		GOTOS => {
			'expression' => 27
		}
	},
	{#State 24
		ACTIONS => {
			")" => 30
		}
	},
	{#State 25
		ACTIONS => {
			'SYMBOL' => 26,
			")" => 32,
			'NUMBER' => 28
		},
		GOTOS => {
			'expression' => 31
		}
	},
	{#State 26
		DEFAULT => -15
	},
	{#State 27
		ACTIONS => {
			")" => 33
		}
	},
	{#State 28
		DEFAULT => -16
	},
	{#State 29
		DEFAULT => -11
	},
	{#State 30
		DEFAULT => -3
	},
	{#State 31
		ACTIONS => {
			")" => 34
		}
	},
	{#State 32
		DEFAULT => -12
	},
	{#State 33
		DEFAULT => -13
	},
	{#State 34
		DEFAULT => -14
	}
],
                                  yyrules  =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'rule', 0, undef
	],
	[#Rule 2
		 'rule', 4,
sub
#line 15 "Parser.yp"
{ $_[0]->YYAccept; return [$_[2], $_[3]]; }
	],
	[#Rule 3
		 'match_rule', 5,
sub
#line 18 "Parser.yp"
{ return [$_[2], $_[3], $_[4]]; }
	],
	[#Rule 4
		 'sub_rule', 1,
sub
#line 21 "Parser.yp"
{ return 'ANY'; }
	],
	[#Rule 5
		 'sub_rule', 1,
sub
#line 22 "Parser.yp"
{ return 'NONEXIST'; }
	],
	[#Rule 6
		 'sub_rule', 2,
sub
#line 23 "Parser.yp"
{ unshift (@{$_[2]}, 0); return $_[2]; }
	],
	[#Rule 7
		 'sub_rule', 1,
sub
#line 24 "Parser.yp"
{ unshift (@{$_[1]}, 1); return $_[1]; }
	],
	[#Rule 8
		 'mrph_expression', 3,
sub
#line 27 "Parser.yp"
{ return $_[2]; }
	],
	[#Rule 9
		 'mrph_rule_list', 1,
sub
#line 30 "Parser.yp"
{ return [$_[1]]; }
	],
	[#Rule 10
		 'mrph_rule_list', 2,
sub
#line 31 "Parser.yp"
{ push (@{$_[1]}, $_[2]); return $_[1]; }
	],
	[#Rule 11
		 'mrph_rule', 3,
sub
#line 34 "Parser.yp"
{ return [1, [$_[2]]]; }
	],
	[#Rule 12
		 'mrph_rule', 4,
sub
#line 35 "Parser.yp"
{ return [0, [$_[3]]]; }
	],
	[#Rule 13
		 'mrph_rule', 4,
sub
#line 36 "Parser.yp"
{ return [1, [$_[2], $_[3]]]; }
	],
	[#Rule 14
		 'mrph_rule', 5,
sub
#line 37 "Parser.yp"
{ return [0, [$_[3], $_[4]]]; }
	],
	[#Rule 15
		 'expression', 1, undef
	],
	[#Rule 16
		 'expression', 1, undef
	]
],
                                  @_);
    bless($self,$class);
}

#line 44 "Parser.yp"


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

sub lexer {
    my ($self) = shift;
    $self->YYData->{INPUT} or return ('', undef);

    for($self->YYData->{INPUT}) {
	$_ =~ /\G \s* (?: \# .* \s* )* /gcx;   # ignore comment1
	$_ =~ /\G \s* (?: \; .* \s* )* /gcx;   # ignore comment2

	# \d では全角数字も認識されてしまうので駄目
	/\G ([+-]? [0-9]+ (?:[.][0-9]*)?) /gcx
	    || /\G ([+-]? [.] [0-9]+) /gcx
	    and return ('NUMBER', $1);

	my $str = $_;
	my $symbol = '';
	my $sym_re = qr{[A-Za-z_\-\:]};
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

	/\G ([()\[\]\*\|\^])/gcx
	    and return ($1, $1);

	return ('', undef);
    }
}

# sub lexer {
#     my $self = shift;

#     $self->YYData->{INPUT} or return ('', undef);

# #     my $symbol_char = qr{[*!\$[:alpha:]\p{Hiragana}\p{Katakana}\p{Han}\?<>=/+:_{}-]};
# #    my $symbol_char = qr{[*!\$\p{InNonNumControl}\p{InCJKSymbolsAndPunctuation}\?<>=/+:_{}-]};
# #    my $symbol_char = qr{([*!\$[:alpha:]\?<>=/+:_{}-]|\p{InCJKSymbolsAndPunctuation}|\p{InHalfwidthAndFullwidthForms}|\p{InLatin1Supplement}|\p{InLetterlikeSymbols}|\p{InHiragana}|\p{InKatakana})};

#     for($self->YYData->{INPUT}) {
#         $_ =~ /\G \s* (?: ; .* \s* )* /gcx;   # ignore comment

# # \d では全角数字も認識されてしまうので駄目
# #         /\G ([+-]? \d+ (?:[.]\d*)?) /gcx
# #         || /\G ([+-]? [.] \d+) /gcx
# #           and return ('NUMBER', $1);

#         /\G ([+-]? [0-9]+ (?:[.][0-9]*)?) /gcx
#         || /\G ([+-]? [.] [0-9]+) /gcx
#           and return ('NUMBER', $1);

# #	my ($vv, $pos) = $self->get_symbol ($_);
# #	pos = $pos;
# #	return ('SYMBOL', $vv) if (defined ($vv));

# 	my $str = $_;
# 	my $symbol = '';
# 	my $sym_re = qr{[*!\$\?<>=/+:_{}-]};
# 	my $pos = pos;
# 	my $i = $pos;
# 	while (1) {
# 	    my $c = substr ($str, $i, 1);
# 	    my $o = ord ($c);

# 	    if ($c =~ /$sym_re/ || $o >= 0x0080) {
# 		$symbol .= $c;
# 	    } elsif ($i > $pos && $c =~ /\d|\./) {
# 		$symbol .= $c;
# 	    } else {
# 		last;
# 	    }
# 	    last unless (++$i < length ($str));
# 	}
# 	if (length ($symbol)) {
# 	    pos = $i;
# 	    return ('SYMBOL', $symbol);
# 	}
# 	pos = $pos;

# # 	my $pos = pos;
# #         /\G ($symbol_char ($symbol_char | \d | [.] )*)/gcx
# #           and return ('SYMBOL', $1);
# # 	pos = $pos unless (defined ($pos));

#         /\G (\| [^|]* \|) /gcx
#           and return ('SYMBOL', $1);

#         /\G " ([^"\\]* (?: \\. [^"\\]*)*) "/gcx
#           and return ('STRING', $1 || "");

#         /\G ([().])/gcx
#           and return ($1, $1);

#         /\G ([`',]) /gcx
#           and return ('QUOTE', $quotes{$1});

#         return ('', undef);
#     }
# }


sub error {
    my ($self) = @_;
    my ($tok, $val) = $self->YYLexer->($self);
    die("Parse error near: '" . $self->unparsed_input . "'");
    return undef;
}

sub parse {
    my ($self) = @_;
    return $self->YYParse (yylex => \&lexer, yyerror => \&error);
}

1;
