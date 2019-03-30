#!/bin/bash

#setup iprout2 source package which is depended by ceetm component
if [ ! -d pkg-iproute ]; then
    git clone git://git.debian.org/git/collab-maint/pkg-iproute.git
fi
