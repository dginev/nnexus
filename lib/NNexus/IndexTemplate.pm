package NNexus::IndexTemplate;
use warnings;
use strict;

### GENERIC METHODS
# To be directly inherited by concrete classes

sub new {
	my ($class,%options) = @_;
	bless {%options}, $class;
}

sub sanity {
	my ($self) = @_;
	$self->{start} //= $self->domain_root;
	# Check if start, page_regexp, ... 
	#	exist
	unless ($self->{start} && $self->{page_regexp}) {
		return 0;
	}
	return 1; # Sane setup if ok so far
}

# Getter or Setter for the initiale traversal URL
sub start { $_[1] ? $_[0]->{start} = $_[1] : $_[0]->{start}||$_[0]->domain_root; }

# 2. index: Traverse a page, obtain candidate concepts and candidate further links
sub index {
	my ($self,%options) = @_;
	$self->{start} = $options{start}||$options{START}||$self->{start};
	# 2.0. Check for configuration sanity
	return 0 unless $self->sanity;
	# 2.1. Record all pages in the category
	# 2.2. Record all subcategories
	# 2.3. Recurse in subcategories

	# 2.4. Return final list of concepts
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

sub domain_root { $_[0]->{domain_root}; } # To be overriden in the concrete classes
sub page_regexp { $_[0]->{page_regexp}; } # To be overriden in the concrete classes
sub candidate_links {
	# TODO: Generic implementation, retrieves ALL candidate links.
}

1;
__END__