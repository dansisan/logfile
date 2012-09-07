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

open OUTFILE, ">$filenames[0].combo2.reviews" or die $!;
open IPHISTFILE, ">$filenames[0].combo.iphist" or die $!;
open RECIPEFILE, ">$filenames[0].combo.rhist" or die $!;
open FILTERFILE, ">$filenames[0].combo.fhist" or die $!;
open VISITORFILE, ">$filenames[0].combo.vhist" or die $!;

my %iphist = ();
my %recipehist = ();
my %filterhist = ();
my %visitorhist = ();
my %monthlook = ("Jan","01","Feb","02","Mar","03","Apr","04","May","05","Jun","06","Jul","07","Aug","08","Sep","09","Oct","10","Nov","11","Dec","12"); 
$i = 0;

@times =[];
@lines =[];
for ($file=0; $file< ($flength = @filehandles); $file++) {#initial load of times
	while(($line = readline $filehandles[$file]) !~ m/getReviews/ || !$line){;} 
		my ($date) = ($line =~ m/\[(.*)-0400\]/);
		my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
		my $time = timegm($sec,$min,$hour,$day,$monthlook{$month}-1,$year);
		$times[$file] = $time;
		$lines[$file] = $line;
	
}
# $i< 500 && 
$messed=0;

	while( $line ) {
	  %minTime = getMin(@times); #get earliest time from across logfiles
	  $whichFile = $minTime{"index"};
	  $line = $lines[$minTime{"index"}]; #load the earliest time file into $line
	  if( $line =~ m/getReviews/){ 
		$i++;
		my ($date) = ($line =~ m/\[(.*)-0400\]/);
		my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
		my $time = timegm($sec,$min,$hour,$day,$monthlook{$month}-1,$year);
		#can't do one long regex b/c order of query params in api call is not consistent
		#([a-zA-Z0-9\/\.:\"\?=&,\_%-]+)
		#my ($ip, $recipe, $filter, $offset, $url) = ($line =~ m/[0-9\.]+ *([0-9\.]+).*getReviews.jsp\?ffid=([0-9]+)&filterid=([0-9a-z-]+).*&offset=([0-9]+) HTTP\/1\.1\" \d+ \d+ \d+ \"(.*)\"/); 		
		my ($ip) = ($line =~ m/[0-9\.]+ *([0-9\.]+)/);
		my ($recipe) = ($line =~ m/ffid=([0-9]+)/);
		my ($filter) = ($line =~ m/filterid=([0-9a-z-]+)/);
		my ($offset) = ($line =~ m/offset=([0-9]+)/); 		 		
		my ($url) = ($line =~ m/HTTP\/1\.1\" \d+ \d+ \d+ \"([^\"]*)\"/); 		
		$iponly=$ip;
		$ip=$ip.'-'.$recipe; #make ip key have recipe
		if(($st=$iphist{$ip}{'last'}) && ($diff=$time-$iphist{$ip}{'last'})>1800 ){#if too long since last action, start new visit
			#clone data to another key w/ timestamp in ip and delete old
			$iphist{$ip .'#'.$st}{'start'}=$iphist{$ip}{'start'};
			$iphist{$ip .'#'.$st}{'engaged-start'}=$iphist{$ip}{'engaged-start'};		delete $iphist{$ip}{'engaged-start'};
			$iphist{$ip .'#'.$st}{'count'}=$iphist{$ip}{'count'};		delete $iphist{$ip}{'count'};
			$iphist{$ip .'#'.$st}{'end'}=$iphist{$ip}{'end'};			delete $iphist{$ip}{'end'};
			$iphist{$ip .'#'.$st}{'filters'}=$iphist{$ip}{'filters'};	delete $iphist{$ip}{'filters'};
			$iphist{$ip .'#'.$st}{'fcount'}=$iphist{$ip}{'fcount'};		delete $iphist{$ip}{'fcount'};			
			delete $iphist{$ip}{'last'}; 
		}
		$iphist{$ip}{'count'}++;
		$visitorhist{$iponly}{'count'}++;
		@filts = (split(',',$iphist{$ip}{'filters'}));
		$lastFilter = $filts[-1];
		$numFilter =  @filts;

		$iphist{$ip}{'last'}=$time;
		#if($lastFilter == $filter && $offset == 0){$iphist{$ip}{'count'}--;} #discount page reloads, double filter clicks
		if($lastFilter eq ''){#if initial load
			$iphist{$ip}{'start'}=$time;
			$offset='';
			$recipehist{$recipe}{'first'}++;			
		} elsif ($iphist{$ip}{'count'} ==2 && ($lastFilter ne $filter || $offset > 0)){			
			$iphist{$ip}{'engaged-start'}=$time; #if engaged set engaged time
			$recipehist{$recipe}{'engaged'}++;
		} elsif ($iphist{$ip}{'count'} >1 && $lastFilter eq $filter && $numFilter == 1 && $offset == 0){
			$recipehist{$recipe}{'reload'}++;
			$offset='';
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
		$deltatime=0;
		if($iphist{$ip}{'engaged-start'}){$deltatime = $iphist{$ip}{'end'} - $iphist{$ip}{'engaged-start'};}
		if($url =~ m/recipe\/index\.html/ ){$urlflag = "recipe";}
			elsif ($url =~ m/review/) {$urlflag = "review";}
			elsif ($url =~ m/\-/){$urlflag="-";}
		($qparam)=($url =~ m/\?(.{0,10})/); 
		$monthd=$monthlook{$month};
		print  OUTFILE "$time,$iponly,$recipe,$filter,$offset,$year-$monthd-$day,$deltatime,$urlflag,$qparam\n";
	  }	#if
#	    if(($line = readline $filehandles[$minTime{"index"}])){ 		
		while(($line = readline $filehandles[$minTime{"index"}]) !~ m/getReviews/ && $line){;}
	    if($line){ 	
			my ($date) = ($line =~ m/\[(.*)-0400\]/);
			my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
			my $time = timegm($sec,$min,$hour,$day,$monthlook{$month}-1,$year);
			$times[$minTime{"index"}] = $time;
			$lines[$minTime{"index"}] = $line;
		}	
		
	} #while
	

close(OUTFILE);
print "Finished file processing.\n";

for my $key (sort {$iphist{$b}{'count'} <=> $iphist{$a}{'count'} } keys %iphist) { 
		$deltatime=0;
		if($iphist{$key}{'engaged-start'}){$deltatime = $iphist{$key}{'end'} - $iphist{$key}{'engaged-start'};}
       print IPHISTFILE "$key, $iphist{$key}{'count'},$deltatime, $iphist{$key}{'fcount'}, $iphist{$key}{'filters'} \n";
   }
close(IPHISTFILE);


for my $key ( sort {$recipehist{$b}{'first'} <=> $recipehist{$a}{'first'}} keys %recipehist ) {
       my $value = $recipehist{$key}{'count'};
       print RECIPEFILE "$key, $recipehist{$key}{'first'}, $recipehist{$key}{'engaged'}, $recipehist{$key}{'reload'}, $recipehist{$key}{'other'}, $recipehist{$key}{'fcount'}, $recipehist{$key}{'filters'} \n";
   }
close(RECIPEFILE);


for my $key ( sort {$filterhist{$b}{'click'} <=> $filterhist{$a}{'click'}} keys %filterhist ) {
   #    my $value = $filterhist{$key}{'count'};
       print FILTERFILE "$key, $filterhist{$key}{'click'}, $filterhist{$key}{'count'} \n";
   }
close(FILTERFILE);

for my $key ( sort {$visitorhist{$b}{'count'} <=> $visitorhist{$a}{'count'}} keys %visitorhist ) {
       print VISITORFILE "$key, $visitorhist{$key}{'count'} \n";
   }

close(VISITORFILE);
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