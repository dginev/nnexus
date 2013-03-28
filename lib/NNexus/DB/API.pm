# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Backend API Module                                                  | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the GNU Public License                               | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #

package NNexus::DB::API;
use strict;
use warnings;
use feature 'switch';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(add_object);

sub add_object {
  my ($db,%options) = @_;
  my ($url, $domain) = map {$options{$_}} qw(url domain);
  my $sth = $db->prepare("INSERT into object (url, domain) values (?, ?)");
  $sth->execute($url,$domain);
  $sth->finish();
  # Return the object id in order to update the concepts and classification
  my $objid;
  given ($db->{dbms}) {
    when ('mysql') {
      $objid = $db->{handle}->{'mysql_insertid'};
    }
    when ('SQLite') {
      $objid = $db->{handle}->sqlite_last_insert_rowid();
    }
    default { die 'No DBMS information provided! Failing...'; }
  };
  return $objid;
}



1;
__END__

=pod 

=head1 NAME

C<NNexus::DB::API> - API routines for commonly used NNexus queries

=head1 SYNOPSIS

    use NNexus::DB;
    my $db = NNexus::DB->new(%options);
    $db->method(@arguments);

=head1 DESCRIPTION

This class provides API methods for specific SQL queries commonly needed by NNexus.

=head2 METHODS

=over 4

=item C<< $db->add_object(%options);

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the GNU Public License

=cut

