#!/usr/bin/perl
#applies to fhist files
(@line = split("\\.","$ARGV[0]"));
$filetype = $line[-1];
open FILTERS, "/Users/dansisan/logfile/filters.txt" or die $!;
open INFILE, "$ARGV[0]";
open OUTFILE, ">$ARGV[0].proc" or die $!;

my %filterlook = ();

	while( $isline = @line = (split(';',<FILTERS>))) {
		chomp(@line);
		for($i=0;$i<$isline;$i++){ 
			$filterlook{$line[0]}[$i]= $line[$i+1];
		}
		$recipelook{trim($line[4])}= trim($line[3]);
	}
	
close FILTERS;

if($filetype eq "fhist"){#fhist
	while( $isline = @line = (split(',',<INFILE>))) {
		chomp(@line);	
		push(@line,$filterlook{$line[0]}[2]); #add recipe name
		push(@line,$filterlook{$line[0]}[1]); #add review count for filter 
		if($filterlook{$line[0]}[0]){
			$line[0]=$filterlook{$line[0]}[0];#replace filter id with name		
		}
		print OUTFILE join(";",@line), "\n";
	}
 } elsif ($filetype eq "iphist"){ #for iphist files
	
}

close OUTFILE;
close INFILE;	

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
	