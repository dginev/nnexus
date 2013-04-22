use strict;
use warnings;

use Test::More tests => 2;
# Tests for a simple NNexus script, e.g "
# perl -MNNexus 'print linkentry(shift);' < 'text_file.txt' > 'autolinked_file.txt'
use NNexus;
is_deeply(linkentry('mockup',format=>'text'),'mockup','Mockup of a text auto-link command');
TODO: {
	local $TODO = "Once we have the snapshots in place:\n
		  We need more meaningful tests, e.g. non-trivial HTML and stand-off";
	ok(1,'TODO');
}