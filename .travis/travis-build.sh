#!/bin/bash -e
#  This file is part of cc-oci-runtime.
#
#  Copyright (C) 2016 Intel Corporation
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

./autogen.sh

# We run the travis script from an exploded `make dist` tarball to ensure
# `make dist` has the necessary files to compile and run the tests.
#
# Note: we don't use `make distcheck` here as we can't run everything we want
#       for distcheck in travis.
# Note: chronic is used to limit the travis output while still showing it if
# the command fails.
chronic make dist
tarball=`ls -1 cc-oci-runtime-*.tar.xz`
chronic tar xvf "$tarball"
tarball_dir=${tarball%.tar.xz}

# We run configure and make check in an exploded make dist tarball to make sure
# we distribute the necessary files for both building and testing.
# We also do an out of tree build to check srcdir vs builddir discrepancy.
mkdir travis_build
(cd travis_build && \
 ../"$tarball_dir"/configure \
     --sysconfdir=/etc --localstatedir=/var --prefix=/usr \
     --enable-cppcheck \
     --enable-valgrind --disable-valgrind-helgrind --disable-valgrind-drd \
     --disable-silent-rules \
     --disable-docker-tests \
 && make -j5 CFLAGS=-Werror \
 && make check)

# go checks
export go_packages=$(go list ./... | grep -v cc-oci-runtime/vendor |\
    sed -e 's#.*/cc-oci-runtime/#./#')

go list -f '{{.Dir}}/*.go' $go_packages |\
    xargs -I % bash -c "misspell -error %"
go vet $go_packages
go list -f '{{.Dir}}' $go_packages |\
    xargs gofmt -s -l | wc -l |\
    xargs -I % bash -c "test % -eq 0"

for p in $go_packages; do golint -set_exit_status $p; done
