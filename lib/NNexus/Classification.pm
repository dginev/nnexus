package NNexus::Classification;
use strict;
use warnings;

use Graph;
use NNexus::Util;

sub new {
  my ($class,%opts) = @_;
  #this is the global graph for determining classification distance
  my $classgraph = Graph::Undirected->new();

  bless {classgraph=>$classgraph,db=>$opts{db},config=>$opts{config}}, $class;
}

#this function assumes that the classification information has already been added
# to the database. There are utility scripts to do this. In the future we may add
# API calls to intialize the classification trees.
sub initClassificationModule {
  my ($self)=@_;
  my $classgraph = $self->{classgraph};

  print "Initializing Classification Distance Module\n";
  my $sth = $self->{db}->cachedPrepare("SELECT child, parent, weight from ontology");
  $sth->execute();

  while ( my $row = $sth->fetchrow_hashref() ) {
    #	print "adding edge $row->{'child'} $row->{'parent'}\n";
    $classgraph->add_weighted_edge( $row->{'child'},
				    $row->{'parent'},
				    $row->{'weight'} );
  }
  print "Done\n";
}

#this function converts a string of the form scheme:id into
# a hash of the form { scheme =>value, externalid => id}
sub convertStringToClassHash {
  my ($self,$config,$string,$domain)=@_;
  my ($scheme,$externalid);

  if ( $string =~ /:/ ) {
    my @vals = split(/\s*:\s*/, $string);
    $scheme = $vals[0];
    $externalid = join( ":", @vals[1..$#vals] );
    if ( !$self->supportedscheme( $scheme ) ) {
      $scheme = $config->{'domains'}->{'domain'}->{$domain}->{'defaultscheme'};
      $string =~ s/^\s+//g;
      $string =~ s/\s+$//g;
      $externalid = $string;
    }
  } else {
    $scheme = $config->{'domains'}->{'domain'}->{$domain}->{'defaultscheme'};
    $string =~ s/^\s+//g;
    $string =~ s/\s+$//g;
    $externalid = $string;
  }
  my $temp = {};
  $temp->{'scheme'} = $scheme;
  $temp->{'externalid'} = $externalid;
  return $temp;
}

sub class_distance {
  my ($self, $class1, $class2 )=@_;
  my $classgraph = $self->{classgraph};
  #print "comparing $class1 to $class2\n";

  my $distance = 100000;
  #TODO: See if this still works
  if ( ($class1 =~ m/^msc:/) && ($class2 =~ m/^msc:/) ) {
    $class1 =~ s/msc://;
    $class2 =~ s/msc://;
    if ( length( $class1 ) == 2 ) {
      $class1 .= "-XX";
    } elsif ( length($class1) == 3 ) {
      $class1 .= "XX";	
    } elsif ( length( $class1 ) == 4 ) {
      $class1 .= "X";	
    }
    if ( length( $class2 ) == 2 ) {
      $class2 .= "-XX";
    } elsif ( length($class2) == 3 ) {
      $class2 .= "XX";	
    } elsif ( length( $class2 ) == 4 ) {
      $class2 .= "X";	
    }
    my @path = $classgraph->SP_Dijkstra( $class1, $class2 );
    $distance = scalar(@path) if @path;

    #print "$class1 to $class2 distance is $distance\n"
  } else {
    $class1 =~ /(.*):/;
    my $ns1 = $1;
    $class2 =~ /(.*):/;
    my $ns2 = $1;
    print "$ns1 vs. $ns2 class distance not yet supported\n"
  }
  return $distance;
}


#
# return the classes of an object in array form.
# scheme:externalid
#
sub getclasses{
  my ($self,$objid) = @_;
  my $sth = $self->{db}->cachedPrepare("SELECT scheme, class from classification where classification.objectid = ?");

  my @classes = ();

  $sth->execute($objid);

  while (my $row = $sth->fetchrow_hashref()) {
    my $class = $row->{'scheme'} . ":" . $row->{'class'}; 
    push @classes, $class;
  }

  $sth->finish();

  return @classes;
}

# get classification info in string *and* hasharray form
#
sub classinfo {
  my ($self,$id) = @_;

  # first get the classification..
  #
  my $sth = $self->{db}->cachedPrepare("select scheme, class from classification where objectid = ?");
  $sth->execute( $id );

  my @output = ();
  my @classes = ();
  while (my $row = $sth->fetchrow_hashref()) {
    push @classes, $row;
    push @output, "$row->{scheme}:$row->{class}";
  }
  $sth->finish();
  return (join(', ',@output),[@classes]);
}

# get a classification string for an object, formatted as an input string
#
sub classstring {
  my ($self,$tbl,$id) = @_;

  # first get the classification..
  #
  my @class = $self->getclass($tbl,$id);

  if (not defined $class[0]) {
    return '';
  }

  my @output;
  foreach my $c (@class) {
    push @output, "$c->{schema}:$c->{externalid}";
  }

  return join(', ',@output);
}

# print the classification for an object as
#
#	ns1: cat1
#			 cat2
#			 ...
#	ns2: cat1
#			 cat2
#			 ....
#		...
# 
# if possible, a parenthesized description will follow the cat#'s (like for msc)
#
sub printclass {
  my ($self,$tbl,$id,$fs) = @_;
  $fs = "+0" unless defined $fs;# font size

  my $html = '';

  # first get the classification..
  #
  my @class = $self->getclass($tbl,$id);

  if (not defined $class[0]) {
    return "";
  }

  $html.="<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">";

  my $curns = "";
  foreach my $row (@class) {
    $html .= "<tr>";
    my $nsprintable = getnsshortdesc($row->{ns});
    my $nslink = getnslink($row->{ns});

    if ($curns ne $row->{ns}) {
      $nsprintable =~ s/ /&nbsp;/;
      if (nb($nslink)) {
	$html .= "<td valign=\"top\"><font size=\"$fs\"><a target=\"planetmath_popup\" href=\"$nslink\">$nsprintable</a>:&nbsp;</font></td>";
      } else {
	$html .= "<td><font size=\"$fs\">$nsprintable:&nbsp;</font></td>";
      }
      $curns = $row->{ns};
    } else {
      $html .= "<td><font size=\"$fs\">&nbsp;</font></td>";
    }
    my $desc = '';
    if ($row->{ns} eq 'msc') {
      my $fss = $fs-1;
      $desc = "<font size=\"$fss\">(".getHierarchicalMscComment($row->{cat}).")</font>";
    }
    $html .= "<td><font size=\"$fs\"><a href=\"".getConfig("main_url")."/?op=mscbrowse&amp;from=$tbl&amp;id=$row->{cat}\">$row->{cat}</a> $desc</font></td>";
    $html .= "</tr>";
  }

  $html .= "</table>";

  return $html;
}

# get the short description field for a namespace
#
sub getnsshortdesc {
  my $ns=shift;

  return lookupfield(getConfig('ns_tbl'),'shortdesc',"name='$ns'");
}
sub getnsshortdescbyid {
  my $nid=shift;

  return lookupfield(getConfig('ns_tbl'),'shortdesc',"id=$nid");
}

# get the link field for a namespace
#
sub getnslink {
  my $ns=shift;

  return lookupfield(getConfig('ns_tbl'),'link',"name='$ns'");
}
sub getnslinkbyid {
  my $nid=shift;

  return lookupfield(getConfig('ns_tbl'),'link',"id=$nid");
}

sub declassify {
  my ($self,$objid) = @_;
  my $sth = $self->{db}->cachedPrepare("DELETE FROM classification where objectid = ?");
  $sth->execute( $objid );
  $sth->finish();
}

sub supportedscheme {
  my ($self,$scheme)=@_;
  foreach my $s ( @{$self->{config}->{'server'}->{'supported'}->{'scheme'}} ) {
    if ($scheme eq $s) {
      return 1;
    }
  }
  return 0;	
}

#use this function to make sure we add the classification scheme to the begining of every class
sub cleancategory {
  my ($self,$category,$domid) = @_;
  #$domid is the default category for the domain

  my ($scheme, @other ) = split( /:/, $category);
  my $ext = join( ":", @other );	

  #check the supported schemes and see if the category matches
  if ( !$self->supportedscheme( $scheme ) ) {
    my $domain = getdomainhash( $domid );
    $scheme = $self->{config}->{'domains'}->{'domain'}->{$domain->{'name'}}->{'defaultscheme'};
    $ext = $category;
    #	print "using default scheme - $scheme\n";
  }
  return ($scheme, $ext);
  #	return "$scheme:$ext";
}

sub addcategory {
  my $category = shift;
  my $default = shift;		#default category for the domain

  my ($scheme, @other ) = split( /:/, $category);
  my $ext = join( ":", @other );	


  print "adding category $scheme : $ext\n";
  my $sth = cachedPrepare("insert into categories (externalid, scheme) values (?,?)");
  # removed due to an eval related memory leak in perl
  #	eval {
  $sth->execute(  $ext, $scheme );
  $sth->finish();
  #	};
}

# shorten classifications, turn
#	 msc:11-00, msc:15-00, ...
# to
#	 msc:11-, msc:15-, ...
# or 
#    msc:11, msc:15, ...
#
# depending on the $level parameter
#
# expects normalization first.
#
sub catlevel {
  my $class = shift;
  my $level = shift;

  if ( $level == 3 ) {
    return $class;
  }

  my @cats = split(/\s*,\s*/,$class);
  foreach my $i (0..$#cats) {
    my ($ns,$longcat) = split(/\s*:\s*/,$cats[$i]);
    my $shortcat = '';
    if ($ns eq "msc") {
      $longcat =~ /^([0-9]{2})/ if ($level == 1);
      $longcat =~ /^([0-9]{2}.)/ if ($level == 2);
      $shortcat = $1;
    }
    $cats[$i] = "$ns:$shortcat";
  }

  return join(', ',@cats);
}


sub updateclass {
  my ($self,$objid,$domainid,$classes) = @_;

  $self->declassify( $objid );
  #	print Dumper($classes);

  my $upclass = $self->{db}->cachedPrepare("INSERT into classification (objectid, scheme, class) values ( ?, ?, ?)");
  foreach my $cl (@{$classes}) {
    my ( $scheme, $class ) = $self->cleancategory( $cl, $domainid );
    $upclass->execute( $objid, $scheme, $class );
  }
  $upclass->finish();
}

# get the classification for an object as an array of hashrefs {scheme, externalid}
# order is preserved.
#
sub getclass {
  my ($self,$id) = @_;
  my ($start, $finish, $DEBUG);
  $DEBUG = 0;

  if ($DEBUG) {
    $start = time();
  }

  my $sql = "SELECT class, scheme from classification where objectid = ?";
  my $sth = $self->{db}->cachedPrepare( $sql );
  $sth->execute( $id );

  my @classes = ();
  while (my $row = $sth->fetchrow_hashref()) {
    push @classes, { 'scheme' => $row->{'scheme'},
		     'class' => $row->{'class'} };
  }

  if ($DEBUG) {
    $finish = time();
    my $total = $finish - $start;
    print "getclass: $total seconds\n";
  }
  $sth->finish();

  return @classes;
}

# normalize an entire classification string
#
sub normalizeclass {
  my ($self,$class) = @_;

  my @carray = split(/\s*,\s*/,$class);

  foreach my $i (0..$#carray) {
    $carray[$i] = $self->normalizecat($carray[$i]);
  }

  return join (', ',@carray);
}

# normalize a category: put it in canonical form
#
sub normalizecat {
  my ($self,$cat) = @_;

  my ($ns,$catstring);

  # get classification namespace and string. if namespace isn't given,
  # use the default
  #
  if ($cat !~ /:/) {
    #for now we just hardcode msc because that is all that is supported now
    # anyway
    ($ns,$catstring) = ("msc",$cat);
  } else {
    ($ns,$catstring) = split(/\s*:\s*/,$cat);
  }

  # handle special things, per scheme
  #
  if ($ns eq 'msc') {
    if ($catstring =~ /^([0-9]{2})$/) {
      $catstring = "$1-00";
    }
    $catstring = uc($catstring);
  }

  return "${ns}:$catstring";
}

1;
