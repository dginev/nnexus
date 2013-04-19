use strict;
use warnings;

use Test::More tests => 3;

use NNexus::Concepts qw(flatten_concept_harvest diff_concept_harvests);
use Data::Dumper;
my $indexed_concepts = [{
                       'synonyms' => [
                                      'integration',
                                      'definite integral'
                                     ],
                       'url' => 't/pages/Integral.html',
                       'categories' => [ '00-XX' , '11-XX'],
                       'concept' => 'integral'
                      }];
# Test flattening of synonyms and categories
my $new_concepts = flatten_concept_harvest($indexed_concepts);
is_deeply($new_concepts, [
          {
            'url' => 't/pages/Integral.html',
            'category' => '00-XX',
            'concept' => 'integration'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'integration'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '00-XX',
            'concept' => 'definite integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'definite integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '00-XX',
            'concept' => 'integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'integral'
          }
        ]);


# Test calculating delete-addition difference between two concept harvests
my $old_concepts=[{concept=>'integration',category=>'00-XX'},
                  {concept=>'deleteme',category=>'11-XX'}];
my ($delete_concepts,$add_concepts) = diff_concept_harvests($old_concepts,$new_concepts);
is_deeply($delete_concepts,[{concept=>'deleteme',category=>'11-XX'}]);
is_deeply($add_concepts,[
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'integration'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '00-XX',
            'concept' => 'definite integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'definite integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '00-XX',
            'concept' => 'integral'
          },
          {
            'url' => 't/pages/Integral.html',
            'category' => '11-XX',
            'concept' => 'integral'
          }
        ]);
# Done
1;
