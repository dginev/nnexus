package NNexus;


#this code is verbatim from Noosphere except the package names.

use strict;
use Cwd;
use NNexus::Util;
use NNexus::Charset;
use NNexus::Crossref;

# needed for when we require images.pl
#
use vars qw{%cached_env_img $reruns %VISIBLETAGS %LINKTAGS};

%VISIBLETAGS = (
	'textit'=>1,
	'footnote'=>1,
	'emph'=>1,
	'proof'=>1,  # commonly defined
	'defn'=>1,   # commonly defined
	'text'=>1,
	'textsl'=>1, 
	'textsc'=>1, 
	'textmd'=>1, 
	'textbf'=>1, 
	'textit'=>1, 
	'tiny'=>1, 
	'scriptsize'=>1, 
	'footnotesize'=>1, 
	'small'=>1, 
	'normalsize'=>1, 
	'large'=>1, 
	'Large'=>1, 
	'LARGE'=>1, 
	'huge'=>1, 
	'HUGE'=>1,
 	'item'=>1
);


# a regexp string which will match any command that indicates we need to run
# LaTeX twice.
$reruns = "ref|eqref|cite";

# fragment pseudo-latex Noosphere commands. basically this means we turn
# one command that contains some math environments, $-escaped, to multiple 
# commands with the math portions extracted and *between* the commands.
#
# for example, we convert things like:
#	 \PMlinkname{$\sigma$-derivation}{SigmaDerivation}
# to
#	 $\sigma$\PMlinkname{-derivation}{SigmaDerivation}
#
sub fragmentpseudos {
	my $text = shift;

	# better to read the description above and re-construct the code yourself
	# than to try to understand this... it could be a lot worse too.
	#
	while ($text =~ /\\PM\w+\{([^\}]*?)\$.+?\$([^\}]*?)\}\{.+?\}/s) {
		if ($1 && $2) {
			$text=~s/(\\PM\w+\{)([^\}]*?)(\$.+?\$)([^\}]*?\})(\{.+?\})/$1$2\}$5$3$1$4$5/s;
		} else {
			if ($2) {
				$text=~s/(\\PM\w+\{)([^\}]*?)(\$.+?\$)([^\}]*?\})(\{.+?\})/$3$1$4$5/s;
			}
			elsif ($1) {
				$text=~s/(\\PM\w+\{)([^\}]*?)(\$.+?\$)([^\}]*?\})(\{.+?\})/$1$2\}$5$3/s;
			}
			else {
				$text=~s/(\\PM\w+\{)([^\}]*?)(\$.+?\$)([^\}]*?\})(\{.+?\})/$3/s;
			}
		}
	}
	#dwarn "split text is [$text]";
	return $text;
}

# get an ASCII or HTML (default) synopsis of a LaTeX fragment
# 
sub getLaTeXSynopsis {
	my $latex = shift;
	my $ascii = shift || 0;

	# change $x$ to x to make inline math still-readable (usually a good assumption)
	#
	if ($ascii) {
		$latex =~ s/\$\s*(\w)\s*\$/$1/g;
	} else {
		$latex =~ s/\$\s*(\w)\s*\$/<i>$1<\/i>/g;
	}

	# also make $\symbol$ readable
	#
	$latex =~ s/\$\s*\\(\w+)\s*\$/$1/g;

	# remove pseudo-commands 
	#
	my $prefix = getConfig('latex_cmd_prefix');
	$latex =~ s/\\$prefix\w*\{.*?\}//sg;

	# split out more complex math
	#
	my ($data) = splitLaTeX($latex);

	# fix punctuation spacing
	$data =~ s/([\w\}]) ([;.,):\?\'])/$1$2/sg;
	$data =~ s/([(\`]) ([\w\\])/$1$2/sg;
 
	$data =~ s/##[0-9]+##/ ... /g;	
	$data =~ s/@@(.+?)@@/ ... /g;

	# remove LaTeX directives
	$data =~ s/\\emph\{(.+?)\}/ $1 /g;
	$data =~ s/\\includegraphics.*?\{.*?\}/ ... /g;
	$data =~ s/\\\w+/ /g;
	$data =~ s/\{(tabular|list|center|itemize|enumerate)\}/ /g;
	$data =~ s/\{(.+?)\}/ $1 /g;
	$data =~ s/\\\\/ /g;

	# other post-processing
	# 
	$data =~ s/\n/ /g;
	$data =~ s/\s+/ /g;
	$data =~ s/(\s*[.]{3}\s*)+/ ... /g;
	$data =~ s/([^ ])[.]{3}([^ ])/$1 ... $2/g;

	return $data;
}

# mangle a given title into a index-form title 
# ("proof of blah" => "blah, proof of")
#
sub mangleTitle {
	my $title = shift;

	($title, my $math) = escapeMathSimple($title);

	my $modified = 0;
	while ($title =~ /^\s*(proof|derivation|example[s]?|of|that|the|an|any|a)\s+(.+)/) {
		my $end = $1;	 # piece to move to end
		my $beg = $2;	 # new beginning 

		my $com = $modified ? '' : ',';
		$title = $beg . $com . ' ' . $end;
		$modified = 1;
	}

	return unescapeMathSimple($title, $math);
}

# simple "escape" of math.. take $.?$ sections and replace them with 
# unambiguous, single-word tags that are relatively inert to other processing.
#
sub escapeMathSimple {
	my $text = shift;

	my $copy = $text;
	my @math = ();
	my $idx = 0;

	while ($copy =~ /(\$.+?\$)/g) {
		my $chunk = $1;
		push @math, $chunk;
		$text =~ s/\Q$chunk\E/##$idx##/;
		$idx++;
	}

	return ($text, [@math]);
}

# reverse the above -- replace unique identifiers with the original math
#
sub unescapeMathSimple {
	my $text = shift;
	my $math = shift;

	# reversing is much simpler....
	#
	$text =~ s/##(\d+)##/$math->[$1]/g;
	
	return $text;
}

# supplementaryPackages - determine what additional packages must be included
# based on a command=>package hash and some text. 
# returns a bunch of \usepackage{}'s as one chunk
# of text
#
sub supplementaryPackages {
	my $latex = shift;
	my $lookup = shift;
	my $params = shift;

	my %includehash;

	# loop through the commands in the lookup table looking for them in the latex
	#
	foreach my $command (keys %$lookup) {
		$includehash{$lookup->{$command}}=1 if ($latex=~/\\$command([\{\[\s])/s);
	}

	my @includes;
	foreach (keys %includehash) {
		push @includes,"\\usepackage[$params->{$_}]{$_}" if (defined $params->{$_});
		push @includes,"\\usepackage{$_}";
	}
	my $include = join("\n",@includes);

	return $include;
}

# same as above but detect "environment-style" commands
#
sub supplementaryEnvPackages {
	my $latex = shift;
	my $lookup = shift;
	my $params = shift;

	my %includehash;

	# loop through the commands in the lookup table looking for them in the latex
	#
	foreach my $command (keys %$lookup) {
		$includehash{$lookup->{$command}}=1 if ($latex=~/\\begin\{$command\}/s);
	}

	my @includes;
	foreach (keys %includehash) {
		push @includes,"\\usepackage[$params->{$_}]{$_}" if (defined $params->{$_});
	push @includes,"\\usepackage{$_}";
	}
	my $include=join("\n",@includes);

	return $include;
}

# check to see if a singly rendered math chunk exists in the database
#
sub variant_exists {
	my $math = shift;
	my $variant = shift;

	my ($rv, $sth) = dbSelect($dbh, {WHAT=>'uid', FROM=>getConfig('rendered_tbl'), WHERE=>"imagekey = '".sq($math)."' and variant = '".sq($variant)."'"});
	my $rowcount = $sth->rows();
	$sth->finish();

	return $rowcount;
}

# the low-level interface to rendering a single math environment to a png image
#
sub singleRenderLaTeX {
	my $math = shift;
	my $variants = shift || getConfig('single_render_variants');

	# make a rendering directory in /tmp
	# 
	my $suffix = 0;
	my $root = getConfig('single_render_root');
#	while (-e "$root$suffix") {
#		$suffix++;
#	}
#	my $dir = $root . $suffix;
	my $dir = $root;

	# can only render one at a time
	#
	if (-e $dir) {
		return 1;
	}
	mkdir $dir;

	# copy over templates we need
	#
	my $template_root = getConfig('stemplate_path');
	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";
	`cp "$template_root/.latex2html-singlerender-init" $dir/.latex2html-init`;

	my $prefix = getConfig('single_render_template_prefix');

	# loop through each variant, render the math and load the image into the 
	# database (if its not there already, this is a last line of defens failsafe)
	# 
	foreach my $variant (@$variants) {
		next if (variant_exists($math, $variant));

		# do the rendering
		#
		require Noosphere::Template;
		my $template = new Template($prefix . "_$variant.tex");
		$template->setKey('math', $math);
		writeFile("$dir/single_render.tex", $template->expand());
		chdir $dir;
		my $retval = system(getConfig('base_dir') . "/bin/latex2html ".getConfig('l2h_opts')." single_render.tex >error.out 2>&1");

		# abort if a render failed
		#
		if ($retval > 0) {
			return $retval;
		}
	
		# read in the resulting image, convert binary data to octal 
		#
		my $image;
		$image = octify(readFile($dir . '/img1.png')) if getConfig('dbms') eq 'pg';
		$image = readFile($dir . '/img1.png') if getConfig('dbms') eq 'mysql';

		# read in the align mode
		#
		my $imagespl = readFile($dir . '/images.pl');
		my $align = 'bottom';	# default align

		if ($imagespl =~ /ALIGN="(.+?)"/) {
			$align = lc($1);
		}

		# insert into database
		#
		my $sth = $dbh->prepare('insert into rendered_images (imagekey, variant, align, image) values (?, ?, ?, ?)');
		$sth->execute($math, $variant, $align, $image);
		$sth->finish();
	}
	
	# remove the rendering directory
	#
	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";
	`rm -rf $dir`;

	return 0;	# return success
}

# the low-level interface to LaTeX rendering methods
#
sub renderLaTeX {
	my $table = shift;
	my $id = shift;
	my $latex = shift;
	my $method = shift;
	my $fname = shift;
	
	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";

	if (not defined($table) or $table eq '.') {
		$table = "temp";
		$id =~ /\/(.*)$/;
		$id = $1;
	}
	
	my $path = getConfig('cache_root');
	my $dir = "$path/$table/$id";

	if (not defined($fname)) {
		dwarn "had to use default name when rendering object $id!\n";
		$fname = "obj";								 # generic name
	}

	my $cwd = getcwd();
#	my $cwd = `pwd`;
	
	# make sure the object directory is there & clean
	#
	if ( ! -e $dir ) {
		mkdir $dir;
	}
	chdir $dir;

	# make sure output method dir is there
	#
	$dir = "$dir/$method";
	if ( ! -e $dir ) {
		mkdir $dir;
	}
	chdir $dir;

	# get web URL for rendered images
	#
	my $url = getConfig('cache_url')."/$table/$id/$method";

	# BB: convert UTF8 international characters to TeX
	$latex = UTF8toTeX($latex);

	# flat png image output (nicest looking)
	#
	if ( $method eq "png" ) {

		$latex = png_preprocess($latex);
	
		my $retval = latex_error_check($fname, $latex);

		if (!$retval) {

			write_out_latex($fname, $latex);
			
			# main meat of rendering
			render_png($fname, $latex, $url);
		}

		else {
			write_error_output($fname, $table, $id, $method);
		}
	}
	
	# latex2html output (best-looking for the [download] speed)
	#
	elsif ( $method eq "l2h" ) {

		my $retval = latex_error_check($fname, $latex);

		if (!$retval) {
			
			write_out_latex($fname, $latex);

			# l2h rendering core
			render_l2h($fname, $latex, $url);
		} 
		
		else {
			write_error_output($fname, $table, $id, $method);
		}
	}

	# source output ... just make HTML presentable and print to output file
	#
	elsif ( $method eq "src" ) {
		write_out_latex($fname, $latex);

		system("rm .$fname.tex.swp");	# just in case vim crashed before

		$ENV{'TERM'} = "xterm";

		system(getConfig('vimcmd')." $dir/$fname.tex".' +:so\ \\'.getConfig('stemplate_path').'/2pmhtml.vim +:w\!\ '.getConfig('rendering_output_file').' +:q +:q 2>/dev/null');
	
	}

# APK - insecure, can we do without?
#	chdir $cwd;
}

# do a non-fonts render just to check syntax of LaTeX
#
sub latex_error_check {
	my $fname = shift;
	my $latex = shift;

	# add in syntax-only package and enactment directive
	#
	$latex =~ s/(\\documentclass.*?\n)/$1\\usepackage{syntonly}\n/so;
	$latex =~ s/(\\begin{document}.*?\n)/\\syntaxonly\n$1/so;

	# BB: convert UTF8 international characters to TeX
	$latex = UTF8toTeX($latex);

	write_out_latex($fname, $latex);

	# run with easily-parsable line-error option
	#
	my $retval = system("/usr/bin/latex -file-line-error-style $fname.tex");

	return $retval;
}

# latex2html rendering core
#
sub render_l2h {
	my $fname = shift;
	my $latex = shift;
	my $url = shift;

	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";

	my $tpath = getConfig("stemplate_path");	# grab latex2html init file
	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";
	`cp $tpath/.latex2html-init .`;

	# run latex to get an aux file for refs
	#
	if ($latex =~ /\\($reruns)\W/) { 
		system("/usr/bin/latex -interaction=batchmode $fname.tex"); 
	}

	# init graphics AA flag
	$ENV{'GS_GRAPHICSAA'} = 0;

	# run l2h
	my $retval = system(getConfig('base_dir') . "/bin/latex2html ".getConfig('l2h_opts')." $fname >error.out 2>&1");

	# run latex2html again after deleting some image files if these images 
	# need to be antialiased
	#
	if ($retval == 0) {
		my @aaimages = getAAImages();
		if (scalar @aaimages) {
			# delete all of the offending image files.	when we re-render, they
			# will be the only images l2h re-processes.
			#
			foreach my $file (@aaimages) {
				unlink $file;
			}

			# turn on our graphics anti-alias flag
			$ENV{'GS_GRAPHICSAA'} = 1;

			# run l2h again (ignore retval- if there were no errors before, there
			# shouldn't be any now)
			system(getConfig('base_dir') . "/bin/latex2html ".getConfig('l2h_opts')." $fname >/dev/null 2>&1");
		}
	}
 
	# post process l2h's HTML output
	#
	postProcessL2hIndex($url);
}


# do any preprocessing on LaTeX source for png mode
#
sub png_preprocess {
	my $latex = shift;

	# make colours work right in png view
	#
	# APK - 2003-06-24: this is going to need fixing.
	#
	if ($latex =~ /\\color/) {
		$latex =~ s/(\\usepackage\{.+?\})/$1\n\\usepackage\{colordvi\}\n\\usepackage\{color\}\n/;
	}

	return $latex;
}

# do rendering for PNG method
#
sub render_png {
	my $fname = shift;
	my $latex = shift;
	my $url = shift;

	$ENV{'PATH'} = "/bin:/usr/bin:/usr/local/bin";

	# see if there are any hyperlinks.
	#
	my $haslinks = ($latex =~ /\\htmladdnormallink/);

	# run mapper to produce image map data and highlighted TeX.  this 
	# will be filename-HI.tex, which further processing will occur on.
	# 
	if ($haslinks) {
		my $mapprog = getConfig('base_dir')."/bin/map/MAP";
		system("$mapprog $fname");
	}

	my $fullname = $fname;
	if ($haslinks) {
		$fullname = "$fname-HI";
	}

	# make a dvi (run latex twice to get numberings for refs)
	#
	if ($latex =~ /\\($reruns)\W/) { 
		 system("/usr/bin/latex -interaction=batchmode $fullname.tex"); 
	}
	# final rendering run
	system("/usr/bin/latex -interaction=batchmode $fullname.tex");

	# make a postscript file
	#
	system("/usr/bin/dvips -t letter -f $fullname.dvi > $fullname.ps");

	# make a pnm 
	#
	system("/usr/bin/gs -q -dBATCH -dGraphicsAlphaBits=4 -dTextAlphaBits=4 -dNOPAUSE -sDEVICE=pnmraw -r100 -sOutputFile=$fullname%03d.pnm $fullname.ps");

	# make the output file
	#
	open HTMLFILE,">".getConfig('rendering_output_file');

	print HTMLFILE "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">\n";

	# loop through pnm output (pages)
	#
	my @pnms = <*.pnm>;
	foreach my $pnm (@pnms) {
		my $png = $pnm;
		$png =~ s/pnm$/png/;

		# get the series number
		$pnm =~ /\d(\d\d)\.pnm/;

		# TODO: MAP should use 3 digits here.
		#
		my $ord = "$1";

		# make a png 
		#
		system("/usr/bin/pnmcrop < $pnm | /usr/bin/pnmpad -white -l20 -r20 -t20 -b20 | /usr/bin/pnmtopng > $png");
	
		# add image to the output html file 
		#
		print HTMLFILE "<tr><td>";

		if ($haslinks) {
			print HTMLFILE "<img src=\"".htmlescape($url."/$png")."\" border=\"0\" usemap=\"#ImageMap".int($ord)."\"/>\n\n";
			# read in the image map and output it to the HTML file
			#
			my $map = readFile($fname."$ord.map");

			print HTMLFILE $map;

		} else { 
			my $alttext = $latex;
			if (length($latex) > 1024) {
				$alttext = "[too big for ALT]";
			}
			print HTMLFILE "<img src=\"".htmlescape($url."/$png")."\" alt=\"".qhtmlescape($alttext)."\" />\n";
		}

		print HTMLFILE "\n\n</td></tr>\n";

		# remove the pnm
		unlink $pnm;
	}

	print HTMLFILE "</table>\n";
	
	unlink "$fullname.aux";
	unlink "$fullname.pnm";
	unlink "$fullname.log";

	close HTMLFILE;
}

# write latex out to a file for rendering
#
sub write_out_latex {
	my $fname = shift;
	my $latex = shift;
	
	open OFILE,">$fname.tex";
	print OFILE $latex;
	close OFILE;
}

# get error log data
#
sub get_latex_error_data {
	my $logfile = shift;	# log file
	my $table = shift;		# path components
	my $id = shift;
	my $method = shift;

	# change to working dir
	#
	chdir(getConfig('cache_root')."/$table/$id/$method");

	# open and read log
	#
	my $log = readFile($logfile);

	my %errors;

	# scan log just for error lines; pick them out and return essential data
	#
	while ($log =~ /^\S+\.tex:(\d+):\s+(.+?)$/mgo) {
		my $line = $1;
		my $error = $2;
		
		$line -= 1;  # adjust for \usepackage{syntonly} and \syntaxonly

		$errors{$line} = $error;
	}
	
	return {%errors};
}

# "explain" a latex source file error with annotated source.
#
sub explainError {
	my $params = shift;
	my $userinf = shift;

	my $table = $params->{'from'};
	my $id = $params->{'id'};
	my $method = $params->{'method'};
	my $name = $params->{'name'};

	my $logfile = "$name.log";
	my $srcfile = "$name.tex";

    my $errors = get_latex_error_data($logfile, $table, $id, $method);

	# we'll also need to open the source file for printing
	#
	chdir(getConfig('cache_root')."/$table/$id/$method");
	open SRCFILE, $srcfile;
	my @srclines = <SRCFILE>;
	close SRCFILE;
	
	my $html = '';  # output

	$html .= "<font face=\"monospace, courier, fixed\">\n";

	for (my $i = 0; $i < scalar @srclines; $i++) {
	
		my $line = $srclines[$i];
		chomp $line;

		if (exists $errors->{$i}) {
			$html .= "<font color=\"#ff0000\">${i}: ".$line."<br>\n";
			$html .= "<b>!!! $errors->{$i}</b></font><br>\n";
		} else {
			$html .= "${i}: ".$line."<br>\n";
		}
	}

	$html .= "</font>\n";

	return $html;
}

# write error log output to rending results file
#
sub write_error_output {
	my $name = shift;	# canonical name.
	my $table = shift;		# path components
	my $id = shift;
	my $method = shift;

	my $logfile = "$name.log";

	# get error data
	#
	my $errors = get_latex_error_data($logfile, $table, $id, $method);

	# output error data
	
	# open rendering output file, start output
	#
	open HTMLFILE,">".getConfig('rendering_output_file');
		
	print HTMLFILE "<table width=\"100%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">\n<tr><td><font size=\"+1\" color=\"#ff0000\">\n";

	print HTMLFILE "Rendering failed.  LaTeX errors: <br /><br />";

	foreach my $lnum (sort { int($a) <=> int($b) } keys %$errors) {

		print HTMLFILE "line ${lnum}: $errors->{$lnum} <br />";
	}
	
	my $root = getConfig('main_url');

	print HTMLFILE "</font></td></tr>
	
	<tr>
		<td align=\"center\">
			<font size=\"-1\">
				<br />
	 			(<a href=\"$root/?op=explain_err&amp;name=$name&amp;from=$table&amp;id=$id&amp;method=$method\" target=\"_pm_err_win\">view source annotated with errors</a>)
			</font>
		</td>
	</tr>
	</table>\n";

	close HTMLFILE;
}

# determine if there was a rendering error, based on return value of latex
# command, and log output. we can't just use return value, since warnings
# and errors aren't distinguished.
#
sub renderError {
	my $retval = shift;
	my $logfile = shift;

	# open and read log
	#
	my $log = readFile($logfile);

	# if no error or warning, we're ok
	#
	return 0 if $retval == 0;

	# separate errors from warnings
	#
	if ($log =~ /^! /m) {
		return 1;
	}
	
	return 0;
}

# get file names of (included graphics) images to be anti-aliased. 
#
sub getAAImages {
	
	my @imgfiles = ();

	# we use the images.pl file l2h produces (should be in the current dir.)
	do "images.pl";

	foreach my $key (keys %cached_env_img) {
		# look for tell-tale signs of things we should antialias
		#
		if ($key =~ /(includegraphics|figura)/) {
			my $val = $cached_env_img{$key};
			$val =~ /SRC="(.+)?"/;
			my $imgfile = $1;
			
			dwarn "*** getAAImages : graphics-antialiasing $imgfile";
			
			push @imgfiles, $imgfile;
		}

		delete $cached_env_img{$key};	# clear all entries
	}

	return @imgfiles;
}

# process latex2html generated index.html file to produce just the html 
# Noosphere needs to include in pages.	Writes this output to the rendering
# output file.
# 
sub postProcessL2hIndex {
	my $url = shift;

	my $path = getConfig('cache_root');

	# just write the latex2html to the rendering output 
	# file, with some minor post-processing
	#
	my $file = '';

	# read output of l2h, running it through tidy to get XHTML
	#
	$file = readFile(getConfig('tidycmd')." -wrap 1024 -numeric -asxml index.html 2>/dev/null |");
	
	# pull out just the body, clean some stuff up
	#
	$file =~ /<body.*?>(.*?)<hr\s*?\/>\s*?<\/body>/sio;
	$file = $1;
	$file =~ s/src=\s*\"(.*?)\"/src=\"$url\/$1\"/igso;
	
	# add title tooltips
	$file =~ s/(alt="(.+?)")/$1 title="$2" /igso;
	$file = "<table border=\"0\" width=\"100%\"><td>$file</td></table>";
	
	# make HREFs to local anchors non-absolute
	$file =~ s/href=\s*"[^"]+#/href="#/igso;

	# write it out to standard location
	#
	open OUTFILE,">".getConfig('rendering_output_file');
	print OUTFILE "$file";
	close OUTFILE;
	
=quote
	# something went wrong, replace rendering output file with the contents of 
	# error.out, with some minor post-processing (pull out just error section)
	#
	else {
		$file = readFile("error.out");
		$file =~ s/^.*?(\*\*\* Error:)/$1/gs;
		$file =~ s/Died at.+$//gs;
		$file =~ s/\n+/\n/gs;
	
		my $newfile = $file;
		while ($file =~ /<<([0-9]+)>>/gs) {
			my $num = $1;
			$newfile =~ s/<<$num>>(.*?)<<$num>>/{$1}/gs;
		}
		$file = $newfile;
		$file = tohtmlascii($file);
		$file =~ s/\n/<br \/>/gs;
		$file = "<table border=\"0\" width=\"100%\"><tr><td><font color=\"#ff0000\"><b>$file</b></font></td></tr></table>";
	}
=cut
}

# write reference links to a file in the rendering output dir
#
sub writeLinksToFile {
	my ($table,$id,$method,$links) = @_;

	my $path = getConfig('cache_root');
	my $dir = "$path/$table/$id/$method";

	open OUTFILE,">$dir/pmlinks.html";
	print OUTFILE "$links";
	close OUTFILE;
}

# this sub grabs the contents of cacheroot/table/objid/method/pmlinks.html file
#
sub getRenderedObjectLinks {
	my ($table,$id,$method) = @_;
	
	my $path = getConfig('cache_root');
	my $dir = "$path/$table/$id/$method";
	
	return readFile("$dir/pmlinks.html");
}

# this sub grabs the contents of the cacheroot/objid/method/output.html file
# no checking on existence is done (where output.html is the rendering output
# file)
#
sub getRenderedObjectHtml {
	my ($table, $id, $method) = @_;
	
	my $path = getConfig('cache_root');
	my $dir = "$path/$table/$id/$method";
	
	my $html = readFile("$dir/".getConfig('rendering_output_file'));

	return $html;
}

# split out, process pseudo-LaTeX linking commands
#
sub splitPseudoLaTeX {
	my $domain = shift; #this is domain as text
	my $text = shift;
	my $method = shift; #BB: should we protect URLs?

	my @escaped = ();
	my @linkids = (); # list of ids to manually link
	my $eidx = 0;

	# crossreference escaping
	#
	# \PMlinkescapetext{four score and seven years} 
	while ($text =~ s/\\PMlinkescapetext\{(.+?)\}/\@\@$eidx\@\@/s) {
		push @escaped,$1;
		$eidx++;
	}
	# {\PMlinkescapetext four score adn seven years}
	while ($text =~ s/\{\\PMlinkescapetext\s(.+?)\}/\@\@$eidx\@\@/s) {
		push @escaped,$1;
		$eidx++;
	}

	# crossreference forcing 
	#
	while ($text =~ s/\\PMlinktofile\{(.+?)\}\{(.+?)\}/\@\@$eidx\@\@/s) {
		push @escaped,"\\PMlinktofile{$1}{$2}";	# preserve these commands
		$eidx++;
	}
	#BB: protect URL unless we are in l2h mode because l2h protects URLs
	while ($text =~ s/\\PMlinkexternal\{(.+?)\}\{(.+?)\}/\@\@$eidx\@\@/s) {
		push @escaped,"\\htmladdnormallink{".protectAnchor($1)."}{".(($method eq 'l2h')?$2:protectURL($2))."}";
		$eidx++;
	}
	while ($text =~ /\\PMlinkid\{(.+?)\}\{(.+?)\}/so) {
		my $anchor = $1;
		my $id = $2;
		if (objectExistsById($id)) {
			push @escaped,"\\htmladdnormallink{$anchor}{". getDomainConfig($domain, 'urltemplate') . "$id.html}";
			$text =~ s/\\PMlinkid\{.+?\}\{.+?\}/\@\@$eidx\@\@/s;
			push @linkids, $id;
		} else {	# failed to resolve target
			push @escaped,$anchor;
			$text =~ s/\\PMlinkid\{.+?\}\{.+?\}/\@\@$eidx\@\@/s;
		}
		$eidx++;
	}
	
	#we are lazy with this and just assume that since PMlinkname is for planetmath we just automatically link
	# to planetmath.org
	while ($text =~ /\\PMlinkname\{(.+?)\}\{(.+?)\}/so) {
    	my $anchor = $1;
    	my $name = $2;
    	my $id = 0;
        #my $id = objectExistsByName($name);
        #if ($id) {
        	push @escaped,"\\htmladdnormallink{$anchor}{".protectURL("planetmath.org")."/encyclopedia/$name.html}";
            push @linkids, $id;
        #} else {        # failed to resolve target
        #	push @escaped,$anchor;
        #}
       	$text =~ s/\\PMlinkname\{.+?\}\{.+?\}/\@\@$eidx\@\@/so;
        $eidx++;
	}



	return ($text, [@escaped], [@linkids]);
}

# split LaTeX into math and text, with ##N## anchors where the math used to be.
# now also removes escaped text portions
# 
sub splitLaTeX {
	my $text = shift;
	my $escaped = shift;

	my @math = ();

	# APK - these spaces will remove worries about some boundary conditions
	# so that the regexps in this sub work (as in when the entry starts or
	# ends with some math).
	#
	$text = " $text ";
	
	if (not defined $escaped) {
		$escaped = [()];
	}

	my $midx = 0;
	my $eidx = scalar @$escaped;

	$text = fragmentpseudos($text);

	# rendered math escaping
	#
	# Moved Lalgorithm handling to top, as these environments tend to contain inlined math -LBH
	while ($text =~ s/(\\begin\{.+algorithm\}.+?\\end\{.+algorithm\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	while ($text =~ s/(\\\[.+?\\\])/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	# changed .+ to .* because the [^\\] is required to match	-LBH
	while ($text =~ s/([^\\])(\$\$.*?[^\\]\$\$)/$1##$midx##/s) {
		push @math,$2;
		$midx++;
	}
	# changed .+ to .* ...	-LBH
	while ($text =~ s/([^\\])(\$.*?[^\\]\$)/$1##$midx##/s) {
		push @math,$2;
		$midx++;
	}
	while ($text =~ s/(\\begin\{eqnarray[*]{0,1}\}.+?\\end\{eqnarray[*]{0,1}\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	while ($text =~ s/(\\begin\{displaymath\}.+?\\end\{displaymath\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	while ($text =~ s/(\\begin\{math\}.+?\\end\{math\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	while ($text =~ s/(\\begin\{equation[*]{0,1}\}.+?\\end\{equation[*]{0,1}\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}
	while ($text =~ s/(\\begin\{align[*]{0,1}\}.+?\\end\{align[*]{0,1}\})/##$midx##/s) {
		push @math,$1;
		$midx++;
	}

	# pull out bibliography section
	#
	if ($text =~ s/((\\begin\{\s*thebibliography\s*\}|\\(paragraph|section|textbf)\{\s*Reference.*?\}|\{\\bf\s+Reference.*?\}|\\(paragraph|section|textbf)\{\s*Further\s+Reading.*?\}|\{\\bf\s+Further\s+Reading.*?\}).+)$/\@\@$eidx\@\@/s) {
		#dwarn "link escaping biblio [$1]";
		push @$escaped,$1;
		$eidx++;
	}

	# escape quoted text
	#
	# APK - removed escaping of ".+?" ... this was bad... ended up escaping
	# consecutive instances of \" in words.
	while ($text =~ s/(``.+?'')/\@\@$eidx\@\@/s) {
		push @$escaped,"$1";
		$eidx++;
	}

	# escape everything not in the whitelist
	#
#	while ($text =~ /(\\(\w+)[*]?(?:\[.+?\])?(?:\{.+?\})?)/sgo) {
	while ($text =~ /(\\(\w+)[*]?(?:\[.+?\])?(?:(\{.+?\})*)?)/sgo) {
		my $cmd = $2;
		my $tag = $1;

	#	print "cmd = $cmd  tag = $tag \n";

		#dwarn "*** splitLaTeX : checking tag [$tag]";
	
		# if not in the whitelist, kill the whole command
		#
		if (not (exists $VISIBLETAGS{$cmd} || exists $LINKTAGS{$cmd})) {
			#dwarn "*** splitLaTeX : not in whitelist, escaping [$tag]";
			$text =~ s/\Q$tag\E/\@\@$eidx\@\@/s;
			push @$escaped, $tag; 
			$eidx++;
		}

		# just kill the tag
		# 
		else {
			$text =~ s/\\$cmd/\@\@$eidx\@\@/s;
			push @$escaped, "\\$cmd";
			$eidx++;
		}
	}
	
	return $text,[@math];
}

# pre-preprocessing hacks to make l2h output look right
#
sub l2hhacks {
	my $latex = shift;

	# paragraphs
	#
	$latex =~ s/\r//gs;
	# 2003-05-29 : hack apparently no longer needed
	#$latex =~ s/(\n\n)/$1\\begin\{rawhtml\}<p>\\end\{rawhtml\}\n\n/sg;

	# xypic double-height fix
	#
	$latex =~ s/(\$\$)\s*(\\xymatrix\s*?\{.+?\})\s*?(\$\$)/$1\\begin{xy}\n*!C\\xybox\{\n$2 \}\\end\{xy\}$3/gs;
	# this next hack probably should be rethought.
	$latex =~ s/(\\begin\{center\})(\s*?)(\\xymatrix\s*?\{.+?\})\s*?(\\end\{center\})/\\begin\{rawhtml\}<div align="center">\\end\{rawhtml\}$2\\begin{xy}\n*!C\\xybox\{\n$3 \}\\end\{xy\}\n\\begin\{rawhtml\}<\/div>\\end\{rawhtml\}/gs;
	$latex =~ s/(\\\[)\s*(\\xymatrix\s*?\{.+?\})\s*?(\\\])/$1\\begin{xy}\n*!C\\xybox\{\n$2 \}\\end\{xy\}$3/gs;
	$latex =~ s/(\\begin\{displaymath\})\s*(\\xymatrix\s*?\{.+?\})\s*?(\\end\{displaymath\})/$1\\begin{xy}\n*!C\\xybox\{\n$2 \}\\end\{xy\}$3/gs;

	return $latex;
}

# preprocessing to do before xreffing
#
# all the spacing is done to make the "list of words" and chained-hash 
# concept index stuff work.
#
# we would be able to get rid of this if we had some "real" parsing; then 
# we could just walk a document tree later.
#
sub preprocessLaTeX {
	my $text = shift;

	# remove comments
	#
	$text =~ s/^\s*[%].*?$//gm;

	# tilde to special char
	#
	$text =~ s/([^\s])~([^\s])/$1 __TILDE__ $2/sg;

	# space punctuation out from the ends of words. that is, make them separate 
	# words.
	$text =~ s/([\w\}])([;.,):\?\!])/$1 __SPACER__ $2/sg;

	# space out punctuation from the beginning of words
	$text =~ s/([(])([\w\\])/$1 __SPACER__ $2/sg;

	# space out footnotes
	$text =~ s/(\w)(\\footnote)/$1 $2/sg;
	$text =~ s/(\\footnote\{)(\w)/$1 $2/sg;

	# space attribs and braces out
	#
	$text =~ s/(\\emph\{|\\textbf\{)(\w)/$1 __SPACER__ $2/sg;
	$text =~ s/(\\emph\{|\\textbf\{|\{\\it|\{\\bf|\{\\em)(.+?)(\})/$1$2 __SPACER__ $3/gs;
	
	# space out \\ linebreaks
	#
	$text =~ s/(\w)\\\\/$1 __SPACER__ \\\\/sg;

	# preserve newlines - this is important for LaTeX
	#
	$text =~ s/\n/ __NL__ /gs;
	$text =~ s/\r/ __CR__ /gs;

	return $text;
}

# post-xreffing processing
#
sub postprocessLaTeX {
	my $text = shift;

	# remove spaces added earlier
	$text =~ s/\s*__SPACER__\s*//gs;

#	$text =~ s/([\w\}]) ([;.,):\?\'\!])/$1$2/sg;
#	$text =~ s/([(\`]) ([\w\\])/$1$2/sg;
#	$text =~ s/(\w) (\})/$1$2/sg;
#	$text =~ s/(\w) (\\footnote)/$1$2/sg;

	# remove tilde thingie
	$text =~ s/\s*__TILDE__\s*/~/sg;

	# put back CR and NL
	$text =~ s/\s*__NL__\s*/\n/sg;
	$text =~ s/\s*__CR__\s*/\r/sg;

	return $text;
}
	

# get phrases/word to escape
#
sub getEscapedWords {
	my $text = shift;

	my @list = ();
	
	# \PMlinkescapeword{word or phrase}
	while ($text =~ /\\PMlinkescapeword\{(.+?)\}/) {
		my $phrase = $1;
		$text =~ s/\\PMlinkescapeword\{\Q$phrase\E\}//gs;
		push @list,$phrase;
	}
	
	# \PMlinkescapephrase{word or phrase}
	while ($text =~ /\\PMlinkescapephrase\{(.+?)\}/) {
		my $phrase = $1;
		$text =~ s/\\PMlinkescapephrase\{\Q$phrase\E\}//gs;
		push @list,$phrase;
	}

	return ($text,@list);
}

# go through $text and escape all occurrences of a phrase (that is, put them
# in a list with stable order and replace them with an anchor in the text)
#
sub escapephrase {
	my $text = shift;
	my $phrase = shift;
	my $eidx = shift;
	my $list = shift;
	
	my $found = 0;
	do {
		$found = 0;
		if ($text =~ /\b(\Q$phrase\E)\b/) {
		$found = 1;
		push @$list,$1;
		$text =~ s/\b\Q$phrase\E\b/\@\@$eidx\@\@/s;
		$eidx++;
	}
	} while ($found == 1);

	return ($text,$eidx);
}

# recombine a math list and LaTeX with math anchors
#
sub recombine {
	my $text = shift;
	my $mathlist = shift;
	my $esclist = shift;
 
	# note that this HAS to be done in this order: escaped items
	# can contain math.
	#
	# APK - also, escaped items can be nested
	#
	while ($text=~s/\@\@([0-9]+)\@\@/$esclist->[$1]/s) { 1; };
	#foreach my $escitem (@$esclist) {
	#	$text=~s/\@\@$idx\@\@/$escitem/s;
	#	$idx++;
	#}
	while ($text=~s/##([0-9]+)##/$mathlist->[$1]/s) { 1; };
	#foreach my $mathitem (@$mathlist) {
	#	$text =~ s/##$idx##/$mathitem/s;
	#	$idx++;
	#}

	return $text;
}
	
1;
