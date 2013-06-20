# /=====================================================================\ #
# | NNexus Autolinker                                                   | #
# | Indexing Plug-in, Wikipedia.org domain                              | #
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
package NNexus::Index::Wikipedia;
use warnings;
use strict;
use base qw(NNexus::Index::Template);
use feature 'say';
use List::MoreUtils qw(uniq);

# 0. Special Blacklist for Wikipedia categories:
our $wiki_category_blacklist = {map {$_=>1}
qw(Pattern_matching Computer_algebra_systems Data_mining_and_machine_learning_software
Audio_editors Digital_signal_processors Image_processing Speech_processing
Speech_recognition Video_processing Voice_technology File_sharing_networks
Computer-aided_design Geographic_information_systems Graph_drawing Researchers_in_geometric_algorithms
Numerical_software Pattern_matching_programming_languages String_matching_algorithms
Molecular_dynamics Internet_search_algorithms Statistical_software Buildings_and_structures_by_shape
Numerology Telephone_numbers Audio_codecs MP3 Video_codecs Broken_block_ciphers Broken_stream_ciphers
Ciphers OS_X_audio_editors Digital_audio_workstation_software Computer_vision
Digital_photography Graphics_file_formats Medical_imaging Speech_processing_software 
Speech_synthesis Video_compression BitTorrent Distributed_data_storage Gnutella
CAD_file_formats Computer-aided_design_software Earth_sciences_graphics_software Geocodes
GIS_file_formats GIS_software OpenStreetMap Geographic_information_systems_organizations
Web_mapping Graph_drawing_software Data_analysis_software Econometrics_software Free_statistical_software
Plotting_software Statistical_programming_languages Time_series_software Basilicas
Cubic_buildings Domes Octagonal_buildings Pyramids Rotundas Round_barns Towers Twisted_buildings_and_structures
Top_lists Bible_code Telephone_numbers_by_country North_American_Numbering_Plan Telephone_directory_publishing_companies
Telephone_number_stubs Digital_audio_players Video_conversion_software Classical_ciphers Block_ciphers
Stream_ciphers Uncracked_codes_and_ciphers Ableton_Live
Applications_of_computer_vision Computer_vision_research_infrastructure Digital_cameras
Image_sensors Photo_software Adobe_Flash Contrast_agents Electrophysiology Magnetic_resonance_imaging
Medical_photography_and_illustration Nuclear_medicine Radiography Speech_synthesis_software
BitTorrent_clients BitTorrent_websites Cloud_storage Distributed_data_storage_systems Free_computer-aided_design_software
Electronic_design_automation_software Virtual_globes Geolocation ISO_3166 Lists_of_postal_codes
Nomenclature_of_Territorial_Units_for_Statistics Spatial_databases Web_Map_Services
Fortran R_(programming_language) Spreadsheet_software Data_visualization_software Light
Radiation Sound Water_waves Twelve-tone_and_serial_composers Ecclesiastical_basilicas Secular_basilicas
Aqueducts Arch_bridges Bridge-tunnels Cable-stayed_bridges Covered_bridges Girder_bridges
Moveable_bridges Navigable_aqueducts Skew_bridges Suspension_bridges Swing_bridges Truss_bridges
Viaducts Astronomical_observatories Covered_stadiums Geologic_domes Mosques Planetaria Octagonal_buildings_in_Canada
Octagon_houses Octagonal_buildings_in_the_United_States Ziggurats Round_barns_in_the_United_States Towers_by_country
Bell_towers Chimneys Clock_towers Communication_towers Defunct_towers Fictional_towers Fire_lookout_towers
Guyed_masts Lighthouses Observation_towers Peel_towers Skyscrapers Tower_mills Water_towers Mast_stubs
Molecular_topology Graph_description_languages Mathematical_chemistry Algorithm_description_languages
Digital_signal_processing Advanced_Access_Content_System
Error_detection_and_correction Computational_physics Pseudorandom_number_generators Algorithms_on_strings
String_data_structures Gyroscopes Vestibular_system Balloons Dualism Dimensional_instruments Nothing Phenomena
Space Spacetime Structure Time Tactical_formations Statistical_data_types Rotating_machines Torque Rubik%27s_Cube
Balloons_(aircraft) Consciousness%E2%80%93matter_dualism Dichotomies Duos Technical_drawing Darkness Hesychasm
Silence Vacuum Action Cultural_trends Earliest_phenomena Events Evolution Hazards Human_development Illusions
Industrial_processes Life Motion  Periodic_phenomena Physical_phenomena Thermodynamic_processes Length Navigation
Outer_space Places Abstraction Anatomy Chaos Components Conceptual_distinctions Design Geography Mental_structures
Musical_form Objects Organizations Rhythm Skeletal_system Society Statics Systems General_relativity Special_relativity
Time_by_country Causality Cosmology Daylight_saving_time Future Horology Interregnums Time_management Nostalgia
Philosophy_of_time Power_(physics) Time_in_religion Time_travel Timekeeping Time_zones Epidemiology Official_statistics
Quality_control X-ray_scattering Carousels Engines Rotary_engines Lathes Turbines Wheels Balloon-borne_experiments
Ballooning Equal_temperaments Spiritualism Vitalism Mind%E2%80%93body_problem Art_duos Criminal_duos Entertainer_duos
Fictional_duos Filmmaking_duos Married_couples Sibling_duos Sports_duos Writing_duos Deafness Silent_film Mime
Behavior Creativity Determinism Fictional_activities Free_will Intention Motivation Planning Prevention Skills Fads
Fashion Public_opinion Style Inventions Lists_of_events Fictional_events Accidents Cancelled_projects_and_events
Causes_of_events Conflicts Controversies  Current_events Disasters  Hoaxes News Organized_events Recurring_events
Biological_evolution Memetics Sociocultural_evolution Stellar_evolution Fire Hazardous_motor_vehicle_activities
Natural_hazards Warning_systems Adolescence Adulthood Ageing Childhood Death Developmental_disabilities Infancy
Parenting Personal_development Developmental_psychology Youth Magic_(illusion) Optical_illusions Abrasive_blasting
Chemical_processes Coatings Combustion_engineering Food_processing Furnaces Glass_forming Industrial_machinery
Joining Machining Metallurgical_processes Packaging Papermaking Photographic_processes Printing_processes
Kinematics Human_height Handedness Wave_farms_in_Denmark Wave_farms_in_the_United_Kingdom
Crystallography Acceleration Linkages Mechanisms Robot_kinematics African_Pygmies Dwarfism
People_with_gigantism Growth_disorders Growth_hormones Density Compositions_for_piano_left-hand_and_orchestra
)};

# EN.Wikipedia.org indexing template
# 1. We want to start from the top-level math category
sub domain_root { "http://en.wikipedia.org/wiki/Category:Mathematical_concepts"; }
our $category_test = qr/\/wiki\/Category:(.+)$/;
our $english_category_test = qr/^\/wiki\/Category:/;
our $english_concept_test = qr/^\/wiki\/[^\/\:]+$/;
our $wiki_base = 'http://en.wikipedia.org';
# 2. Candidate links to subcategories and concept pages
sub candidate_links {
  my ($self)=@_;
  my $url = $self->current_url;
  # Add links from subcategory pages
  if ($url =~ /$category_test/ ) {
    my $category_name = $1;
    return [] if $wiki_category_blacklist->{$category_name};
    my $dom = $self->current_dom;
    my $subcategories = $dom->find('#mw-subcategories')->[0];
    return [] unless defined $subcategories;
    my @category_links = $subcategories->find('a')->each;
    @category_links = grep {defined && /$english_category_test/} map {$_->{href}} @category_links;

    # Also add terminal links:
    my $concepts = $dom->find('#mw-pages')->[0];
    my @concept_links = $concepts->find('a')->each if defined $concepts;
    @concept_links = grep {defined && /$english_concept_test/} map {$_->{href}} @concept_links;

    my $candidates = [ map {$wiki_base . $_ } (@category_links, @concept_links) ];
    return $candidates;
  } else {return [];} # skip leaves
}

# Index a concept page, ignore category pages
sub index_page { 
  my ($self) = @_;
  my $url = $self->current_url;
  # Nothing to do in category pages
  return [] unless $self->leaf_test($url);
  my $dom = $self->current_dom;
  # We might want to index a leaf page when descending from different categories, so keep them marked as "not visited"
  delete $self->{visited}->{$url};
  my ($concept) = map {/([^\(]+)/; lc(rtrim($1));} $dom->find('span[dir="auto"]')->pluck('all_text')->each;
  my @synonyms;
  # Bold entries in the first paragraph are typically synonyms.
  my $first_p = $dom->find('p')->[0];  
  @synonyms = (grep {(length($_)>4) && ($_ ne $concept)} map {lc $_} $first_p->children('b')->pluck('all_text')->each) if $first_p;
  my $categories = $self->current_categories || ['XX-XX'];

  return [{ url => $url,
	 concept => $concept,
   scheme => 'wiki',
	 categories => $categories,
	 @synonyms ? (synonyms => \@synonyms) : ()
   }];
}

sub candidate_categories {
	my ($self) = @_;
	if ($self->current_url =~ /$category_test/ ) {
		return [$1];
	} else {
		return $self->current_categories;
	}
}

# The subcategories trail into unrelated topics after the 4th level...
sub depth_limit {10;} # But let's bite the bullet and manually strip away the ones that are pointless
sub leaf_test { $_[1] !~ /$category_test/ }
# Utility:
# Right trim function to remove trailing whitespace
sub rtrim {
	my $string = shift;
	$string =~ s/\s+$//;
	return $string; }

1;
__END__

=pod

=head1 NAME

C<NNexus::Index::Wikipedia> - Indexing plug-in for the (English) L<Wikipedia.org|http://wikipedia.org> domain.

=head1 DESCRIPTION

Indexing plug-in for the (English) Wikipedia.org domain.

See L<NNexus::Index::Template> for detailed indexing documentation.

=head1 SEE ALSO

L<NNexus::Index::Template>

=head1 AUTHOR

Deyan Ginev <d.ginev@jacobs-university.de>

=head1 COPYRIGHT

 Research software, produced as part of work done by
 the KWARC group at Jacobs University Bremen.
 Released under the MIT License (MIT)

=cut