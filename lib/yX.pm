use strict;
use warnings;

############################################################################
                              package yX;
############################################################################

sub filter {
	# Extract code listings
	my $listing_number = 1;
	my $code = '';
	my $indent = '';
	my @chunks = split /(\\begin_deeper|\\end_deeper)/;
	CHUNK: for my $chunk (@chunks) {
		# Process indentation changes
		if ($chunk eq '\\begin_deeper') {
			$indent .= "\t";
			next CHUNK;
		}
		if ($chunk eq '\\end_deeper') {
			chop $indent;
			next CHUNK;
		}
		# Extract code
		while($chunk =~ /\G.*?begin_layout LyX-Code\n(.*?)\n\\end_layout\n\n/sg) {
			my $snippet = $1;
			
			# Remove the backslash escapes
			$snippet =~ s/\n\\backslash\n/\\/g;
			# Replace double quotes
			$snippet =~ s/\n\\begin_inset Quotes e[rl]d\n\\end_inset\n\n/"/g;
			# Extract inline equation elements
			while ($snippet =~ /\\begin_inset Formula \$(.*?)\$/) {
				# Pull out the contents of the equation
				my $eqn = $1;
				# Replace funny characters with escape sequences
				$eqn =~ s/_/_sub_/g;
				$eqn =~ s/\^/_sup_/g;
				$eqn =~ s/\\/_backslash_/g;
				$eqn =~ s/\{/_lcurly_/g;
				$eqn =~ s/\}/_rcurly_/g;
				$eqn =~ s/\(/_lparen_/g;
				$eqn =~ s/\)/_rparen_/g;
				$eqn =~ s/\[/_lbracket_/g;
				$eqn =~ s/\]/_rbracket_/g;
				# Substitute this for the formula
				$snippet =~ s/\n\\begin_inset Formula \$.*?\$\n\\end_inset\n\n/$eqn/;
			}
			
			# Fix any extra line wrapping
			$snippet =~ s/\n//g;
			# Handle forced newlines
			$snippet =~ s/\\begin_inset Newline newline\\end_inset/\n/g;
			
#			$code .= "# line 1 \"Listing $listing_number\"\n$indent$snippet\n";
			$code .= "$indent$snippet\n";
			$listing_number++;
		}
	}
	$_ = $code;
	print "-------- $0 --------\n$code\n-------- --------\n"
		if $ENV{MYX_PRINT_CODE};
}

use Filter::Simple \&filter;

1;

__END__

=head1 NAME

MyX - mixing LyX and Perl

=head1 USAGE

 # Run the Perl code in a LyX document
 perl -MyX document.lyx
 
 # As above, but print the extracted code first
 MYX_PRINT_CODE=1 perl -MyX document.lyx

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

