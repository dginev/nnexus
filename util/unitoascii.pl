#This script will convert a file in utf8 format to ascii format.
# Beware: you can lose some characters in the file being converted

use Unicode::String qw(latin1 utf8 utf16);
#trings to latin1 strings
#


open(FILE, $ARGV[0]);

my $input = "";
while(<FILE>){

	$input .= $_;

}

my $s = UTF8ToLatin1($input);

print $s;


sub UTF8ToLatin1 {
        my $string = shift;

        return utf8($string)->latin1;
}

