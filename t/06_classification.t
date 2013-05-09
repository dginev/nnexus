use strict;
use warnings;

use Test::More tests => 7;

my $eval_return = eval {
  use NNexus::Classification qw(msc_similarity disambiguate);
  1;
};

# Base load
ok($eval_return && !$@, 'NNexus::Classification Loaded successfully.');

# MSC Similarity:
is(msc_similarity(),0,'MSC Similarity: undefined arguments return 0');
is(msc_similarity(undef,'00-XX'),0,'MSC Similarity: partial arguments return 0');
is(msc_similarity('00-XX',undef),0,'MSC Similarity: partial arguments return 0');
is(msc_similarity('00-XX','00-XX'),1,'MSC Similarity: same class is 1');
is(msc_similarity('00-XX','XX-XX'),0,'MSC Similarity: XX-XX is 0 with all');

# Disambiguation:
# TODO: Better clusters
my $candidates = [
	{ concept=>"fake scheme",
		scheme=>"fake",
		category=>"random",
	},
	{ concept=>"missing category",
		scheme=>"msc",
		category=>"XX-XX",
	},
	{ concept=>"A",
		scheme=>"msc",
		category=>"00-XX",
		link=>'http://planetmath.org/A'
	},
	{ concept=>"B",
		scheme=>"msc",
		category=>"00-XX",
		link=>'http://planetmath.org/B'
	},
	{ concept=>"group",
		scheme=>"msc",
		category=>"00-XX",
		link=>'http://planetmath.org/group'
	},
	{ concept=>"banach algebra",
		scheme=>'msc',
		category=>"46H05",
		link=>'http://planetmath.org/banachalgebra'
	},
	{ concept=>"banach algebra",
		scheme=>'msc',
		category=>"46H07",
		link=>'http://planetmath.org/banachalgebra'
	},
	{ concept=>"banach algebra",
		category=>"Banach_algebras",
		scheme=>"wiki"
	},
];

my $cluster = disambiguate($candidates,verbosity=>0);
is_deeply($cluster,[
	{ concept=>"banach algebra",
		scheme=>'msc',
		category=>"46H05",
		link=>'http://planetmath.org/banachalgebra'
	}],'Disambiguation succeeded.');