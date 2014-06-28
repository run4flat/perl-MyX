use strict;
use warnings;
use Test::More;
require yX;

# Tests MyX on a LyX document with no text.
chdir 't';
open my $in_fh, '<', '00-empty.lyx' or die "Unable to open test file\n";
$_ = join('', <$in_fh>);
close $in_fh;

yX::filter();
eval $_;

is($@, '', 'LyX file with no content gives no trouble or output');

done_testing;
