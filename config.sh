#!/bin/bash

# Clusterings.
# Which method of HPC do we use?
# Values: mpi | pvm
# Or both, obviously.
CLUSTER="mpi pvm"

# Cluster status monitor.
# Only sinfo for now. Patches for Ganglia or Nagios or whatever welcome.
# Leave blank for none.
MONITOR=sinfo

# Window manager.
# Suggested values: wmii | icewm
# Warning: if you select wmii, we'll build it from scratch, which can take a
# minute and requires that suckless.org not be down.
# Leaving it blank will also neglect to install xorg at all.
WM=icewm

# Additional Debian packages you want to install.
# You can also install them manually before running the script
EXTRAPACKAGES=

# Kernel version to use. Has to be a 2.6 with a minor version supported by
# aufs2.1 (basically 31 and over), or 3.x.
# Default: 3.2.0; 2.6.32 suggested if you're using Squeeze
KERNEL=3.2.0

# Kernel configuration file.
# The specific options we need are adjusted automatically.
KERNEL_CONF=/boot/config-$(uname -r)

# Location of the aufs git repository.
# If you foresee building a lot of different versions of ClusterDebian and don't
# want to have to wait an hour while it pulls the repository over the Internet
# every time, consider hosting a local mirror somewhere and changing this.
# Otherwise, probably best not to touch it.
AUFS_GIT="http://github.com/sfjro/aufs3-linux.git"
# If you're using a 2.6 kernel, use the following instead:
#AUFS_GIT="git://git.c3sl.ufpr.br/aufs/aufs2-2.6.git"

# Network configuration.
NETWORK=192.168.1.0     # Subnet mask is /24. No exceptions.
GATEWAY=192.168.1.254
DNS="8.8.8.8 8.8.4.4"   # Google's public DNS (either way, space-separated)
