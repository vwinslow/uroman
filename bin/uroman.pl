#!/usr/bin/perl -w

# uroman  Nov. 12, 2015 - Oct. 11, 2019
# Author: Ulf Hermjakob

# Usage: uroman.pl {-l [ara|bel|bul|deu|ell|eng|fas|grc|heb|kaz|kir|lav|lit|mkd|mkd2|oss|pnt|rus|srp|srp2|tur|uig|ukr|yid]} {--chart|--offset-mapping} {--no-cache} {--workset} < STDIN
# Example: cat workset.txt | uroman.pl --offset-mapping --workset

#use Mojolicious::Lite;
#use Mojo::JSON;
use Dancer2;
no strict;
no warnings;
$|=1;

use FindBin;
use Cwd "abs_path";
#use File::Basename qw(dirname);
use File::Spec;
use lib "$FindBin::Bin/../lib";
use NLP::Chinese;
use NLP::Romanizer;
use NLP::UTF8;
use NLP::utilities;
#use JSON;
use Encode;

post '/' => sub {
    #print "-------------------\n";
	my $self = shift;
    my $json = request->body;
	#print "json received is: " . $json . "\n";
	@res = @{from_json($json)};
	print "received request with " . scalar @res . " entries\n";
	#print "json as list is : " . "@res\n";
	@romanized = romanizeText(@res);
	#print "Romanized result is: " . "@romanized\n";
	send_as JSON => { "romanized" =>  [@romanized] } ;
};
my %hash;
open my $fh, '<', 'data/replacement.csv' or die "Cannot open: $!";
while (my $line = <$fh>) {
	$line =~ s/\s*\z//;
	my @array = split /,/, $line;
	my $key = lc shift @array;
	$hash{$key} = lc shift @array;
}
close $fh;
start;
sub romanizeText {
	my $bin_dir = abs_path(dirname($0));
	my $root_dir = File::Spec->catfile($bin_dir, File::Spec->updir());
	my $data_dir = File::Spec->catfile($root_dir, "data");
	my $lib_dir = File::Spec->catfile($root_dir, "lib");

	$chinesePM = NLP::Chinese;
	$romanizer = NLP::Romanizer;
	$util = NLP::utilities;
	$utf8 = NLP::UTF8;
	%ht = ();
	%pinyin_ht = ();
	$lang_code = "uig";
	$return_chart_p = 0;
	$return_offset_mappings_p = 0;
	$workset_p = 0;
	$cache_rom_tokens_p = 1;
	$script_data_filename = File::Spec->catfile($data_dir, "Scripts.txt");
	$unicode_data_filename = File::Spec->catfile($data_dir, "UnicodeData.txt");
	$unicode_data_overwrite_filename = File::Spec->catfile($data_dir, "UnicodeDataOverwrite.txt");
	$romanization_table_filename = File::Spec->catfile($data_dir, "romanization-table.txt");
	$chinese_tonal_pinyin_filename = File::Spec->catfile($data_dir, "Chinese_to_Pinyin.txt");

	$romanizer->load_script_data(*ht, $script_data_filename);
	$romanizer->load_unicode_data(*ht, $unicode_data_filename);
	$romanizer->load_unicode_overwrite_romanization(*ht, $unicode_data_overwrite_filename);
	$romanizer->load_romanization_table(*ht, $romanization_table_filename);
	$chinese_to_pinyin_not_yet_loaded_p = 1;
	my @lines = @_;
	#print "Func received lines: " . "@lines\n";
	#print "lines length: ";
	#print 0+@lines;
	#print "\n";
	@result = ();
	$resultString;
	$line_number = 0;
	foreach (@lines) {
	   my $line = @lines[$line_number];
	   $line = encode_utf8($line); 
	   #print "line is : " . $line . "\n";
	   $line_number++;
	   my $snt_id = "";
	   if ($workset_p) {
		  next if $line =~ /^#/;
		  if (($i_value, $s_value) = ($line =~ /^(\S+\.\d+)\s(.*)$/)) {
		 $snt_id = $i_value;
		 $line = "$s_value\n";
		  } else {
		 next;
		  }
	   }
	   if ($chinese_to_pinyin_not_yet_loaded_p && $chinesePM->string_contains_utf8_cjk_unified_ideograph_p($line)) {
		  $chinesePM->read_chinese_tonal_pinyin_files(*pinyin_ht, $chinese_tonal_pinyin_filename);
		  $chinese_to_pinyin_not_yet_loaded_p = 0;
	   }
	   if ($return_chart_p) {
		  $resultString .= $chart_result;
		  *chart_ht = $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "return chart", $line_number);
		  $chart_result = $romanizer->chart_to_json_romanization_elements(0, $chart_ht{N_CHARS}, *chart_ht, $line_number);
	   } elsif ($return_offset_mappings_p) {
		  ($best_romanization, $offset_mappings) = $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "return offset mappings", $line_number, 0);
		  $resultString .= "::snt-id $snt_id\n" if $workset_p;
		  $resultString .= "::orig $line";
		  $resultString .= "::rom $best_romanization\n";
		  $resultString .= "::align $offset_mappings\n\n";
	   } elsif ($cache_rom_tokens_p) {
		  $resultString .= $romanizer->romanize_by_token_with_caching($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number);
	   } else {
		  $resultString .=$romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number);
	   }
	my @names = split /[^\w]/, $resultString;
	foreach $name (@names) {
		#print "Checking if " . $name . " exists\n";
		if (exists($hash{$name})) {
			$name = $hash{$name};
			#print "Replaced " . $name . "\n";
		}
	}
	$resultString = join(" ", @names);
	push @result, $resultString;
	$resultString = "";
   }
   return @result;
}
