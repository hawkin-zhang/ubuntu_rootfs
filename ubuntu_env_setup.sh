#!/bin/bash


FBDIR=$(pwd)
CFGFILE=ubuntu_command.cfg

install_package() {

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

echo "setup necessary tools for ubuntu"

packages_list=${FBDIR}/additional_packages_list_moderate
. $packages_list
	
install_package 