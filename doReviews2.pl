#!/usr/bin/perl
use Time::Local;

$ARGV[0] or die $!;
@filenames=  split(' ',$ARGV[0]);
my @filehandles;
foreach $el (@filenames){#create filehandles and load in array
	local *FILE;
	open(FILE, "$el") or die $!;
 	push(@filehandles, *FILE);
	print "File: $el \n";	
}

open OUTFILE, ">$filenames[0].combo.reviews" or die $!;
open IPHISTFILE, ">$filenames[0].combo.iphist" or die $!;
open RECIPEFILE, ">$filenames[0].combo.rhist" or die $!;
open FILTERFILE, ">$filenames[0].combo.fhist" or die $!;

my %iphist = ();
my %recipehist = ();
my %filterhist = ();
$i = 0;

@times =[];
@lines =[];
for ($file=0; $file< ($flength = @filehandles); $file++) {#initial load of times
	while(($line = readline $filehandles[$file]) !~ m/getReviews/ || !$line){;} 
		my ($date) = ($line =~ m/\[(.*)-0400\]/);
		my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
		my $time = timegm($sec,$min,$hour,$day,$mon,$year);
		$times[$file] = $time;
		$lines[$file] = $line;
	
}
# $i< 500 && 
$messed=0;

	while( $line ) {
	  %minTime = getMin(@times); #get earliest time
	  $whichFile = $minTime{"index"};
	  $line = $lines[$minTime{"index"}]; #load the earliest time file into $line
	  if( $line =~ m/getReviews/){ 
		$i++;
		my ($date) = ($line =~ m/\[(.*)-0400\]/);
		my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
		my $time = timegm($sec,$min,$hour,$day,$mon,$year); 
		#can't do one long regex b/c order of query params in api call is not consistent
		#([a-zA-Z0-9\/\.:\"\?=&,\_%-]+)
		#my ($ip, $recipe, $filter, $offset, $url) = ($line =~ m/[0-9\.]+ *([0-9\.]+).*getReviews.jsp\?ffid=([0-9]+)&filterid=([0-9a-z-]+).*&offset=([0-9]+) HTTP\/1\.1\" \d+ \d+ \d+ \"(.*)\"/); 		
		my ($ip) = ($line =~ m/[0-9\.]+ *([0-9\.]+)/);
		my ($recipe) = ($line =~ m/ffid=([0-9]+)/);
		my ($filter) = ($line =~ m/filterid=([0-9a-z-]+)/);
		my ($offset) = ($line =~ m/offset=([0-9]+)/); 		 		
		my ($url) = ($line =~ m/HTTP\/1\.1\" \d+ \d+ \d+ \"([^\"]*)\"/); 		

		$ip=$ip.'-'.$recipe; #make ip key have recipe
		if(($st=$iphist{$ip}{'start'}) && ($diff=$time-$iphist{$ip}{'start'})>7200 ){#if too long since last visit, start new visit
			#clone data to another key w/ timestamp in ip and delete old
			$iphist{$ip .'#'.$st}{'start'}=$iphist{$ip}{'start'};
			$iphist{$ip .'#'.$st}{'count'}=$iphist{$ip}{'count'};		delete $iphist{$ip}{'count'};
			$iphist{$ip .'#'.$st}{'end'}=$iphist{$ip}{'end'};			delete $iphist{$ip}{'end'};
			$iphist{$ip .'#'.$st}{'filters'}=$iphist{$ip}{'filters'};	delete $iphist{$ip}{'filters'};
			$iphist{$ip .'#'.$st}{'fcount'}=$iphist{$ip}{'fcount'};		delete $iphist{$ip}{'fcount'};			
		}
		$iphist{$ip}{'count'}++;
		@filts = (split(',',$iphist{$ip}{'filters'}));
		$lastFilter = $filts[-1];
		$numFilter =  @filts;

		#if($lastFilter == $filter && $offset == 0){$iphist{$ip}{'count'}--;} #discount page reloads, double filter clicks
		if($lastFilter eq ''){#if initial load
			$iphist{$ip}{'start'}=$time;
			$recipehist{$recipe}{'first'}++;			
		} elsif ($iphist{$ip}{'count'} ==2 && ($lastFilter ne $filter || $offset > 0)){			
			$recipehist{$recipe}{'engaged'}++;
		} elsif ($iphist{$ip}{'count'} >1 && $lastFilter eq $filter && $numFilter == 1 && $offset == 0){
			$recipehist{$recipe}{'reload'}++;
		} else {
			$recipehist{$recipe}{'other'}++;
		}
		$filterhist{$filter}{'count'}++; 
		if($lastFilter ne $filter){#if change in filter, including first view

			if($iphist{$ip}{'count'} > 1){#don't count filter from pageload
				$filterhist{$filter}{'click'}++; #if not initial load, increment filterhist
			} 
			$iphist{$ip}{'filters'}=$iphist{$ip}{'filters'} . $filter . ',';
			if($lastFilter ne ''){
				$recipehist{$recipe}{'filters'}=$recipehist{$recipe}{'filters'} . $filter . ',';
				$recipehist{$recipe}{'fcount'}++;
			}			
			$iphist{$ip}{'fcount'}++;
		}
		$iphist{$ip}{'end'}=$time;
		print  OUTFILE "$time \t $ip  \t $recipe  \t $filter  \t $offset \t $date", $iphist{$ip}{'end'} - $iphist{$ip}{'start'}, " $url $whichFile\n";
	  }	#if
	  	while(($line = readline $filehandles[$minTime{"index"}]) !~ m/getReviews/ && $line){;}
	    if($line){ 
			print $time;
			my ($date) = ($line =~ m/\[(.*)-0400\]/);
			my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
			my $time = timegm($sec,$min,$hour,$day,$mon,$year);
			$times[$minTime{"index"}] = $time;
			$lines[$minTime{"index"}] = $line;
		}	
		
	} #while
	

close(OUTFILE);
print "Finished file processing.\n";

for my $key (sort {$iphist{$b}{'count'} <=> $iphist{$a}{'count'} } keys %iphist) { 
       my $value = $iphist{$key}{'count'};
       print IPHISTFILE "$key, $iphist{$key}{'count'}, ", $iphist{$key}{'end'} - $iphist{$key}{'start'}, ", $iphist{$key}{'fcount'}, $iphist{$key}{'filters'} \n";
   }
close(IPHISTFILE);


for my $key ( sort {$recipehist{$b}{'first'} <=> $recipehist{$a}{'first'}} keys %recipehist ) {
       my $value = $recipehist{$key}{'count'};
       print RECIPEFILE "$key, $recipehist{$key}{'first'}, $recipehist{$key}{'engaged'}, $recipehist{$key}{'reload'}, $recipehist{$key}{'other'}, $recipehist{$key}{'fcount'}, $recipehist{$key}{'filters'} \n";
   }
close(RECIPEFILE);


for my $key ( sort {$filterhist{$b}{'count'} <=> $filterhist{$a}{'count'}} keys %filterhist ) {
       my $value = $filterhist{$key}{'count'};
       print FILTERFILE "$key, $filterhist{$key}{'click'}, $filterhist{$key}{'count'} \n";
   }
close(FILTERFILE);

sub getMin {
	$min = @_[0];
	$mini = 0;
	my $n=0;
	foreach $i (@_){		
		if ($i<$min && $i != ''){
			$min = $i ;
			$mini = $n;
		}
		$n++;		
	}
	return %out = ("index", $mini, 
					"value", $min);
}