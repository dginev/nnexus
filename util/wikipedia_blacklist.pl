#/usr/bin/perl -w
use strict;
use warnings;
# This script starts with a fresh NNexus SQLite database 
#  and performs an indexing pass over all defined Index Templates
#  currently: PlanetMath, Wikipedia, DLMF and Mathworld

# It then creates a snapshot - both as a DB file and as a SQLite db dump.
# 1. Initialize
use NNexus::Index::Dispatcher;
use NNexus::Index::Wikipedia;
use Data::Dumper;
use Mojo::DOM;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $date = $mday.'-'.($mon+1).'-'.(1900+$year);

my $domain = "Wikipedia";
my %cached_choice = ();
# Build on the existing white/black lists:
open my $white_fh, "<", 'whitelist.txt';
while (<$white_fh>) {
  chomp;
  $cached_choice{$_} = 1; }
close $white_fh;

open my $black_fh, "<", 'blacklist.txt';
while (<$black_fh>) {
  chomp;
  $cached_choice{$_} = 0; }
close $black_fh;

open $white_fh, ">>", 'whitelist.txt';
open $black_fh, ">>", 'blacklist.txt';


my $dispatcher = NNexus::Index::Dispatcher->new(domain=>$domain,
  verbosity=>1,should_update=>1,
  start=>'default');
while ($dispatcher->index_step) {}

# Close file handles
close $white_fh;
close $black_fh;

package NNexus::Index::Dispatcher;
sub index_step {
  my ($self,%options) = @_;
  my $template = $self->{index_template};
  my $db = $self->{db};
  my $domain = $self->{domain};
  my $verbosity = $options{verbosity} ? $options{verbosity} : $self->{verbosity};
  # 1. Check if object has already been indexed:
  my $next_step = $template->next_step;
  return unless ref $next_step; # Done if nothing left.
  unshift @{$template->{queue}}, $next_step; # Just peaking, keep it in the queue
  my $url = $next_step->{url}; # Grab the next canonical URL
  if ($template->leaf_test($url)) { # Skip leaves
        return []; }
  # 2. Relay the indexing request to the template, gather concepts
  my $indexed_concepts = $template->index_step(%options);
  return unless defined $indexed_concepts; # Last step.
  return []; # We have what to continue with
}

package NNexus::Index::Wikipedia;
sub request_interval { 2; }
use IO::Prompt;
sub user_agreement {
  my ($url) = @_;
  $url =~ s/^\/wiki\/Category\://;
  return $cached_choice{$url} if exists $cached_choice{$url};

  my $agreement = prompt("$url : ");
  if ($agreement =~ /^n/i) {
    print $black_fh "$url\n";
    $cached_choice{$url} = 0;
    return 0; }
  else {
    print $white_fh "$url\n";
    $cached_choice{$url} = 1;
    return 1;
  }}
sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  # Add links from subcategory pages
  if ($url =~ /$NNexus::Index::Wikipedia::category_test/ ) {
    my $category_name = $1;
    my $dom = $self->current_dom;
    my $subcategories = $dom->find('#mw-subcategories')->[0];
    my @category_links = ();
    if( defined $subcategories ) {
      @category_links = $subcategories->find('a')->each;
      @category_links = grep {user_agreement($_)} grep {defined && /$NNexus::Index::Wikipedia::english_category_test/} map {$_->{href}} @category_links; }
    my $candidates = [ map {$NNexus::Index::Wikipedia::wiki_base . $_ } @category_links ];
    return $candidates;
  } else {return [];} # skip leaves
}

1;