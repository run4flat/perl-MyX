use strict;
use warnings;
use Test::More;

require yX;
chdir 't';

# Tests MyX on various LyX documents
for my $file (glob '1*.lyx') {
	open my $in_fh, '<', $file or die "Unable to open $file\n";
	$_ = join('', <$in_fh>);
	close $in_fh;
	
	my ($func_name) = /Test Function: (.*)/;

	yX::filter();
	eval $_;

	is($@, '', "MyX parsed $file without croaking");
	eval $func_name;
}

done_testing;
