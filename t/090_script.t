use strict;
use warnings;

use Test::More tests => 3;
# Tests for a simple NNexus script, e.g "
# perl -MNNexus 'print linkentry(shift);' < 'text_file.txt' > 'autolinked_file.txt'

use NNexus;
is_deeply(linkentry('mockup',format=>'text'),'mockup','Mockup of a text auto-link command');

is_deeply(linkentry('test banach algebra here.',format=>'text',domain=>'Planetmath'),
	'test <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">banach algebra</a> here.',
	"Banach algebra test.");

# TODO: Do we need any elaborate indexing here?
is_deeply(indexentry(url=>'http://planetmath.org/mockup',domain=>"Planetmath",dom=>"mockup"),
	[],
	'Mockup indexing job.');