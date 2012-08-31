#!/usr/bin/perl
#this works on .reviews files, from doReviews3.pl
print (@line = split("\\.","$ARGV[0]"));
print $line[0], "hello\n @line $ARGV[0]\n";
open FILTERS, "/Users/dansisan/logfile/filters.txt" or die $!;
open INFILE, "$ARGV[0]";
open OUTFILE, ">$ARGV[0].proc" or die $!;

my %filterlook = ();
my %recipelook = ();

	while( $isline = @line = (split(';',<FILTERS>))) {
		chomp(@line);
		for($i=0;$i<$isline;$i++){ 
			$filterlook{$line[0]}[$i]= $line[$i+1];
		}
		$recipelook{trim($line[4])}= trim($line[3]);
	}
	
close FILTERS;

	while( $isline = @line = (split(',',<INFILE>))) {
		chomp(@line);
	
		push(@line,$filterlook{$line[0]}[2]); #add recipe name

		if($filterlook{$line[3]}[0]){
			$line[3]=trim($filterlook{$line[3]}[0]);#replace filter id with name		
		}

		if($recipelook{$line[2]}){
			$line[2]=$recipelook{$line[2]}."-".$line[2];#replace recipe id with name-id		
		}
		print OUTFILE join(";",@line), "\n";
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