# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | High-level external API                                             | #
# |=====================================================================| #
# | Part of the Planetary project: http://trac.mathweb.org/planetary    | #
# |  Research software, produced as part of work done by:               | #
# |  the KWARC group at Jacobs University                               | #
# | Copyright (c) 2012                                                  | #
# | Released under the MIT License (MIT)                                | #
# |---------------------------------------------------------------------| #
# | Adapted from the original NNexus code by                            | #
# |                                  James Gardner and Aaron Krowne     | #
# |---------------------------------------------------------------------| #
# | Deyan Ginev <d.ginev@jacobs-university.de>                  #_#     | #
# | http://kwarc.info/people/dginev                            (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package NNexus;
use strict;
use warnings;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(linkentry indexentry);
our ($INSTALLDIR) = grep(-d $_, map("$_/NNexus", @INC));

use vars qw($VERSION);
$VERSION  = "2.0";

use Mojo::JSON 'j';
use NNexus::DB;
use NNexus::Job;
our %snapshot_credentials =
(
 "dbms" => "SQLite",
 "dbname" => "$INSTALLDIR/resources/database/snapshot.db",
 "dbuser" => "nnexus",
 "dbpass" => "nnexus",
 "dbhost" => "localhost",
) if $INSTALLDIR;

sub linkentry {
  my ($body,%options) = @_;
  my $db = delete $options{db};
  $options{embed} //= 1;
  $options{format} //= 'html';
  return $body unless ($db || %snapshot_credentials);
  $db = NNexus::DB->new(%snapshot_credentials) unless $db;
  my $job = NNexus::Job->new(function=>'linkentry',body=>$body,db=>$db,%options);
  $job->execute;
  my $result = $job->result;
  if ($options{annotation} && ($options{annotation} eq 'json')) {j($result);}
  return $result;
}

sub indexentry {
  my (%options) = @_;
  my $db = delete $options{db};
  return [] unless ($db || %snapshot_credentials);
  $db = NNexus::DB->new(%snapshot_credentials) unless $db;
  my $job = NNexus::Job->new(function=>'indexentry',db=>$db,%options);
  $job->execute;
  return $job->result;
}

1;
__END__

=pod 

=head1 NAME

C<NNexus> - Procedural API for NNexus indexing, auto-linking and annotation.

=head1 SYNOPSIS

  use NNexus;
  $annotated_text = linkentry($text,%options);
  $invalidated_urls = indexentry($url,%options);

=head1 DESCRIPTION

This class provides a high-level user-facing procedural API for NNexus processing.
  Useful for Perl scripting, for example:
  
  perl -MNNexus -e 'print linkentry(join("",<>))' < example.html > linked_example.html

=head2 METHODS

=over 4

=item C<< $annotated_text = linkentry($text,%options); >>

Wikifies/auto-links the provided $text against the default NNexus database, unless otherwise specified.
  The accepted %options are all accepted options of the L<NNexus::Job> new constructor.

=item C<< $invalidated_urls = indexentry($url,%options); >>

Indexes a new entry located at the provided $url,
 invalidates the current auto-link jobs known to the default database
 and returns the entries to be invalidated.
 The accepted %options are all accepted options of the L<NNexus::Job> new constructor.

=back

=head1 SEE ALSO

L<NNexus::Job>, L<nnexus>, L<NNexus::Manual>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by 
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut