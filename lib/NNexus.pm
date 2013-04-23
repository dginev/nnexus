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
our @EXPORT = qw(linkentry);
our ($INSTALLDIR) = grep(-d $_, map("$_/NNexus", @INC));

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

# TODO: Use a snapshot by default
sub linkentry {
  my ($body,%options) = @_;
  my $db = $options{db};
  $options{embed} = 1 unless defined $options{embed};
  $options{format} = 'html' unless defined $options{format};
  return $body unless ($db || %snapshot_credentials);
  $db = NNexus::DB->new(%snapshot_credentials) unless $db;
  my $job = NNexus::Job->new(function=>'linkentry',body=>$body,db=>$db,%options);
  $job->execute;
  return $job->result;
}

1;
__END__
