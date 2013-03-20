package NNexus::IndexTemplate;
use warnings;
use strict;
use Mojo::DOM;
use Mojo::UserAgent;
### GENERIC METHODS
# To be directly inherited by concrete classes

sub new {
	my ($class,%options) = @_;
	my $ua = Mojo::UserAgent->new;
	bless {ua=>$ua,%options}, $class;
}
sub ua {$_[0]->{ua};}
sub sanity {
	my ($self,$options) = @_;
	$self->current_url($options->{current_url});
	delete ($options->{current_url});
	# Check if current_url, page_regexp, ... 
	#	exist
	unless ($self->current_url) {
		return;
	}
	return 1; # Sane setup if ok so far
}

# Getter or Setter for the current URL to be indexed
sub current_url { $_[1] ? $_[0]->{current_url} = $_[1] : $_[0]->{current_url}||$_[0]->domain_root; }
sub current_dom { $_[1] ? $_[0]->{current_dom} = $_[1] : $_[0]->{current_dom}; }

# 2. index: Traverse a page, obtain candidate concepts and candidate further links
sub index {
	my ($self,%options) = @_;
	$options{current_url}//=$options{start}; # Start is fallback if no current_url set yet.
	# 2.0. Check for configuration sanity
	return unless $self->sanity(\%options);
	# 2.1. Prepare (or just accept) a Mojo::DOM to be analyzed
	if ($options{dom}) {
		$self->{current_dom} =  $options{dom};
		delete $options{dom};
	} else {
		$self->{current_dom} = $self->ua->get($self->current_url)->res->dom;
	}
	# 2.1. Record all pages in the category
	my $candidate_links = $self->candidate_links;
	# 2.2. Obtain the indexer payload
	my $payload = $self->index_page;
	# 2.3. Recurse in subcategories
	foreach (@$candidate_links) {
		$options{current_url}=$_;
		push @$payload, $self->index(%options);
	}
	# 2.4. Return final list of concepts
	return $payload;
	# We want to return a list of hashes:
	# [
	#   { URL => $url,
	#	  canonical => $canonical,
	#     NLconcept => $concepts,
	#     category => $category 
	#   }, ...
	# ]
}

### CONCRETE METHODS
# To be overloaded by concrete classes

sub domain_root {q{};} # To be overriden in the concrete classes
sub index_page {[];} # To be overriden in the concrete classes
sub candidate_links {
	[];
	# TODO: Generic implementation, retrieves ALL candidate links.
}

1;
__END__