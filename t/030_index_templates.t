use strict;
use warnings;

use Test::More tests => 4;

use NNexus::Index::Dlmf;
use NNexus::Index::Wikipedia;
use NNexus::Index::Planetmath;
use NNexus::Index::Mathworld;
use Mojo::DOM;

sub local_dom {
	my ($path) = @_;
	open my $localfh, "<", $path;
	my $contents = join('',<$localfh>);
	close $localfh;
	Mojo::DOM->new($contents);
}

# Testing all provided Index::Template classes
my ($url, $dom,$concepts);

# 1. Test the Wikipedia indexing
$url = 't/pages/Integral.html';
$dom = local_dom($url);
$concepts = NNexus::Index::Wikipedia->new->index_step(
  start=>$url,
  dom=>$dom);
is_deeply($concepts, [{
                       'synonyms' => [
                                      'integration',
                                      'definite integral'
                                     ],
                       'url' => 't/pages/Integral.html',
                       'categories' => [ 'msc:00-XX' ],
                       'concept' => 'integral'
                      }],
          'Wikipedia Index Template - operational');


# 2. Test the PlanetMath indexing
$url = 't/pages/HeytingAlgebra.html';
$dom = local_dom($url);
$concepts = NNexus::Index::Planetmath->new->index_step(
  start=>$url,
  dom=>$dom);
is_deeply($concepts,[{
                      'url' => 't/pages/HeytingAlgebra.html',
                      'categories' => [
                                       'msc:06D20',
                                       'msc:03G10'
                                      ],
                      'concept' => 'Heyting algebra'
                     }
                    ],
          'Planetmath Index Template - operational');

# 3. Test the MathWorld indexing
$url = 't/pages/QuadraticInvariant.html';
$dom = local_dom($url);
$concepts = NNexus::Index::Mathworld->new->index_step(
  start=>$url,
  dom=>$dom);
is_deeply($concepts,[{
                      'url' => 't/pages/QuadraticInvariant.html',
                      'categories' => [
                                       'msc:15A72'
                                      ],
                      'concept' => 'Quadratic Invariant'
                     }
                    ],
          'MathWorld Index Template - operational');

# 4. Test the DLMF indexing
$url = 't/pages/idx_Z.html';
my $original_url = 'http://dlmf.nist.gov/idx/Z';
$dom = local_dom($url);
$concepts = NNexus::Index::Dlmf->new->index_step(
  start=>$original_url,
  dom=>$dom);
is_deeply($concepts,[{
                      'url' => 'http://dlmf.nist.gov/35.4',
                      'categories' => [
                                       'msc:33-XX'
                                      ],
                      'concept' => 'zonal polynomials'
                     }
                    ],
         'DLMF Index Template - operational');
1;
