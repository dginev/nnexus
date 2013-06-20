use strict;
use warnings;

use Test::More tests => 5;
use NNexus::Annotate qw(serialize_concepts);
use Mojo::JSON;
my $json  = Mojo::JSON->new;
my $body = "Simple testing sentence. We want Banach's algebra linked, \nalso Abelian groups.";
my $text_concepts = [
	{	concept=>'Banach\'s algebra',
		offset_begin=>33,
		offset_end=>49,
		domain=>'Planetmath',
		link=>'planetmath.org/banachalgebra'
	},
	{	concept=>'Abelian groups',
		offset_begin=>64,
		offset_end=>78,
		domain=>'Mathworld',
		link=>'mathworld.wolfram.com/AbelianGroup.html'
	},
	{	concept=>'Abelian groups',
		offset_begin=>64,
		offset_end=>78,
		domain=>'Planetmath',
		multilinks=>[
			'planetmath.org/abeliangroup',
			'planetmath.org/group']
	}
];
my $annotated_text = <<'ANNOTATED_TEXT';
Simple testing sentence. We want <a class="nnexus_concept" href="http://planetmath.org/banachalgebra">Banach's algebra</a> linked, 
also <a class="nnexus_concepts" href="javascript:void(0)" onclick="this.nextSibling.style.display='inline'">Abelian groups</a><sup style="display: none;"><a class="nnexus_concept" href="http://planetmath.org/abeliangroup"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" href="http://planetmath.org/group"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" href="http://mathworld.wolfram.com/AbelianGroup.html"><img src="http://mathworld.wolfram.com/favicon_mathworld.png" alt="Mathworld"></img></a></sup>.
ANNOTATED_TEXT
chomp($annotated_text); # No artificial newline

is_deeply(
	serialize_concepts(
		domain=>'all',
		embed=>1,
		annotation=>'html',
		format=>'text',
		body=>$body,
		concepts=>$text_concepts),
	$annotated_text,
	'Embed HTML links in plain text');


my $html_body = <<'HTML_BODY';
<html>
	<body>
		<p>Simple testing sentence.</p>
		<p>We want <b>Banach's algebra</b> linked, 
			also <b>Abelian groups</b>.</p>
	</body>
</html>
HTML_BODY
chomp($html_body); # Disregard spurious newline
my $html_concepts = [
	{	concept=>'Banach\'s algebra',
		offset_begin=>65,
		offset_end=>81,
		domain=>'Planetmath',
		link=>'planetmath.org/banachalgebra'
	},
	{	concept=>'Abelian groups',
		offset_begin=>106,
		offset_end=>120,
		domain=>'Mathworld',
		link=>'mathworld.wolfram.com/AbelianGroup.html'
	},
	{	concept=>'Abelian groups',
		offset_begin=>106,
		offset_end=>120,
		domain=>'Planetmath',
		multilinks=>[
			'planetmath.org/abeliangroup',
			'planetmath.org/group']
	}
];
my $annotated_html = <<'ANNOTATED_HTML';
<html>
	<body>
		<p>Simple testing sentence.</p>
		<p>We want <b><a class="nnexus_concept" href="http://planetmath.org/banachalgebra">Banach's algebra</a></b> linked, 
			also <b><a class="nnexus_concepts" href="javascript:void(0)" onclick="this.nextSibling.style.display='inline'">Abelian groups</a><sup style="display: none;"><a class="nnexus_concept" href="http://planetmath.org/abeliangroup"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" href="http://planetmath.org/group"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" href="http://mathworld.wolfram.com/AbelianGroup.html"><img src="http://mathworld.wolfram.com/favicon_mathworld.png" alt="Mathworld"></img></a></sup></b>.</p>
	</body>
</html>
ANNOTATED_HTML
chomp($annotated_html); # No artificial newline
is_deeply(
	serialize_concepts(
		domain=>'all',
		embed=>1,
		annotation=>'html',
		format=>'html',
		body=>$html_body,
		concepts=>$html_concepts),
	$annotated_html,
	'Embed HTML links in a simple HTML document.');

my $annotated_htmlrdfa = <<'ANNOTATED_HTMLRDFA';
<html>
	<body>
		<p>Simple testing sentence.</p>
		<p>We want <b><a class="nnexus_concept" property="http://purl.org/dc/terms/relation" href="http://planetmath.org/banachalgebra">Banach's algebra</a></b> linked, 
			also <b><a class="nnexus_concepts" href="javascript:void(0)" onclick="this.nextSibling.style.display='inline'">Abelian groups</a><sup style="display: none;"><a class="nnexus_concept" property="http://purl.org/dc/terms/relation" href="http://planetmath.org/abeliangroup"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" property="http://purl.org/dc/terms/relation" href="http://planetmath.org/group"><img src="http://planetmath.org/sites/default/files/fab-favicon.ico" alt="Planetmath"></img></a><a class="nnexus_concept" property="http://purl.org/dc/terms/relation" href="http://mathworld.wolfram.com/AbelianGroup.html"><img src="http://mathworld.wolfram.com/favicon_mathworld.png" alt="Mathworld"></img></a></sup></b>.</p>
	</body>
</html>
ANNOTATED_HTMLRDFA
chomp($annotated_htmlrdfa); # No artificial newline
is_deeply(
	serialize_concepts(
		domain=>'all',
		embed=>1,
		annotation=>'HTML+RDFa',
		format=>'html',
		body=>$html_body,
		concepts=>$html_concepts),
	$annotated_htmlrdfa,
	'Embed HTML+RDFa links in a simple HTML document.');

# We need to compare the Perl datastructures and not the JSON strict directly,
# as from Perl 5.18 the order of hash keys is randomized differently at every run
my $standoff_json = [{
	"link"=>"http:\/\/planetmath.org\/banachalgebra",
	"domain"=>"Planetmath",
	"offset_end"=>81,
	"offset_begin"=>65,
	"concept"=>"Banach's algebra"},
	{"link"=>"http:\/\/mathworld.wolfram.com\/AbelianGroup.html",
	"domain"=>"Mathworld",
	"offset_end"=>120,
	"offset_begin"=>106,
	"concept"=>"Abelian groups"},
	{"domain"=>"Planetmath",
	"offset_end"=>120,
	"offset_begin"=>106,
	"concept"=>"Abelian groups",
	"multilinks"=>["http:\/\/planetmath.org\/abeliangroup","http:\/\/planetmath.org\/group"]
	}];

is_deeply(
	$json->decode(
		serialize_concepts(
			domain=>"all",
			embed=>0,
			annotation=>"json",
			concepts=>$html_concepts)),
	$standoff_json,
	'Stand-off JSON annotation');

use Data::Dumper;
$Data::Dumper::Sortkeys =1;
# We use Data Dumper's Sortkeys to neutralize the Perl 5.18 hash key randomness
# TODO: Is this in any way needed/important/useful ?
is_deeply(
	serialize_concepts(
		domain=>"all",
		embed=>0,
		annotation=>"perl",
		concepts=>$html_concepts),
	Dumper($html_concepts),
	'Stand-off Perl annotation');

