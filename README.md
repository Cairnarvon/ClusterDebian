# ClusterDebian

ClusterDebian is a Linux distro inspired by [ClusterKnoppix](http://clusterknoppix.sw.be/), which is sadly no longer maintained. It's designed to make HPC on temporary clusters a little bit more convenient.

The idea is that you have a network topology more or less like this:

![network](https://github.com/Cairnarvon/ClusterDebian/raw/master/doc/network.png "ClusterDebian network")

The first node boots off a live CD or USB device and automatically sets up a PXE server, and all of the other nodes boot off that. The entire filesystem is shared over NFS, for ease of interaction.

Unlike ClusterKnoppix, ClusterDebian is not an SSI cluster OS. The openMosix project is dead, MOSIX is non-free, and all the alternatives are, as far as I've been able to work out, crap. Instead, ClusterDebian uses **Open MPI** and/or **PVM** for its clustery goings-on.

ClusterDebian does not alter your HD in any way (though you can obviously mount it manually yourself if you want to), and in fact runs fine on machines that don't have any.

## Getting it

A ClusterDebian image is typically at least a few hundred megabytes in size, and I don't have the resources to share that kind of data over the Internets. Instead, I'm providing these scripts to help you create your own from a fresh Debian install, which has the added benefit that you can customise it to your liking in ways you couldn't with a plain ISO.

A step-by-step guide:

1. Obtain [Debian Squeeze](http://www.debian.org/) and install it on a machine, virtual or otherwise, with a few gigabytes of disk space (say four, though a bit more may be a good idea, depending on your architecture (64-bit kernels take up dramatically more disk space during the build process than 32-bit ones, in my experience) and how much crap you want to add yourself; err on the side of generosity, because you'll probably just be deleting it afterwards anyway). Don't bother installing anything but "Standard system utilities". Name your regular user whatever you like; he'll be in the final image too.

2. Log in as root and install `git` (`aptitude install git`).

3. Clone this repository to `/tmp` (`git clone git://github.com/Cairnarvon/ClusterDebian /tmp/clusterdebian`). It doesn't have to be `/tmp`, but putting it somewhere else (like a home directory) will usually mean it will end up in the finished ISO, and you don't need that (particularly since it will contain hundreds of megabytes of kernel bits by the end).

4. Go to that directory and edit `config.sh`. If you want to add your own files or packages to the system, now is the time to do it. (If you want to build something that depends on the Open MPI or PVM libraries, you can run `./build.sh packages` to install the various packages first, if you like.)

5. Run `./build.sh`. If everything goes right, you'll end up with an ISO after a while (and I do mean a while: along the way we'll be pulling the `aufs` repository and building a new kernel; say three or four hours). You can expect to be prompted twice during building: once during package installation, when you will be asked if you want to enable the `sinfo` CGI script (if you chose to install that, at least), and again when we're compiling the kernel, if there are options you haven't specified (there will probably be a few), something like an hour in on my machine. Other than that you can basically leave it running unattended.

6. Put this on a USB drive (`dd if=clusterdebian.iso of=/dev/sdb`, *assuming `/dev/sdb` is your USB device*) or a CD-ROM and try booting from it. (If you built inside a QEMU VM and are having difficulty getting the ISO to somewhere useful, remember that the host machine is accessible at IP 10.0.2.2. Just `scp` it.)

If you end up with a screen like the one below, things should be working.

![bootloader](https://github.com/Cairnarvon/ClusterDebian/raw/master/doc/isolinux.png "ISOLINUX bootloader")
![login](https://github.com/Cairnarvon/ClusterDebian/raw/master/doc/node1.png "ClusterDebian node1 login")

`node1` should have started its DHCP server automatically, so try booting the other nodes over PXE. The man page will guide you from there.

### Troubleshooting

Ideally all that can go wrong during building is our one external dependency failing, which is the `aufs` repository. If that happens, maybe [the `aufs` Sourceforge page](http://aufs.sourceforge.net/) will have mirrors. Just edit the `AUFS_GIT` variable in `config.sh`.

If you're using `wmii` as a window manager, there's another external dependency: if the Suckless server is down, installation will fail. To resolve this, either use another window manager (recommended) or set it to "none" and install `wmii` from the repositories instead. Be aware that this version is ancient, though, and missing quite a lot of the bits that make it a usable window manager.

If you run into any other issues during building, please [report them](issues).

## FAQ

### How do I install it to a HD?

I *really* can't recommend this, but if you'd rather not boot from USB or CD-ROM, you can just use the machine you're running the build script on as a permanent `node1`. An advantage of this is that you don't even have to build a new kernel, shaving something like three or four hours off the build process. The downside is that if you hose it, you can't just reboot to fix it (and it *will* be fragile; an incorrect shutdown can render it unable to boot).

To do this, just run `./build.sh localnode1` rather than just `./build.sh`. The secondary nodes will still boot over PXE.

### Why aren't my nodes receiving nice consecutive numbers?

The node number is the last octet of its IP address, and DHCP doesn't necessarily hand out IP addresses in nice consecutive sequences, so this can happen. No cause for concern, this is normal.

### Do I have to use Debian Squeeze?

You have to use Debian (some Debian derivatives might work, but don't count on it), but I don't see any particular reason ClusterDebian wouldn't work with testing or unstable, if you're that sort of person. No guarantees, though, and you'll have to edit `misc/issue` by hand.

### I just spent hours building an image and I just remembered something else I want to include. Do I really have to do it all over again?

Probably not. If your change did not affect `config.sh`, you can get away with just running `./build.sh iso` to rebuild just the ISO. Even if it did affect `config.sh` (and the change isn't to the kernel configuration), you can just run `./build.sh allbutkernel`. Note that running `./build.sh allbutkernel` without a working kernel will give you an ISO that won't work.

(If you've shut down your VM since the first build, run `/etc/init.d/cluster stop` before doing any of this. You'll probably need to `dhclient` as well.)

### Why are we compiling a new kernel in the first place?

There doesn't seem to be a way around it. To export either `aufs` or `unionfs` (which we need for the live-booting node) over NFS (which we need to do in order for our PXE nodes to have a filesystem to mount), we need a kernel that allows this, and the default Debian kernel does not, so we have to compile our own (and pull the `aufs` repository to do it). It's painful that two kernel options require hours to fix, but there you go. Suggestions welcome.

## Acknowledgements

ClusterDebian started as a three-person bachelor's graduating project at [KHLeuven](http://www.khleuven.be/) before I nicked it for my own and actually made it work. Credit is due to fellow students Bert Mertens and Jan Roes, and to KHLeuven's G&T department for letting me use their networking lab for a bit.
