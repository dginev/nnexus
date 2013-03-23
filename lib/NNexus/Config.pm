# /=====================================================================\ #
# |  NNexus Autolinker                                                  | #
# | Runtime Configuration Module                                        | #
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

package NNexus::Config;
use strict;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(&read_json_file);
use Data::Dumper;

use NNexus::Concepts;
use NNexus::Classification;
use NNexus::Domain;
use NNexus::DB;

sub new {
  my ($class,$opts) = @_;
  $opts = read_json_file('conf.json') unless defined $opts;
  if ($opts->{verbosity} && $opts->{verbosity} > 0) {
    print STDERR "Starting NNexus with configuration:\n";
    print STDERR Dumper( $opts );
  }
  my $db = NNexus::DB->new(%{$opts->{database}});
  $opts->{db} = $db;

  my $classification = NNexus::Classification->new(db=>$db,config=>{ %$opts });
  $classification->initClassificationModule();
  $opts->{classification} = $classification;
  bless $opts, $class;
}

sub get_DB {
  $_[0]->{db};
}

sub read_json_file {
  my $file_name = shift;
  use JSON::PP qw(decode_json);
  open my $fh, "<", $file_name or die "Error opening Configuration JSON file: $file_name!\n";
  my $string = join('',<$fh>);
  close $fh;
  return decode_json($string);
}

1;

__END__

=pod 

=head1 NAME

C<NNexus::Config> - Configuration class for NNexus startup

=head1 SYNOPSIS

    use NNexus::Config;
    my $config = NNexus::Config->new($opts);

=head1 DESCRIPTION

Refactored from the old NNexus approach to startup, creates a configuration object for a NNexus server.

NOTE: A huge refactoring job is still ahead of this class...

=head2 METHODS

=over 4

=item C<< my $config = NNexus::Config->new($opts); >>

Initialize a new configuration object.
Options are given via an optional XML::Simple object $opts, or in an XML syntax in "baseconf.xml" in the current directory.
TODO: Add XML syntax docs somewhere here

=back

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>
(Based on code from James Gardner and Aaron Krowne)

=head1 COPYRIGHT

GPLv3

=cut
