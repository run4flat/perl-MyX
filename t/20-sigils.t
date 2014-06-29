use strict;
use warnings;
use Test::More;

require yX;
chdir 't';

# Test croaking behavior of MyX on sigils
open my $in_fh, '<', '20-sigils.lyx' or die "Unable to open t/20-sigils.t\n";
$_ = join('', <$in_fh>);
close $in_fh;

eval { yX::filter() };

isnt($@, '', 'MyX filter croaks on sigils');

done_testing;
