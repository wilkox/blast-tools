#!/usr/bin/perl

#provides useful information and tools for monitoring 
# blast searchs running locally or on the sun grid engine

#release 0.3

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

use Getopt::Long;
use Time::Local;

$USAGE = q/USAGE:
blast_progress_monitor -o <blast output file> -i <blast query multifasta>
blast_progress_monitor -s <shell script submitted to cluster>
blast_progress_monitor -u
blast_progress_monitor -f <file containing list of shell scripts>

OPTIONAL:	-c	<filename> Produce a truncated query file which includes all the sequences up to the point blast has reached but no further. Filename is optional, default is "<query file>.cuttoprogress" Useful for analysing partial output.
		-d	<filename> Produce a truncated query file as with -c, but containing all the sequences after the point blast has reached. Filename is optional, default is "<query file>.cutfromprogress" Useful for restarting inadvertently stopped blast jobs.
		-j	<job id> If the blast job is running on the Sun Grid Engine (SGE), provide the job id and the script will use qstat to retrieve the start time and estimate the time of completion. Incompatible with -s. This script must be executed on the head node for the cluster.
		-t	<start time DD-MM-YYYY-HH:MM:SS> If you are not running the job on the SGE or would prefer not to provide a job id for whatever reason, provide the time you began the search and the script will use that to estimate the completion time. Note that the start time is strictly in the format DD-MM-YYYY-HH:MM:SS, in 24-hour time. Incompatible with -s and -j.
		-u	Retrives a list of all jobs currently running on the SGE under the current username, and runs the equililant of "-s <shell script>" on each of them. Incompatible with -s, -i, -o and -f.
		-f	<filename> Reads a list of shell scripts from the provided file, and runs the equivilant of "-s <shell script>" on each. Incompatible with -s, -i, -o and -u.
		-v	<prefix> Produce a visual plot of coverage, useful for identifying missing chunks in jobs which have been split then recombined. Requires R, output in pdf to <prefix>.pdf
		-g	<prefix> Create multifasta queries out of gaps in coverage. Can only be used in conjunction with -v. Output files will be <prefix>.<range>.fasta.
		-h	<decimal> Optionally specify the threshold at which a string of contiguous query sequences without hits is called as a gap. Default is 0.02 (i.e. 2% of the total number of query sequences).

KNOWN LIMITATIONS:	Does not support shell scripts with multiple jobs, behaviour in this situation is unpredictable but will probably result in only the last job in the list being reported upon.
			Very brittle with respect to input or output files generated by concatenating multiple searches. Do this at your own risk. One warning sign that something has gone badly wrong is if the reported hitrate (% query sequences with hits) is > 100% - if this is the case, all output should be treated as invalid.
/;

GetOptions(
'o=s' => \$blastoutputfile,
'i=s' => \$blastqueryfile,
'c:s' => \$cuttofilename,
'd:s' => \$cutfromfilename,
'j=s' => \$jobid,
's=s' => \$shellscript,
't=s' => \$userstarttime,
'u' => \$autolist,
'f=s' => \$shell_scripts_file,
'v=s' => \$makePlot,
'g=s' => \$makeGaps,
'h=s' => \$gapproportion,
);

#check options, set defaults
die ("ERROR - you cannot specify both a shell script (-s) and blast input/output files (-i and -o)\n") if (defined $shellscript && (defined $blastoutputfile || defined $blastqueryfile));
die ("ERROR - you cannot specify both a shell script (-s) and a job id (-j)\n") if (defined $shellscript && defined $jobid);
die ("ERROR - you cannot specify both a start time (-t) and a shell script (-s)\n") if (defined $shellscript && defined $userstarttime);
die ("ERROR - you cannot specify both a start time (-t) and a job id (-j)\n") if (defined $userstarttime && defined $jobid);
die ("ERROR - cou cannot request the status of all jobs for the current user (-u) in conjunction with any other option\n") if $autolist && (defined $shellscript || defined $blastqueryfile || defined $blastoutputfile || defined $shell_scripts_file);
die ("ERROR - option -f is incompatible with options -u, -i, -o and -s\n") if defined $shell_scripts_file && (defined $shellscript || defined $blastqueryfile || defined $blastoutputfile || $autolist);
die ("ERROR - must provide a file containing a list of shell scripts with -f option\n") if defined $shell_scripts_file && !$shell_scripts_file;
die ("ERROR - must supply an output prefix for option -v\n") if defined $makePlot && !$makePlot;
die ("ERROR - must supply an output prefix for option -g\n") if defined $makeGaps && !$makeGaps;
die ("ERROR - -g can only be used in conjunction with -v\n") if defined $makeGaps && !$makePlot;
die ("ERROR - -h can only be used in conjunction with -g\n") if defined $gapproportion && !$makeGaps;
$gapproportion = 0.02 if !$gapproportion;

##BODY
if ($autolist) {
	@shell_scripts = &get_list_of_user_jobs;
	foreach $shellscript (@shell_scripts) {
		&readshscript;
		&make_the_output;
		}
	exit;
}

if (defined $shell_scripts_file) {
	@shell_scripts = &read_shell_scripts_file;
	foreach $shellscript (@shell_scripts) {
		&readshscript;
		&make_the_output;
		}
	exit;
}
&readshscript unless !$shellscript; #strip info from the shell script if provided
die ("$USAGE\n") if (!$blastoutputfile || !$blastqueryfile); #die with usage message if the bare minimum info is not available
&parse_start_time if defined $userstarttime; #parse the user-specified job start time if provided
&make_the_output;
exit;
##END BODY

##SUBS
sub make_the_output {

  undef $lasthit;

	print "====\n"; #begin output
	print "SHELL SCRIPT RUNNING ON SGE:\t$shellscript\n" unless !$shellscript;
	&dostats; #basic stats on progress
	&printstats; #print results
	&getstarttime if defined $jobid; #get the start time if a job id is available
	&estimateendtime if defined $jobtime; #estimate the time of completion if a jobtime is available
	&printendtime if defined $jobtime; #print the results of endtime estimation
	&cuttoprogress unless !$cuttofilename; #produce cut-to-progress file if so requested
	&cutfromprogress unless !$cutfromfilename; #produce cut-from-progress file if so requested
	&make_plot if $makePlot; #make a coverage plot if requested
	print "\n====\n"; #end output
}

sub make_plot {

	my @inputs;
	my @importantpos;

	#read in blast query list
	die ("ERROR - could not open blast query file $blastqueryfile\n") unless open(IN, "<$blastqueryfile");
	while ($line = <IN>) {
		next unless $line =~ /^>(\S+)/;
		push(@inputs, $1);
	}
	close IN;

	#read in blast output list
	die ("ERROR - could not open blast output file $blastoutputfile\n") unless open(OUT, "<$blastoutputfile");
	while ($line = <OUT>) {
		next unless $line =~ /^(\S+)\s+/;
		$outputs{$1} = "";
	}
	close OUT;

	#calculate how many reads are needed to trip the "it's a gap"
	$gapthreshold = $gapproportion * @inputs;

	#iterate through queries and note large gaps
	$i = 0;
	$gapstart = 0;
	$index = 0;
	foreach (@inputs) {
		++$index;
		if (exists $outputs{$_}) {
			if ($gaptripped == 1) {
				push(@importantpos, $gapstart) unless $index - $gapstart < $gapthreshold;
				push(@importantpos, ($index + 1)) unless $index - $gapstart < $gapthreshold;
				$gaptripped = 0;
				$i = 0;
			}
			$gapstart = $index + 1;
			next;
		}
		++$i;
		if ($i >= $gapthreshold) {
			$gaptripped = 1;
		}
	}


	#write the hitplot as a comma-separated file
	die ("ERROR - could not create temporary file at /tmp/hitmap.csv\n") unless open(PLOT, ">/tmp/hitmap.csv");
	$i = 0;
	print PLOT "index,value";
	foreach (@inputs) {
		if (exists $outputs{$_}) {
			print PLOT "\n$i,1";
		} else {
			print PLOT "\n$i,0";
		}
		++$i;
	}
	close PLOT;

	#draw the plot in R

		$R = <<EOF;
pdf("$makePlot.coverage.pdf")
hitmap = read.csv("/tmp/hitmap.csv", head=TRUE)
plot(hitmap\$index, hitmap\$value, type="n", main = c("Coverage map for $blastqueryfile"), xlab = c("Query sequences"), ylab=c(""), xlim=c(0, $i), yaxt="n", ylim=c(0,1.5))
polygon_coords = rbind(hitmap, c($i, 0), c(0,0))
polygon(polygon_coords, col=c("lightblue3"), lty=0)
EOF

		foreach (@importantpos) {
			$R .= "\ntext($_,1.1,\"$_\",srt=90)";
		}

	$R .= "\ndev.off()";

	die ("ERROR - could not create temporary R script at /tmp/drawplot.R\n") unless open(R, ">/tmp/drawplot.R");
	print R $R;
	close R;

	system("R --no-save < /tmp/drawplot.R &> /dev/null");
	system("rm /tmp/drawplot.R /tmp/hitmap.csv");

	print "\nCoverage plot created at $makePlot.coverage.pdf";

	#make gap query files if the user has asked for them
	if ($makeGaps) { 
		until (@importantpos == 0) {
			$startread = shift(@importantpos);
			$endread = shift(@importantpos);
			die ("ERROR - cannot open query file $blastqueryfile\n") unless open(QF, "<$blastqueryfile");
			die ("ERROR - cannot create gap file $makeGaps.$startread-$endread.fasta\n") unless open(GF, ">$makeGaps.$startread-$endread.fasta");
			$printing = 0;
			$printing = 1 if $startread == 0;
			$readindex = 0;
			while ($line = <QF>) {
				++$readindex if $line =~ /^>/;
				$printing = 1 if $readindex == $startread;
				$printing = 0 if $readindex == $endread;
				print GF $line if $printing == 1;
				}
			close QF;
			close GF;
			print "\nCreated gap file at $makeGaps.$startread-$endread.fasta";
		}
	}

}

sub dostats{

	my %hits;
	$totalhits = 0;
	$progresscount = 0;
	my @queries;

	#set the cut-to and cut-from file names to the defaults if they were not specified by the user
	$cuttofilename =  "$blastqueryfile.cuttoprogress" if (defined $cuttofilename && !$cuttofilename);
	$cutfromfilename = "$blastqueryfile.cutfromprogress" if (defined $cutfromfilename && !$cutfromfilename);

	#get the clean name for the query file
	$blastqueryfile =~ /\/([^\/]+)$/;
	$cleanname = $1;

	#detect if output is in xml format
	$head = `head -1 $blastoutputfile`;
	my $is_xml if $head =~ /^<\?xml/;
	print STDERR "DETECTED XML OUTPUT FORMAT\n" if $is_xml;
	print STDERR "DETECTED TABULAR OUTPUT FORMAT\n" unless $is_xml;

	#make hash of hits
	die ("ERROR: could not open blast output file $blastoutputfile\n") unless open(BLASTOUTPUT, "<$blastoutputfile");
	while ($line = <BLASTOUTPUT>) {
		chomp $line;
		if ($is_xml) {
			next unless $line =~ /<.*query-def.*>(.+)<\/.*query-def.*>/;
			$qname = $1;
			$qname =~ /^(\S+)/;
			$qname = $1;
		} else {
			next unless $line =~ /^(\S+)\s/;
			$qname = $1;
			}
		++$hits{$qname};
		++$totalhits;
		$lasthit = $qname;
		}
	close BLASTOUTPUT; 

	#make array of input sequences, in order, and produce the cut-to-progress file if requested
	die ("ERROR: could not open blast query file $blastqueryfile\n") unless open(BLASTINPUT, "<$blastqueryfile");
	if (defined $cuttofilename) {
		die("ERROR: could not create cut-to-progress file at $cuttofilename") unless open(CUT, ">$cuttofilename");
		}
	if (defined $cutfromfilename) {
		die("ERROR: could not create cut-from-progress file at $cutfromfilename\n") unless open(CUTFROM, ">$cutfromfilename");
		}

	my $cutdone = 0;
	while ($line = <BLASTINPUT>) {
		chomp $line;
		$currentseq = $1 if $line =~ /^>(\S+)\s/;
		$cutdone = 2 if ($line =~ /^>/ && $cutdone == 1); #set cutdone to 2 when we are one the next sequence after the last with full hit
		if (defined $cuttofilename) {
			print CUT "$line\n" unless $cutdone == 2;
			}
		if (defined $cutfromfilename) {
			print CUTFROM "$line\n" if $cutdone == 2;
			}
		push(@queries, $1) if $line =~ /^>(\S+)/;
		next unless $currentseq && $lasthit;
		if ($currentseq eq $lasthit) {
			$cutdone = 1; #set cutdone to 1 if we are on the last sequence with full hit
			}
		}
	close BLASTINPUT;
	close CUT if $cuttofilename;
	close CUTFROM if $cutfromfilename;
	$querycount = @queries;

	#handle the 'no output yet' condition
	if ($lasthit eq "") {
		$hitcount = 0;
		$totalhits = 0;
		$progresscount = 0;
		$percentrelative = 0;
		$avghitsperquery = 0;
		$percentprogress = 0;
		return;
	}

	#determine the number of query hits which have been processed, approximately
	foreach (@queries) {
		++$progresscount;
		$found_lasthit = 1 if $_ eq $lasthit;
		last if $_ eq $lasthit;
		}
	die ("FATAL AND EMBARRASSING ERROR - did not find lasthit $lasthit in query file $blastqueryfile\n") unless $found_lasthit == 1;

	#calculate and report basic info
	$percentprogress = ($progresscount * 100) / @queries;
	$hitcount = 0;
	$hitcount = keys(%hits);
	$percentrelative = ($hitcount * 100) / $progresscount;
	$avghitsperquery = ($totalhits / $progresscount);
} #end of dostats sub

sub printstats {

	print<<EOF
BLAST QUERY FILE:\t$blastqueryfile
BLAST OUTPUT FILE:\t$blastoutputfile

TOTAL QUERY SEQUENCES:\t$querycount
TOTAL SEQUENCES WITH HITS:\t$hitcount
TOTAL HITS:\t$totalhits

NUMBER OF QUERY SEQUENCES PROCESSED:\t$progresscount
PERCENT PROCESSED QUERIES WITH HITS:\t$percentrelative%
AVG HITS PER PROCESSED QUERY:\t$avghitsperquery
PROGRESS:\t$percentprogress%

LAST QUERY WITH FULL HIT:\t$lasthit
EOF
;
	} #end of printstats sub

sub cuttoprogress {
	print "\nCUT-TO-PROGRESS FILE GENERATED AT $cuttofilename";
}

sub cutfromprogress {
	print "\nCUT-FROM-PROGRESS FILE GENERATED AT $cutfromfilename";
}

sub getstarttime { #grab the start time from qstat

	#run qstat and parse the output
	$qstat = `qstat`;
	@qstat = split(/\n/, $qstat);
	undef $jobline;
	foreach (@qstat) {
		$jobline = $_ if $_ =~ /^$jobid/;
		}
	if (!$jobline) {
		print STDERR "\nERROR: could not find jobid $jobid, is qstat working? Are you sure the job is still running?";
		return;
		}
	$jobline =~ /^$jobid\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+\s+\S+)\s+/;
	$datetime = $1;
	$datetime =~ /(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/;
	@jobtime = ($6, $5, $4, $2, ($1 - 1), $3);
	$jobtime = timelocal(@jobtime);
} #end of getstarttime sub

sub estimateendtime {
	
	#handle the "no output yet" condition
	if ($lasthit eq "") {
		$completiontime = "CANNOT BE ESTIMATED";
		return;
		}

	#estimate the end time
	$jobtimenice = localtime($jobtime);
	@today = localtime();
	$currenttime = timelocal(@today);
	$currenttimenice = localtime($currenttime);
	$timediff = $currenttime - $jobtime;
	$totaltime = (($timediff * 100) / $percentprogress);
	$timeremaining = $totaltime - $timediff;
	$completiontime = $currenttime + $timeremaining;
	$completiontimenice = localtime($completiontime);
} #end of estimateendtime sub

sub printendtime {

	print <<EOF

JOB ID:\t$jobid
JOB START TIME:\t$jobtimenice
CURRENT SYSTEM TIME:\t$currenttimenice
ESTIMATED COMPLETION TIME:\t$completiontimenice
EOF
;
} #end of printendtime sub

sub readshscript { #parse the parameters out of a shell script

	die ("ERROR: could not open shell script $shellscript") unless open (SH, "<$shellscript");
	if ($shellscript =~ /\//) { #if the shell script is not in the working dir
		$shellscript =~ /^(.+\/)([^\/]+)$/;
		$reldir = $1;
		$cleanname = $2;
	} else { #if the shell script is in the working dir
		$cleanname = $shellscript;
		$reldir = "";	
	}

	while ($line = <SH>) {
		chomp $line;
		next if $line =~ /^#/;
		next if $line eq "";
		if ($line =~ /^blastall|blastpgp/) {
			$line =~ /-i\s+(\S+)/; #TODO: what if the query file name contains escaped spaces?
			$blastqueryfile = $1;
			$blastqueryfile = $reldir . $blastqueryfile unless $blastqueryfile =~ /^\//; #prefix to account for relative directory unless the shell script specifies an absolute path, i.e. the path begins with a /
			$line =~ /-o\s+(\S+)/; #TODO: what if the output file name contains escaped spaces?
			$blastoutputfile = $1;
			$blastoutputfile = $reldir . $blastoutputfile unless $blastoutputfile =~ /^\//; #prefix to account for relative directory unless the shell script specifies an absolute path, i.e. the path begins with a /
			}
		}
	close SH;	

	#get the job id from qstat
	$qstat = `qstat -r`;
	@qstat = split(/\n/, $qstat);
	foreach $line (@qstat) {
		$jobid = $1 if $line =~ /^(\d+)/;
		$found_job = 1 if $line =~ /Full\sjobname:.+$cleanname/;
		last if $line =~ /Full\sjobname:.+$cleanname/;
		}
	if (!$found_job) { #if the job could not be found in the qstat list
		print STDERR "ERROR: Could not find a job id for shell script $cleanname - are you sure it's running on the SGE?\n";
		undef $jobtime; #carry on, but don't try and estimate end time
		}
} #end of readshscript sub

sub parse_start_time { #parse a user-provided start time

	die ("ERROR - job start time (-t) must be provided in the format DD-MM-YYYY-HH:MM:SS (24-hour time)\n") unless $userstarttime =~ /^([012][0-9]|3[01])-(0[1-9]|1[0-2])-(\d{4})-([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$/;
        @jobtime = ($6, $5, $4, $1, $2 - 1, $3);
        $jobtime = timelocal(@jobtime);
} #end of parse_start_time sub

sub get_list_of_user_jobs { #returns a list of jobs running on the sge under the current user's name
	my $user_name = `whoami`;
	my $qstat_output = `qstat -u $user_name`;
	my @qstat_lines = split(/\n/, $qstat_output);
	my @jobid_list;
	foreach $line (@qstat_lines) {
		next if $line =~ /^job-ID/;
		next if $line =~ /^-/;
		$line =~ /^(\S+)/;
		push(@jobid_list, $1);
		}
	
	foreach $jobid (@jobid_list) {
		$qstat_output = `qstat -j $jobid`;
		$qstat_output =~ /\nsge_o_workdir:\s+(.+)\n/;
		my $working_dir = $1;
		$qstat_output =~ /\njob_name:\s+(.+)\n/;
		$script_path = $working_dir . "/" . $1;
		push(@return, $script_path);
	}
	return @return;	
}

sub read_shell_scripts_file {
	die ("ERROR - cannot read shell scripts file $shell_scripts_file\n") unless open(SSF, "<$shell_scripts_file");
	undef @return;
	while ($line = <SSF>) {
		chomp $line;
		push(@return, $line);
	}
	return @return;
}