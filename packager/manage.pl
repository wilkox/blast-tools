#!/usr/bin/perl

#manage blast packages created with package.pl

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

#load the svn module
print STDERR "\nChecking the correct svn version has been loaded...";
my $SVNversion = `svn --version`;
unless ($SVNversion =~ /1\.6\.17/) {
	print "\nYou need to load the SVN 1.6.17 module. Run this command in your shell:\n\nmodule load /sw/SVN/1.6.17/1.6.17\n\nIf you want this module to load automatically on login, add it to your ~/.bashrc.";
	exit;
}

#read index.dat
unless (-e "index.dat") {
	print STDERR "\nIt looks like this is your first run, as index.dat isn't present. We'll run an svn update to try and bring it over. You may be asked for your ssh password.";
	print STDERR "\n[svn update]\n";
	system("svn update");
}
die ("ERROR - cannot open index.dat") unless open(INDEX, "<index.dat");
while ($line = <INDEX>) {
	chomp $line;
	my @line = split(/\t/, $line);
	my $status = shift(@line);
	my $package = shift(@line);
	$status{$package} = $status;
	push(@index, $package);
	@qids = @line;
	foreach (@qids) {
		$qids{$_} = "";
	}
}

#go through and figure out what package is currently running
foreach $package (@index) {
	next unless $status{$package} eq "R";
	print STDERR "\nPackage $package is marked as running - checking in with qstat to see if it is still going";
	my $whoami = `whoami`;
	$whoami =~ s/\n//g;
	print STDERR "\n[qstat | grep $whoami 2>&1]\n";
	my $qstat = `qstat | grep $whoami 2>&1`;
	my @qstat = split(/\n/, $qstat);
	my $running;
	foreach $line (@qstat) {
		$line =~ /^(\S+)/;
		$running = 1 if exists $qids{$1};
	}

	#if it's still running, report and exit
	if ($running == 1) {
		print STDERR "\nPackage $package is still running. Come back later!\n";
		exit;

	#if not, assume it's finished
	} else {
		
		#mark as complete
		print STDERR "\nPackage $package has finished running. Marking as complete.";
		$status{$package} = "C";
		&updateIndex;

		#svn commit and exclude the package
		print STDERR "\nCommitting the changes to the repo. You may be asked for your ssh password.";
		print STDERR "\n[svn add $package --force] Adding all unversioned parts of the tree\n";
		system("svn add $package --force");
		print STDERR "\n[svn commit -m 'automated commit for completion of $package'] Committing changes\n";
		system("svn commit -m 'blast packager automated commit'");
		print STDERR "\nRemoving the local copy of $package. You may be asked for your ssh password.";
		print STDERR "\n[svn update --set-depth exclude $package]\n";
		system("svn update --set-depth exclude $package");
		
		#exit the loop so the next package can be set running
		last;
	}
}

#if nothing is running, get something running
print STDERR "\nLooking for next package to submit to queue.";
foreach $package (@index) {
	next unless $status{$package} eq "Q";
	$toSubmit = $package;
	&submitPackage($toSubmit);
	exit;
}

print STDERR "\nNo packages left to run!\n";

##SUBROUTINES

#submits a package to the queue
sub submitPackage {

	my $package = $_[0];

	print STDERR "\nSubmitting package $package...";

	#first make sure the package is actually present
	unless (-d "$package") {
		print STDERR "\nPackage $package is not currently present. We'll use svn to bring it over. You may be asked for your ssh password.";
		print STDERR "\n[svn update --set-depth infinity $package]\n";
		system("svn update --set-depth infinity $package");
	}
	unless (-d "$package") {
		print STDERR "\nPackage $package was unable to be retrieved. Do you have a good connection to the machine where your svn repo is hosted?";
		exit;
	}

	#get a list of all the submission scripts in that package
	my $scripts = `find $package/scripts -type f | grep -v svn`;
	my @scripts = split(/\s+/, $scripts);
	foreach (@scripts) {
		print STDERR "\nSubmitting $_...";
		print STDERR "\n[qsub $_ 2>&1]";
		my $qid = `qsub $_ 2>&1`;
		$qid =~ s/\n//g;
		$qid =~ s/\s//g;
		push(@qids, $qid);
	}

	#update index to show that the package is running
	$status{$package} = "R";
	&updateIndex;

}

#updates the index
sub updateIndex {
	die ("ERROR - cannot write index.dat") unless open(INDEX, ">index.dat");
	print STDERR "\nUpdating index...";
	foreach (@index) {
		print INDEX "$status{$_}\t$_";
		if ($status{$_} eq "R") {
			foreach my $qid (@qids) {
				print INDEX "\t$qid";
			}
			print INDEX "\n";
		} else {
			print INDEX "\n";
		}
	}
	close INDEX;
	
	print STDERR "\nCommiting updated index...";
	print STDERR "\n[svn commit -m 'commiting updated index']";
	system("svn commit -m 'commiting updated index'");
}
