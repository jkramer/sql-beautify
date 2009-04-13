
package SQL::Beautify;

use strict;
use warnings;

our $VERSION = 0.03;

use SQL::Tokenizer;
use Carp;


sub new {
	my ($class, %options) = @_;

	my $self = bless { %options }, $class;

	# Set some defaults.
	$self->{query}  = ''   unless defined($self->{query});
	$self->{spaces} = 4    unless defined($self->{spaces});
	$self->{space}  = ' '  unless defined($self->{space});
	$self->{break}  = "\n" unless defined($self->{break});
	$self->{wrap}   = {}   unless defined($self->{wrap});

	# Initialize internal stuff.
	$self->{_level} = 0;

	return $self;
}


sub add {
	my ($self, $addendum) = @_;

	$addendum =~ s/^\s*/ /;

	$self->{query} .= $addendum;
}


sub query {
	my ($self, $query) = @_;

	$self->{query} = $query if(defined($query));

	return $self->{query};
}


sub beautify {
	my ($self) = @_;

	$self->{_output} = '';
	$self->{_level_stack} = [];
	$self->{_new_line} = 1;

	my $last;

	$self->{_tokens} = [ SQL::Tokenizer->tokenize($self->query, 1) ];

	while(defined(my $token = $self->_token)) {
		if($token eq '(') {
			$self->_add_token($token);
			$self->_new_line;
			push @{$self->{_level_stack}}, $self->{_level};
			$self->_over unless $last and uc($last) eq 'WHERE';
		}

		elsif($token eq ')') {
			$self->_new_line;
			$self->{_level} = pop(@{$self->{_level_stack}}) || 0;
			$self->_add_token($token);
			$self->_new_line;
		}

		elsif($token eq ',') {
			$self->_add_token($token);
			$self->_new_line;
		}

		elsif($token eq ';') {
			$self->_add_token($token);
			$self->_new_line;

			# End of statement; remove all indentation.
			@{$self->{_level_stack}} = ();
			$self->{_level} = 0;
		}

		elsif($token =~ /^(?:SELECT|FROM|WHERE|HAVING)$/i) {
			$self->_back unless $last and $last eq '(';
			$self->_new_line;
			$self->_add_token($token);
			$self->_new_line if($self->_next_token and $self->_next_token ne '(');
			$self->_over;
		}

		elsif($token =~ /^(?:GROUP|ORDER|LIMIT)$/i) {
			$self->_back;
			$self->_new_line;
			$self->_add_token($token);
		}

		elsif($token =~ /^(?:BY)$/i) {
			$self->_add_token($token);
			$self->_new_line;
			$self->_over;
		}

		elsif($token =~ /^(?:UNION|INTERSECT|EXCEPT)$/i) {
			$self->_new_line;
			$self->_add_token($token);
			$self->_new_line;
		}

		elsif($token =~ /^(?:LEFT|RIGHT|INNER|OUTER|CROSS)$/i) {
			$self->_back;
			$self->_new_line;
			$self->_add_token($token);
			$self->_over;
		}

		elsif($token =~ /^(?:JOIN)$/i) {
			if($last and $last !~ /^(?:LEFT|RIGHT|INNER|OUTER|CROSS)$/) {
				$self->_new_line;
			}

			$self->_add_token($token);
		}

		elsif($token =~ /^(?:AND|OR)$/i) {
			$self->_new_line;
			$self->_add_token($token);
			$self->_new_line;
		}

		else {
			$self->_add_token($token, $last);
		}

		$last = $token;
	}

	$self->_new_line;

	$self->{_output};
}


# Add a token to the beautified string.
sub _add_token {
	my ($self, $token, $last_token) = @_;

	if($self->{wrap}) {
		my $wrap;

		if($self->_is_keyword($token)) {
			$wrap = $self->{wrap}->{keywords};
		}
		elsif($self->_is_constant($token)) {
			$wrap = $self->{wrap}->{constants};
		}

		if($wrap) {
			$token = $wrap->[0] . $token . $wrap->[1];
		}
	}

	my $last_is_dot =
		defined($last_token) && $last_token eq '.';

	if(!$self->_is_punctuation($token) and !$last_is_dot) {
		$self->{_output} .= $self->_indent;
	}

	$self->{_output} .= $token;

	# This can't be the beginning of a new line anymore.
	$self->{_new_line} = 0;
}


# Increase the indentation level.
sub _over {
	my ($self) = @_;

	++$self->{_level};
}


# Decrease the indentation level.
sub _back {
	my ($self) = @_;

	--$self->{_level} if($self->{_level} > 0);
}


# Return a string of spaces according to the current indentation level and the
# spaces setting for indenting.
sub _indent {
	my ($self) = @_;

	if($self->{_new_line}) {
		return $self->{space} x ($self->{spaces} * $self->{_level});
	}
	else {
		return $self->{space};
	}
}


# Add a line break, but make sure there are no empty lines.
sub _new_line {
	my ($self) = @_;

	$self->{_output} .= $self->{break} unless($self->{_new_line});
	$self->{_new_line} = 1;
}


# Have a look at the token that's coming up next.
sub _next_token {
	my ($self) = @_;

	return @{$self->{_tokens}} ? $self->{_tokens}->[0] : undef;
}


# Get the next token, removing it from the list of remaining tokens.
sub _token {
	my ($self) = @_;

	return shift @{$self->{_tokens}};
}


# Check if a token is a known SQL keyword.
sub _is_keyword {
	my ($self, $token) = @_;

	my @KEYWORD = qw(
		SELECT WHERE FROM HAVING GROUP BY UNION INTERSECT EXCEPT LEFT RIGHT
		INNER OUTER CROXX JOIN AND OR VARCHAR INTEGER BIGINT TEXT IS NULL NOT
		BETWEEN EXTRACT EPOCH INTERVAL IF LIMIT AS
	);

	return ~~ grep { $_ eq uc($token) } @KEYWORD;
}


# Check if a token is a constant.
sub _is_constant {
	my ($self, $token) = @_;

	return ($token =~ /^\d+$/ or $token =~ /^(['"`]).*\1$/);
}


sub _is_punctuation {
	my ($self, $token) = @_;

	return ($token =~ /^[,;.]$/);
}


1

__END__

=head1 NAME

SQL::Beautify

=head1 SYNOPSIS

	my $sql = new SQL::Beautify;

	$sql->query($sql_query);

	my $nice_sql = $sql->beautify;

=head1 DESCRIPTION

Beautifies SQL statements by adding line breaks indentation.

=head1 METHODS

=over 4

=item B<new>(query => '', spaces => 4, space => ' ', break => "\n", wrap => {})

Constructor. Takes a few options.

=over 4

=item B<query> => ''

Initialize the instance with a SQL string. Defaults to an empty string.

=item B<spaces> => 4

Number of spaces that make one indentation level. Defaults to 4.

=item B<space> => ' '

A string that is used as space. Default is an ASCII space character.

=item B<break> => "\n"

String that is used for linebreaks. Default is "\n".

=item B<wrap> => {}

Use this if you want to surround certain tokens with markup stuff. Known token
types are "keywords" and "constants" for now. The value of each token type
should be an array with two elements, one that is placed before the token and
one that is placed behind it. For example, use make keywords red using terminal
color escape sequences.

	{ keywords => [ "\x1B[0;31m", "\x1B[0m" ] }

=back

=item B<add>($more_sql)

Appends another chunk of SQL.

=item B<query>($query)

Sets the query to the new query string. Overwrites anything that was added with
prior calls to B<query> or B<add>.

=item B<beautify>

Beautifies the internally saved SQL string and returns the result.

=back

=head1 BUGS

Needs more tests.

Please report bugs in the CPAN bug tracker.

This module is not complete (known SQL keywords, special formatting of
keywords), so if you want see something added, just send me a patch.

=head1 COPYRIGHT

Copyright (C) 2009 by Jonas Kramer.  Published under the terms of the Artistic
License 2.0.

=cut
