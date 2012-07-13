#!/usr/bin/perl
use strict;
use warnings;
use Graph;
use Data::Dumper;
use RDF::Simple::Parser;
use DBI;

my $infile = $ARGV[0];
my $databasename = $ARGV[1];

open ( IN, $infile );

my @data = <IN>;
my $text = join ('', @data);
my $parser = RDF::Simple::Parser->new();
my @triples = $parser->parse_rdf($text);

my $upg = Graph::Undirected->new;
foreach my $t ( @triples ) {
	my $a = $t->[0];
	my $b = $t->[2];
	my $type = $t->[1];
	if ( $type =~ m/subClassOf$/ ) {
		$a =~ s/.*#/msc:/;
		$b =~ s/.*#/msc:/;
                #print "$a<---->$b\n";
		$upg->add_edge( $a, $b );
	}
}

### Rewrite traversal and SQL insertion:

my $vertex_queue = [ ['msc:root',0] ];
my $edge_collection = [];
my $visited = {};
my $max_depth = 0;

while ( @$vertex_queue ) {
  # 0. Grab a current vertex from the queue
  my $current_vertex = shift @$vertex_queue;
  #print "CURRENT VERTEX ".Dumper($current_vertex);
  $max_depth = $current_vertex->[1] if ($current_vertex->[1] > $max_depth);
  # 1. Visit
  next if $visited->{$current_vertex->[0]};
  $visited->{$current_vertex->[0]} = 1;
  # 2. Push new neighbours to queue, increment level
  my @neighbours = $upg->neighbours($current_vertex->[0]);
  #print "NEIGHBBORS ".Dumper($neighbours);
  foreach my $neighbour ( @neighbours ) {
    if ( ! defined ( $visited->{$neighbour} ) ) {
      # 3. Add an edge for every neighbour if not visited,
      # to avoid adding twice (undirected graph)
      my $next_level = $current_vertex->[1]+1;
      push @$edge_collection, [$neighbour, $current_vertex->[0] , 10**($next_level) ];
      # 4. Push the neighbour on the queue
      push_if_new($vertex_queue, [$neighbour,$next_level]);
    }
  }
}

#print "There are $max_depth levels\n";
my $topweight = 10**($max_depth);

my $dbh = DBI->connect( "DBI:mysql:$databasename;localhost", "nnexus", "nnexus", 
			{RaiseError=>1}) || die "coundn't connect" ;


my $del = $dbh->prepare( "delete from ontology" );
$del->execute();
my $sth = $dbh->prepare( "insert into ontology ( child, parent, weight ) values ( ?, ?, ?)" );

foreach my $e ( @$edge_collection ) {
	my ($c, $p, $w) = @$e;
	$sth->execute( $c, $p, $topweight/$w);
        print "storing $c $p ".$topweight/$w."\n";
}

# Pushes element in array if new
# Note: All elements are of the form [$name,$number]
#       where the $name-s are the important comparables
sub push_if_new {
  my ($array,$element) = @_;
  my $result = grep {$element->[0] eq $_->[0]} @$array;
  #print "PUSH IF " . $result;
  #print "PUSH ARRAY " . Dumper($array);
  #print "PUSH ELEMENT " . Dumper($element);
  push @$array, $element unless grep {$element->[0] eq $_->[0]} @$array;
}
