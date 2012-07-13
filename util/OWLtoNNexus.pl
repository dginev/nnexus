#!/usr/bin/perl
use strict;

use Boost::Graph;
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

my $i = 0;
my $p = 'root';
my $list = $upg->neighbors($p);
my %prev = ();
while ( 1 ) {
	$i++;
	my @children;
	foreach my $t ( @$list ) {
		my $c = $upg->neighbors($t);
		foreach my $j ( @$c ) {
			if ( not  defined ( $prev{$j} ) ) {
				push @children, $j;
				$prev{$j} = 1;
			}
		}
	}
	@children = uniquify( @children );
	if ( @children < 1 ) {
		last;	
	}
	#%prev = map { $_ => 1 } @$list;
	$list = \@children;
}

my $levels = $i;

print "There are $levels levels\n";


my $topweight = 10**($i-1);

#now assign the appropriate weights to the graphs.
#my $list = $upg->children_of_directed($p);
my $i = 0;
my $p = 'root';
my $list = $upg->neighbors($p);
my @edges = ();
my %prev = ();
my @children = ();
$prev{'root'} = 1;
foreach my $t ( @$list ) {
	my $weight = $topweight;
	my @edge = ( "$t", "$p", "$weight" );
	push @edges, \@edge;
	print "$t $p $weight\n";
	$prev{$t} = 1;
	push @children, $t;
}


$i=1;
while ( 1 ) {
	my @children;
	foreach my $t ( @$list ) {
		my $c = $upg->neighbors($t);
		foreach my $j ( @$c ) {
			if ( not  defined ( $prev{$j} ) ) {
				my $weight = $topweight / (10**$i);
				my @edge = ( "$j", "$t", "$weight" );
				push @edges, \@edge;
				print "$j $t $weight\n";
				push @children, $j;
				$prev{$j} = 1;
			}
		}
	}
	@children = uniquify( @children );
	if ( @children < 1 ) {
		last;	
	}
	$list = \@children;
	$i++;
}

my $dbh = DBI->connect( "DBI:mysql:$databasename;localhost", "nnexus", "nnexus", 
			{RaiseError=>1}) || die "coundn't connect" ;


my $del = $dbh->prepare( "delete from ontology" );
$del->execute();
my $sth = $dbh->prepare( "insert into ontology ( child, parent, weight ) values ( ?, ?, ?)" );

foreach my $e ( @edges ) {
	my ($c, $p, $w) = @$e;
	$sth->execute( $c, $p, $w);
}


sub uniquify {
        my @a = @_;
	my %seen = ();
	my @uniqu = grep { ! $seen{$_} ++ } @a;
        return @uniqu;
}
