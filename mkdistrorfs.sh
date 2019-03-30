#!/bin/bash

# create ubuntu rootfs 
#support CPU arch: armhf,arm64,powerpc ,power64
#support version: 
#			ubuntu 18.04		bionic
#			ubuntu 16.04   		xenial
#			ubuntu 14.04		trusty
#			ubuntu 12.01		precise
#more ubuntu version please see /usr/share/debootstrap/scripts
#parametes:
#		$1 : CPU arch : arm32,arm64,powerpc, powerpc64
#		$2 : ubuntu version


set -e

ARCH=arm64
UVERSION=arm64
FBVERSION=0.0.1
DISTROTYPE=ubuntu
CFGFILE=ubuntu_command.cfg

usage() {
    echo "usage: mkdistrorfs.sh <arch> <distro_codename> [ <package-list> ]"
    echo example:
    echo " mkdistrorfs.sh arm64 xenial"
    echo " mkdistrorfs.sh armhf stretch"
    echo " mkdistrorfs.sh amd64 zesty"
    exit
}

install_package() {

	if [ -f ${RFSDIR}/usr/aptpkg/.firststagedone ]; then
		echo ${RFSDIR} firststage exist!
		return
    fi
    packages_list=${FBDIR}/configs/ubuntu/${CFGFILE}
    . $packages_list

	for pkg in $dependent_pkg; do
		echo "check $pkg ..."
		if ! dpkg-query -l $pkg | grep ii 1>/dev/null; then
		echo installing $pkg ..
		sudo apt-get -y install $pkg
		fi
	done
}

gen_ubuntu_roofs(){
	
	if [ -f ${RFSDIR}/usr/aptpkg/.firststagedone ]; then
		echo ${RFSDIR} firststage exist!
		return
    fi
	
	if [ ! -d "$RFSDIR" ]; then
		mkdir -p ${RFSDIR}
		mkdir -p ${RFSDIR}/usr/bin
		mkdir -p ${RFSDIR}/lib/modules
		echo "create rfs folder ${RFSDIR}"
    fi
	
	
	
	if [ ${ARCH} = arm64 ]; then
		tgtarch=aarch64
		bstarch=arm64
	elif [ ${ARCH}  = arm32 ]; then	
		tgtarch=arm
		bstarch=armhf
	elif [ ${ARCH}  = powerpc ]; then	
		tgtarch=ppc
		bstarch=${ARCH} 
	elif [ ${ARCH}  = powerpc64 ]; then	
		tgtarch=ppc64le
		bstarch=ppc64el
	else 
		echo "ARCH error ,exit"
		exit
    fi
	
	echo "tgtarch=$tgtarch"
	if [ ! -f /usr/sbin/update-binfmts ]; then
		echo update-binfmts not found
		exit 1
    fi
	
	
	if update-binfmts --display qemu-${tgtarch} | grep disabled 1>/dev/null; then
		update-binfmts --enable qemu-${tgtarch}
	if update-binfmts --display qemu-${tgtarch} | grep disabled; then
	    echo enable qemu-${tgtarch} failed
	    exit 1
	else
	    echo enable qemu-${tgtarch} successfully
	fi
    fi
	
	if [ ! -f /usr/bin/qemu-${tgtarch}-static ]; then
		echo qemu-${tgtarch}-static not found
		exit 1
    fi
	
    if [ ! -f /usr/sbin/debootstrap ]; then
		echo debootstrap not found
		exit 1
    fi

	 if [ $1 != amd64 ] && [ ! -f ${RFSDIR}/usr/bin/qemu-${tgtarch}-static ]; then
        cp /usr/bin/qemu-${tgtarch}-static ${RFSDIR}/usr/bin
    fi
	
	packages_list=configs/ubuntu/additional_packages_list_moderate
	echo additional packages list: ${packages_list}
    if [ ! -d ${RFSDIR}/usr/aptpkg ]; then
		mkdir -p ${RFSDIR}/usr/aptpkg
		cp -f ${packages_list} ${RFSDIR}/usr/aptpkg
		cp -f configs/ubuntu/extrinsic-pkg/*.sh ${RFSDIR}/usr/aptpkg
	if [ -f configs/ubuntu/reconfigpkg.sh ]; then
	    cp -f configs/ubuntu/reconfigpkg.sh ${RFSDIR}/usr/aptpkg
	fi
    fi
	
	if [ -f configs/ubuntu/reconfigpkg.sh ]; then
	    cp -f configs/ubuntu/reconfigpkg.sh ${RFSDIR}/usr/aptpkg
	fi
	
	sudo cp mkdistrorfs.sh ${RFSDIR}/usr/bin/mkdistrorfs
	
	 if [ ! -d ${RFSDIR}/debootstrap ]; then
		echo "sudo debootstrap --arch=${bstarch} --foreign $2 ${RFSDIR}"
        sudo debootstrap --arch=${bstarch} --foreign $2 ${RFSDIR}
        echo "installing for second-stage ..."
	fi
	
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C \
        sudo chroot ${RFSDIR} /debootstrap/debootstrap  --second-stage
    echo "configure ... "
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C \
        sudo chroot ${RFSDIR} dpkg --configure -a
	
	#change root to ${RFSDIR}, install necessary packages
	touch ${RFSDIR}/usr/aptpkg/.firststagedone
	echo  "sudo chroot $RFSDIR mkdistrorfs $1 $2 ${RFSDIR}"
	sudo chroot ${RFSDIR} mkdistrorfs $1 $2 ${RFSDIR}
	
}

install_cfg_secondstage() {

	echo "check ${RFSDIR}/usr/aptpkg/.rfsblddone"
	if [ -f ${RFSDIR}/usr/aptpkg/.rfsblddone ] ; then
        echo "${RFSDIR}/usr/aptpkg/.rfsblddone exit"
		return
    fi
	
	if [ -n "$3" ]; then
		packages_list=/usr/aptpkg/$3
    else
        packages_list=/usr/aptpkg/additional_packages_list_moderate
    fi
    . $packages_list
	
    # set locale
    if ! grep LANG= /etc/default/locale && [ $2 = xenial ]; then
		export LC_ALL=en_US.UTF-8
        echo 'LANG="en_US.UTF-8"' > /etc/default/locale
        locale-gen en_US.UTF-8
		dpkg-reconfigure -f noninteractive locales
    fi

    # set timezone
    if [ ! -f /etc/timezone ]; then
        echo "tzdata tzdata/Areas select America" > /tmp/tmptz
        echo "tzdata tzdata/Zones/America select Chicago" >> /tmp/tmptz
        debconf-set-selections /tmp/tmptz
        rm /etc/timezone
        rm /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata
        rm /tmp/tmptz
    fi

    # create user and passwd
    if [ ! -d /home/user ]; then
        useradd -m -d /home/user -s /bin/bash user
        gpasswd -a user sudo
        echo -e 'root\nroot\n' | passwd root
        echo -e 'user\nuser\n' | passwd user
	mkdir -p /home/user
	chown -R user:user /home/user
    fi
    # set default hostname
    echo localhost > /etc/hostname

    # set apt sources list to install additional packages
    asl=/etc/apt/sources.list
    rm -f $asl
    if [ ${DISTROTYPE} = ubuntu ]; then
	if [ ${ARCH} = "x86_64" -o ${ARCH} = "i686" ]; then
	    fn=archive; pn=ubuntu;
	else
	    fn=ports; pn=ubuntu-ports;
	fi

	echo deb http://mirrors.aliyun.com/$pn/ $2 main restricted  universe multiverse >> $asl
	echo deb-src http://mirrors.aliyun.com/$pn/ $2 main restricted  universe multiverse >> $asl

	echo deb http://mirrors.aliyun.com/$pn/ $2-updates main restricted  universe multiverse >> $asl
	echo deb-src http://mirrors.aliyun.com/$pn/ $2-updates main restricted  universe multiverse >> $asl

	echo deb http://mirrors.aliyun.com/$pn $2-security main restricted >> $asl
	echo deb-src http://mirrors.aliyun.com/$pn $2-security main restricted >> $asl

	echo deb http://mirrors.aliyun.com/$pn $2-proposed main restricted universe multiverse >> $asl
	echo deb-src http://mirrors.aliyun.com/$pn $2-proposed main restricted universe multiverse >> $asl

	echo deb http://mirrors.aliyun.com/$pn $2-backports main restricted universe multiverse >> $asl
	echo deb-src http://mirrors.aliyun.com/$pn $2-backports main restricted universe multiverse >> $asl
	

    elif [ ${DISTROTYPE} = debian ]; then
	echo deb [arch=$1] http://mirrors.kernel.org/debian/ $2 main >> $asl
    fi

	echo "start apt-get -y update"
    apt-get -y update
    if [ ${DISTROTYPE} = ubuntu ]; then
	if ! dpkg-query -W language-pack-en-base 1>/dev/null; then
	    echo installing language-pack-en-base ..
            apt-get -y install language-pack-en-base
	fi
    fi
	
	echo "start apt-get -y upgrade"
    apt-get -y upgrade

    # install cross toolchain for armhf on aarch64 machine
    if [ ${ARCH} = "arm64" -a ${DISTROTYPE} = ubuntu ] && [ -f /usr/bin/qemu-aarch64-static ]; then
        apt-get -y install crossbuild-essential-armhf gcc-arm-linux-gnueabihf gccgo-6
	elif [${ARCH} = "arm32" -a ${DISTROTYPE} = ubuntu]; then
		apt-get -y install gcc crossbuild-essential-armhf gcc-arm-linux-gnueabihf
	elif [${ARCH} = "powerpc" -a ${DISTROTYPE} = ubuntu]; then
		apt-get -y install gccgo-6 gccgo-6-doc gcc
    fi

    # Add additional packages for user convenience
    echo installing additional packages: $additional_packages_list
    for pkg in $additional_packages_list; do
		echo installing $pkg ...
		apt-get -y install $pkg || true
	done
    echo "additionally packages installed."
	/usr/aptpkg/reconfigpkg.sh
    touch /usr/aptpkg/.rfsblddone
}


gen_extra_package() {
	if [ ! -d "build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d"]; then
		echo	"build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d not exit"
	  	return
	fi
	echo "generate tz file "
	cd  build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d
	sudo tar czf  $FBDIR/image/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs_`date +%Y%m%d%H%M`.tz *
}

[ $? -ne 0 ] && usage

if [ $2 = jessie -o $2 = stretch ]; then
    DISTROTYPE=debian
elif [ -z "$DISTROTYPE" ]; then
    DISTROTYPE=ubuntu
fi


if [ $1 = arm32  ]; then
    ARCH=arm32
	export CC=arm-linux-gnueabihf-gcc 
elif [ $1 = arm64 ]; then
	ARCH=arm64
	export CC=aarch64-linux-gnu-gcc
elif [ $1 = powerpc ]; then
	ARCH=powerpc
	export CC=powerpc-linux-gnuspe-gcc
elif [ $1 = powerpc64 ]; then
	ARCH=powerpc64
	export CC=powerpc64-linux-gnu-gcc
else
    echo "ARCH eroor ,exit!"
	exit
fi
 echo "ARCH=${ARCH}"
 
 FBDIR=$(pwd)
 if [ -z "$3" ]; then 
	RFSDIR=$FBDIR/build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d
fi

echo "FBDIR=$FBDIR"
echo "RFSDIR=${RFSDIR}"


install_package $1 $2 
gen_ubuntu_roofs $1 $2

echo "check build/rfs/${DISTROTYPE}_$2_$ARCH_rootfs.d/usr/aptpkg/.rfsblddone"
if [ -f build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d/usr/aptpkg/.rfsblddone ]; then
    echo build/rfs/${DISTROTYPE}_${2}_${ARCH}_rootfs.d is available!
   exit
fi

echo "start stage 2"
if [ ${ARCH} = "arm64"  ]  || [ ${ARCH} = "arm32" ]  ||   [ ${ARCH} = "powerpc" ] ||   [ ${ARCH} = "powerpc64" ]]; then
    install_cfg_secondstage $1 $2 
    distrotimestamp=${DISTROTYPE}_${2}_${ARCH}_`date +%Y%m%d%H%M`
    echo $distrotimestamp > /usr/aptpkg/.rfsblddone
	
fi

gen_extra_package $1 $2

