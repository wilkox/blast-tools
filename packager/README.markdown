#About
This set of scripts is designed for managing large BLAST jobs on a remote server running PBS or similar, where there are limitations on bandwidth and disk space at the remote server. It breaks BLAST jobs up into chunks and manages them in the PBS queue.

These scripts were written for a specific case in a specific environment and are **absolutely not fit for production use** unless you have read every line of code, tested them thoroughly and know exactly what you're doing!

#Requiremens
Requires `perl` and subversion on both the local and remote servers.

#License
This software is released into the public domain. To the extent possible under law, all copyright and related or neighboring rights are waived and permission is explicitly and irrevocably granted to copy, modify, adapt, sell and distribute it in any way you choose.

Attribution to the author would be appreciated but is not required.

#Author
Packager was written by David Wilkins: david@wilkox.org
