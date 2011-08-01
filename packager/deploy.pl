#!/usr/bin/perl

#deploy blast packages

#written by david wilkins <david@wilkox.org>
#lives at https://github.com/wilkox/blast-tools

#this software is released into the public domain. To the extent 
# possible under law, all copyright and related or neighboring
# rights are waived and permission is explicitly and irrevocably
# granted to copy, modify, adapt, sell and distribute this software
# in any way you choose.

#create project directory
print "\nEnter a name for this blast project. A subdirectory with this name will be created in your home dir:\n>";
$projectName = <STDIN>;
chomp $projectName;
$home = $ENV{HOME};
if (-d "$home/$projectName") {
	print "\nDirectory $home/$projectName already exists, fool.";
	exit;
}
print "\n[mkdir $home/$projectName $home/$projectName/$projectName-working]\n";
system("mkdir $home/$projectName $home/$projectName/$projectName-working");

#make the svn repo
print "\nCreating a repository at $home/$projectName/repo";
print "\n[svnadmin create $home/$projectName/repo]\n";
system("svnadmin create $home/$projectName/repo");

#copy the packager files into the working dir
print "\nCopying packager into the project working dir";
print "\n[cp deploy.pl package.pl manage.pl reconstruct.pl template.sh $home/$projectName/$projectName-working/";
system ("cp deploy.pl package.pl manage.pl reconstruct.pl template.sh $home/$projectName/$projectName-working/");

#import packager files into repo
print "\nImporting working dir into repository";
print "\n[cd $home/$projectName; svn import $projectName-working file:///$home/$projectName/repo/$projectName-working -m 'packager initial import']\n";
system("cd $home/$projectName; svn import $projectName-working file:///$home/$projectName/repo/$projectName-working -m 'packager initial import'");

#remove working dir and check out versioned copy
print "\nRemoving unversioned copy of working dir and checking out versioned copy";
print "\n[rm -rf $home/$projectName/$projectName-working; cd $home/$projectName; svn checkout file:///$home/$projectName/repo/$projectName-working]";
system("rm -rf $home/$projectName/$projectName-working; cd $home/$projectName; svn checkout file:///$home/$projectName/repo/$projectName-working");

#deploy to remote server
$local = `hostname --long`;
$local =~ s/\n//g;
$user = `whoami`;
$user =~ s/\n//g;
$home =~ s/^\///g;
print "\n\n\nTime to deploy to remote server. Log on to the remote server and enter the following command in your home directory. You may be asked for your ssh password back to this machine, possibly twice.";
print "\n============\n\nsvn checkout --depth files svn+ssh://$user\@$local/$home/$projectName/repo/$projectName-working\n\n==========\n";
