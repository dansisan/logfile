#!/usr/bin/perl
use Time::Local;
open INFILE, $ARGV[0] or die $!;
open OUTFILE, ">$ARGV[0].reviews" or die $!;


my %iphist = ();
$i = 0;
	while($i < 50 &&  ($line = <INFILE>)) {
		
	  if($line =~ m/getReviews/){ 
		$i++;
		my ($date) = ($line =~ m/\[(.*)-0400\]/);
		my ($day, $month, $year, $hour, $min, $sec) = ($date =~ m/([0-9]+)\/(.*)\/(\d*):(\d*):(\d*):(\d*)/);
		my $time = timegm($sec,$min,$hour,$day,$mon,$year); 
		my ($ip, $recipe, $filter, $offset) = ($line =~ m/[0-9.]+ ([0-9.]+).*getReviews.jsp\?ffid=([0-9]+)&filterid=([0-9a-f-]+).*&offset=([0-9])+/); 


		if(($st=$iphist{$ip}{'start'}) && ($diff=$time-$iphist{$ip}{'start'})>7200 ){#if too long since last visit, start new visit
			#clone data to another key w/ timestamp in ip and delete old
			$iphist{$ip .'-'.$st}{'start'}=$iphist{$ip}{'start'};
			$iphist{$ip .'-'.$st}{'count'}=$iphist{$ip}{'count'};		delete $iphist{$ip}{'count'};
			$iphist{$ip .'-'.$st}{'end'}=$iphist{$ip}{'end'};			delete $iphist{$ip}{'end'};
			$iphist{$ip .'-'.$st}{'filters'}=$iphist{$ip}{'filters'};	delete $iphist{$ip}{'filters'};
			
			print $ip, ' ',$iphist{$ip .'-'.$st}{'start'}, "\n";
		}
		$iphist{$ip}{'count'}++;
		if($iphist{$ip}{'count'} == 1){
			$iphist{$ip}{'start'}=$time;			
		}
		if($tst = (split(',',$iphist{$ip}{'filters'}))[-1] != $filter){
			$iphist{$ip}{'filters'}=$iphist{$ip}{'filters'} . $filter . ',';
		}
		$iphist{$ip}{'end'}=$time;
		print  OUTFILE "$time \t $ip  \t $recipe  \t $filter  \t $offset \t $date\n";
	  }	
	}
	
close(INFILE);
close(OUTFILE);

open IPHISTFILE, ">$ARGV[0].iphist" or die $!;

for my $key (sort {$iphist{$b}{'count'} cmp $iphist{$a}{'count'} } keys %iphist) { 
#for my $key ( keys %iphist ) {
       my $value = $iphist{$key}{'count'};
       print IPHISTFILE "$key \t\t $iphist{$key}{'count'} ", $iphist{$key}{'end'} - $iphist{$key}{'start'}, " $iphist{$key}{'filters'}\n";
   }
close(IPHISTFILE);
