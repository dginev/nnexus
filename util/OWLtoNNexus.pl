#!/usr/bin/perl
use strict;
use warnings;
use Graph;
use RDF::Simple::Parser;
use DBI;

my $infile = $ARGV[0];
my $databasename = $ARGV[1];

open ( IN, $infile );

my @data = <IN>;
my $text = join ('', @data);
my $parser = RDF::Simple::Parser->new();
my @triples = $parser->parse_rdf($text);

my $upg = new Boost::Graph( directed => 0 );
foreach my $t ( @triples ) {
	my $a = $t->[0];
	my $b = $t->[2];
	my $type = $t->[1];
	if ( $type =~ m/subClassOf$/ ) {
		$a =~ s/#//;
		$b =~ s/#//;
		$upg->add_edge( node1 => $a, node2 => $b );
	}
}

### Rewrite traversal and SQL insertion:

my $vertex_queue = [ ['root',0] ];
my $edge_collection = [];
my $visited = {};
my $max_depth = 0;

while ( @$vertex_queue ) {
  # 0. Grab a current vertex from the queue
  my $current_vertex = shift @$vertex_queue;
  $max_depth = $current_vertex->[1] if ($current_vertex->[1] > $max_depth);
  # 1. Visit
  next if $visited->{$current_vertex->[0]};
  $visited->{$current_vertex->[0]} = 1;
  # 2. Push new neighbors to queue, increment level
  my $neighbors = $upg->neighbors($current_vertex->[0]);
  foreach my $neighbor ( @$neighbors ) {
    if ( ! defined ( $visited->{$neighbor->[0]} ) ) {
      # 3. Add an edge for every neighbour if not visited,
      # to avoid adding twice (undirected graph)
      my $next_level = $current_vertex->[1]+1;
      push @$edge_collection, [$neighbor, $current_vertex->[0] , 10**($next_level) ];
      # 4. Push the neighbour on the queue
      push_if_new($vertex_queue, [$neighbor,$next_level]);
    }
  }
}

print "There are $max_depth levels\n";
my $topweight = 10**($max_depth-1);

my $dbh = DBI->connect( "DBI:mysql:$databasename;localhost", "nnexus", "nnexus", 
			{RaiseError=>1}) || die "coundn't connect" ;


my $del = $dbh->prepare( "delete from ontology" );
$del->execute();
my $sth = $dbh->prepare( "insert into ontology ( child, parent, weight ) values ( ?, ?, ?)" );

foreach my $e ( @$edge_collection ) {
	my ($c, $p, $w) = @$e;
	$sth->execute( $c, $p, $topweight/$w);
}

# Pushes element in array if new
# Note: All elements are of the form [$name,$number]
#       where the $name-s are the important comparables
sub push_if_new {
  my ($array,$element) = @_;
  push @$array, $element unless grep {$element->[0] eq $_->[0]} @$array;
}
