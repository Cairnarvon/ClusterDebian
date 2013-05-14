#!/bin/bash

if [ "$(whoami)" != "root" ]; then
    echo "Should be root." >&2
    exit 1
fi

[ -f config.sh ] && . config.sh

for X in $CLUSTER; do
    case "$X" in
        mpi)
            MPI=y
            ;;
        pvm)
            PVM=y
            ;;
        *)
            echo "Unrecognised option: CLUSTER $X." >&2
            ;;
    esac
done

for X in $MONITOR; do
    case "$X" in
        sinfo)
            SINFO=y
            ;;
        *)
            echo "Unrecognised option: MONITOR $X." >&2
            ;;
    esac
done

packages()
{
    echo "Installing packages."

    aptitude -q=3 update

    CLUSTERING=
    [ -n "$MPI" ] && CLUSTERING="$CLUSTERING libopenmpi-dev openmpi-bin openmpi-checkpoint"
    [ -n "$PVM" ] && CLUSTERING="$CLUSTERING pvm pvm-dev"

    MONITORING=
    [ -n "$SINFO" ] && MONITORING="$MONITORING sinfo"

    XORG="xorg feh"
    case "$WM" in
        wmii)
            # We'll install wmii itself manually.
            ;;
        "")
            unset XORG
            ;;
        *)
            XORG="$XORG $WM"
    esac

    SSH="openssh-client openssh-server"
    LIVE="rsync memtest86+ genisoimage grub-pc squashfs-tools live-boot live-config live-config-sysvinit live-boot-initramfs-tools syslinux hwdata"
    PXE="isc-dhcp-server syslinux atftpd nfs-kernel-server"
    MISC="build-essential gcc git make wget"

    ALL="$CLUSTERING $MONITORING $XORG $SSH $LIVE $PXE $MISC $EXTRAPACKAGES"

    aptitude -q=3 -y install $ALL || exit 2

    # Only node1 needs this; our cluster script will start them manually.
    update-rc.d isc-dhcp-server remove
    update-rc.d nfs-kernel-server remove

    if [ "$WM" == "wmii" ]; then
        # The version of wmii in the Debian repositories is too old to be usable.
        # So, let's build our own.
        echo "Installing wmii."
        if [ ! -f wmii_3.9.2_i386.deb ]; then
            if [ ! -d "wmii+ixp-3.9.2" ]; then
                wget -O - http://dl.suckless.org/wmii/wmii+ixp-3.9.2.tbz | tar xj
            fi
            cd wmii+ixp-3.9.2
            make deb-dep
            make deb
            cd ..
        fi
        dpkg -i wmii_3.9.2_*.deb || exit 2
    fi
}

config()
{
    [ -z "$NETWORK" ] && NETWORK=192.168.1.0
    NETBASE=$(awk -F '.' '{print $1"."$2"."$3}' <<< $NETWORK)

    echo "Copying configuration files."

    # DHCP
    sed "s/DNS/${DNS// /, }/g
         s/BROADCAST/$NETBASE.255/g
         s/NETWORK/$NETBASE.0/g
         s/RANGE/$NETBASE.2 $NETBASE.251/g" conf/dhcpd.conf >/etc/dhcp/dhcpd.conf

    # Network interfaces for node1
    sed "s/NODE1/$NETBASE.1/" conf/interfaces        >/etc/network/interfaces
    [ -n "$GATEWAY" ] && echo "    gateway $GATEWAY" >>/etc/network/interfaces

    # DNS
    if [ -n "$DNS" ]; then
        cp conf/resolv.conf /etc/resolv.conf
        for DNSIP in $DNS; do
            echo "nameserver $DNSIP" >>/etc/resolv.conf
        done
    else
        rm /etc/resolv.conf
    fi

    # PXE
    mkdir -p /srv/tftp/pxelinux.cfg
    sed "s/NODE1/${NETBASE}.1/" conf/pxelinux.cfg >/srv/tftp/pxelinux.cfg/default

    # SSH
    cp conf/ssh{,d}_config /etc/ssh/

    # NFS
    cp conf/exports /etc/exports

    # TFTP
    cp conf/inetd.conf /etc/inetd.conf

    # sinfo
    [ -n "$SINFO" ] && sed "s/NETBASE/${NETBASE}/" conf/sinfo >/etc/default/sinfo
}

bling()
{
    echo "Updating miscellaneous files."

    # issue and motd
    BASED_ON=$(printf "%63s" "Based on $(lsb_release -sd)")
    sed "s#BASED_ON#$BASED_ON#" misc/issue >/etc/issue

    # motd
    rm -f /etc/motd
    cp misc/motd /etc/motd
}

userdot()
{
    PERSON=$(basename $1)
    echo "Copying dotfiles for $PERSON."

    cp dot/.{bash,vim}rc $1
    chown $PERSON $1/.{bash,vim}rc

    rm -f $1/.ssh/id_rsa*
    su -c "ssh-keygen -q -f $1/.ssh/id_rsa -N ''" $PERSON
    cat $1/.ssh/id_rsa.pub >>/etc/ssh/authorized_keys

    if [ -n "$WM" ]; then
        cp misc/wallpape.png $1/.wallpape.png
        sed "s/WM/$WM/" dot/.xinitrc >$1/.xinitrc
        cp dot/.Xresources $1
        chown $PERSON $1/{.wallpape.png,.xinitrc,.Xresources}

        case "$WM" in
            wmii)
                cp -r dot/.wmii $1
                chown -R $PERSON $1/.wmii
                ;;
            *)
                ;;
        esac
    fi

    [ -n "$MPI" ] && ln -s /etc/cluster/mpi.hosts $1/mpi.hosts
    [ -n "$PVM" ] && ln -s /etc/cluster/pvm.hosts $1/pvm.hosts
}

dot()
{
    echo "Installing dotfiles."

    for USER in $(ls /home); do
        userdot /home/$USER
    done
    userdot /root
}

scripts()
{
    echo "Installing cluster scripts and man pages."

    cp scripts/cluster.shutdown /usr/bin
    [ ! -d "/usr/local/man/man8" ] && mkdir -p /usr/local/man/man8
    cp doc/cluster.shutdown.8 /usr/local/man/man8

    cp scripts/cluster.update /usr/bin
    cp doc/cluster.update.8 /usr/local/man/man8

    cp scripts/cluster /etc/init.d/cluster
    update-rc.d cluster defaults || exit 4

    [ -z "$NETWORK" ] && NETWORK=192.168.1.0
    NETBASE=$(awk -F '.' '{print $1"."$2"."$3}' <<< $NETWORK)
    [ ! -d "/usr/local/man/man7" ] && mkdir -p /usr/local/man/man7
    sed "s/NETBASE/${NETBASE}/g" doc/cluster.7 >/usr/local/man/man7/cluster.7
}

kernel()
{
    [ -z "$KERNEL" ]      && KERNEL=3.2.0
    [ -z "$KERNEL_CONF" ] && KERNEL_CONF=/boot/config-$(uname -r)
    [ -z "$AUFS_GIT" ]    && AUFS_GIT="http://git.c3sl.ufpr.br/pub/scm/aufs/aufs2-2.6.git"

    if [ "${KERNEL:0:1}" -eq 2 ]; then
        BRANCH="aufs2.1-${KERNEL/2.*./}"
    else
        MINOR=${KERNEL#*.}
        MINOR=${MINOR%.*}
        case $MINOR in
            [2,4,6-9])
                BRANCH="aufs3.$MINOR"
                ;;
            *)
                BRANCH="aufs3.x-rcN"
                ;;
            esac
    fi

    echo "Creating a usable kernel."
    echo "First, cloning the aufs repository."
    if [ ! -d "aufs-linux" ]; then
        git clone --branch "$BRANCH" $AUFS_GIT aufs-linux || exit 3
        cd aufs-linux
    else
        cd aufs-linux
        echo "Checking out."
        git checkout "$BRANCH" || exit 3
    fi

    echo "Configuring kernel."
    sed '/CONFIG_NFS_FS/d
         /CONFIG_NFS_V4/d
         /CONFIG_NFSD/d
         /CONFIG_NFSD_V4/d
         /CONFIG_NFS_COMMON/d
         /CONFIG_AUFS_EXPORT/d
         /CONFIG_AUFS_FS/d
         /CONFIG_EXPORTFS/d' "$KERNEL_CONF" >.config
    echo "\
CONFIG_NFS_FS=y
CONFIG_NFS_V4=y
CONFIG_NFSD=y
CONFIG_NFSD_V4=y
CONFIG_NFS_COMMON=y
CONFIG_AUFS_FS=y
CONFIG_AUFS_EXPORT=y
CONFIG_EXPORTFS=y" >>.config

    # We don't need specific values for the next two options, but a typical
    # kernel conf won't include defaults for them, so to avoid prompting we
    # supply them.
    grep -q 'AUFS_HNOTIFY'    .config || echo "CONFIG_AUFS_HNOTIFY=n"    >>.config
    grep -q 'AUFS_BR_HFSPLUS' .config || echo "CONFIG_AUFS_BR_HFSPLUS=y" >>.config

    make silentoldconfig

    echo "Building."
    make

    echo "Installing."
    make modules_install
    make headers_install
    make install

    echo "Thank you for your patience."
    cd ..
}

pxe()
{
    [ -z "$KERNEL" ] && KERNEL=2.6.31

    echo "Setting up PXE."

    if [ ! -f "/usr/lib/syslinux/pxelinux.0" ]; then
        echo "Couldn't find pxelinux.0! Installing packages first."
        packages
    fi
    cp /usr/lib/syslinux/pxelinux.0 /srv/tftp/pxelinux.0

    KERNELPATH="/boot/vmlinuz-$KERNEL"

    [ ! -f "$KERNELPATH" ] && KERNELPATH="$KERNELPATH+"

    if [ ! -f "$KERNELPATH" ]; then
        echo -n "Couldn't find kernel! Enter path (or blank to build one): "
        read KERNELPATH
        while [ ! -f "$KERNELPATH" ]; do
            if [ -z "$KERNELPATH" ]; then
                kernel
                KERNELPATH="/boot/vmlinuz-$KERNEL"
                [ ! -f "$KERNELPATH" ] && KERNELPATH="$KERNELPATH+"
            else
                echo -n "Invalid kernel path! Re-enter: "
                read KERNELPATH
            fi
        done
    fi
    cp "$KERNELPATH" /srv/tftp/vmlinuz.img.netboot

    sed -i.old 's/BOOT=local/BOOT=nfs/' /etc/initramfs-tools/initramfs.conf
    mkinitramfs -o /srv/tftp/initrd.img.netboot ${KERNELPATH#*/vmlinuz-}
    mv /etc/initramfs-tools/initramfs.conf{.old,}
}

iso()
{
    echo "Generating ISO."
    scripts/remastersys
}

clean()
{
    git reset --hard HEAD
}

--help()
{
    echo "Usage: $0 [ ACTION... ]"
    echo "Actions:"
    echo "    packages"
    echo "    config"
    echo "    bling"
    echo "    dot"
    echo "    scripts"
    echo "    kernel"
    echo "    pxe"
    echo "    iso"
    echo "Specials:"
    echo "    localnode1"
    echo "    allbutkernel"
    echo
    echo "You almost certainly want to run this without arguments."
}

-h()
{
    --help
}

localnode1()
{
    packages
    config
    bling
    dot
    scripts
    pxe
}

allbutkernel()
{
    localnode1
    iso
}


if [ $# -gt 0 ]; then
    for f; do
        $f
    done
else
    packages
    config
    bling
    dot
    scripts
    kernel
    pxe
    iso
fi
