package NNexus::IndexTemplate;

# 1. Set all default values, 
sub new {
	my ($class,%options) = @_;
	bless {%options}, $class;
}

sub sanity {
	my ($self) = @_;
	# Check if start, page_regexp, ... 
	#	exist
}

sub start { $_[0]->{start}; }
sub page_regexp { $_[0]->{page_regexp}; }

# 2. For every page we traverse
sub index {
	my ($self,%options) = @_;
	# 2.0. Check for configuration sanity
	return unless $self->sanity;
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

1;
__END__