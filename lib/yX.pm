use strict;
use warnings;

############################################################################
                              package yX;
############################################################################

# We need to keep track of a number of pieces of information. For now, I
# track all of these in a collection of global variables. This'll be a
# problem when one MyX document attempts to use another MyX document,
# but as that's not yet supported, I am not too worried about it.

my (@headings, @parse_stack, @wants_code_stack, $code, $indent,
	$line_number, $listing_count, $just_wanted_code, $prev_font_type);

# This constructs a line directive that Perl knows how to parse so it
# gives useful location reporting of problems.
sub current_line_description {
	my $description = "line $line_number \"";
	if (@headings) {
		$description .= "Section " . join('.', @headings)
	}
	else {
		$description .= "Preface";
	}
	$description .= " listing $listing_count\"\n";
	return $description;
}
sub current_line_directive {
	return '# ' . current_line_description;
}

# Keeps track of indentation for me
sub parse_indentation {
	my ($line) = @_;
	$indent .= "\t" if $line =~ /begin_deeper/;
	chop $indent if $line =~ /end_deeper/;
}

# Tracks the current section and subsection number
sub parse_section {
	my ($line) = @_;
	if ($line =~ /begin_layout S((ubs)*)ection/) {
		my $depth = length($1) / 3;
		$#headings = $depth;
		$headings[$depth]++;
		$listing_count = 0;
	}
}

sub parse_code {
	my ($line) = @_;
	if ($line =~ /begin_layout LyX-Code/) {
		$code .= $indent;
		$prev_font_type = 'typewriter';
	}
	elsif ($line =~ /end_layout/) {
		$code .= "\n";
		$line_number++;
	}
	elsif ($line =~ /^\\family (.*)/) {
		# Handle font changes gracefully
		my $font_type = $1;
		$font_type =~ s/\s+/_/;
		$font_type = 'typewriter' if $font_type eq 'default';
		if ($font_type ne $prev_font_type) {
			$code .= "_${font_type}_";
			$prev_font_type = $font_type;
		}
	}
	else {
		# Special case the backslash stuff:
		$line =~ s{\\backslash}{\\}g;
		
		$code .= $line;
	}
}

sub parse_newline {
	my ($line) = @_;
	
	# Add a newline when we see the start of the inset
	$code .= "\n" if $line =~ /\\begin_inset Newline/;
}

sub parse_quotes {
	my ($line) = @_;
	
	# Add double quotes when we encounter the start of the inset
	$code .= '"' if $line =~ /\\begin_inset Quotes e[rl]d/;
}

sub parse_formula {
	# Get the inset formula and turn into a valid code snippet.
	my ($line) = @_;
	return unless $line =~ /\\begin_inset Formula \$(.*?[^\\])\$/;
	$line = $1;
	
	# Croak on sigils in formulae
	die('Sigils are not allowed in formulae inset into code on '
		. current_line_description() . "\n") if $line =~ tr/$@%//;
	# Replace funny characters with escape sequences
	$line =~ s/_/_sub_/g;
	$line =~ s/\^/_sup_/g;
	$line =~ s/\\/_backslash_/g;
	$line =~ s/\{/_lcurly_/g;
	$line =~ s/\}/_rcurly_/g;
	$line =~ s/\(/_lparen_/g;
	$line =~ s/\)/_rparen_/g;
	$line =~ s/\[/_lbracket_/g;
	$line =~ s/\]/_rbracket_/g;
	$line =~ s/,/_comma_/g;
	$line =~ s/\s+//g;
	
	# Add the resulting code
	$code .= $line;
}

# Given a \begin_... line, returns the appropriate parser function,
# which gets pushed onto the parser stack.
sub parser_for {
	my ($line) = @_;
	
	# First and foremost, set up code parsing
	if ($line =~ /begin_layout LyX-Code/) {
		# Unless we just came from a LyX Code layout, set up the
		# variables for a new listing.
		if (not $just_wanted_code) {
			$listing_count++;
			$line_number = 1;
			$code .= current_line_directive;
		}
		$wants_code_stack[-1] = 1;
		return \&parse_code;
	}
	
	# Section and indentation handling always setup special parsers, too
	return \&parse_section if $line =~ /begin_layout S((ubs)*)ection/;
	return \&parse_indentation if $line =~ /begin_deeper/;
	
	# If we're not parsing code, then set up a null parser
	return \&parse_ignore unless $wants_code_stack[-1];
	
	# If we're generating code, then set up specialty parsers for known
	# insets
	return \&parse_formula if $line =~ /begin_inset Formula/;
	return \&parse_quotes if $line =~ /begin_inset Quotes/;
	return \&parse_newline if $line =~ /begin_inset Newline/;
	
	# And set up the ignore parser for everything else, overriding the
	# code wanted stack setting.
	$wants_code_stack[-1] = 0;
	return \&parse_ignore;
}

sub parse_ignore { }

sub parse_lines {
	# Get the collection of lines
	my @lines = @_;
	
	# Set up the globals we will use
	@headings = ();
	$indent = $code = '';
	$line_number = 1;
	$listing_count = 0;
	$just_wanted_code = 0;
	$prev_font_type = 'typewriter';
	
	# Initialize the parse state and code wanted stacks
	@parse_stack = (\&parse_ignore);
	@wants_code_stack = (0);
	
	# Go!
	LINE: while(@lines) {
		my $line = shift @lines;
		if ($line =~ /\\begin_/) {
			push @wants_code_stack, $wants_code_stack[-1];
			push @parse_stack, parser_for($line);
		}
		# Use the new or current parser to handle this line
		$parse_stack[-1]->($line);
		# Pop the top parser if we reached the matching end tag
		if ($line =~ /\\end_/ and @parse_stack > 1) {
			pop @parse_stack;
			
			# The "just wanted code" is the previous value on the
			# stack, except for the special case of indentation reduction
			my $prev_wants_code = pop @wants_code_stack;
			$just_wanted_code = $prev_wants_code
				unless $line =~ /\\end_deeper/;
		}
	}
	
	# All done
	return $code;
}

sub filter {
	$_ = parse_lines(split /\n/);
#	print "-----\n$_\n-----\n";
}

use Filter::Simple \&filter;

1;

__END__

=head1 NAME

MyX - mixing LyX and Perl

=head1 USAGE

 # Run the Perl code in a LyX document
 perl -MyX document.lyx

=head1 DESCRIPTION

C<MyX> lets you sprinkle Perl code into your C<LyX> document and then run the
code in that document without changing anything. That's right! Using C<MyX>,
you run C<LyX> documents through the Perl parser! By itself, of course, that
would be complete nonsense. What it actually does is it uses
a source filter to extract every C<LyX-Code> line of our C<LyX> file and
returns that to the Perl interpreter.

Although this module is refered to as C<MyX>, it is actually named C<yX>.
This is because Perl command-line module inclusion uses the C<-M> switch,
i.e. C<-MSome::Module>. Including the module C<yX> from the command line
means using the switch C<-MyX>. Clever, eh?

=head1 AUTHOR

David Mertens C<dcmertens.perl@gmail.com>

=cut

