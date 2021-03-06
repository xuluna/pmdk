#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2016-2019, Intel Corporation

#
# run-build-package.sh - is called inside a Docker container; prepares
#                        the environment and starts a build of PMDK project.
#

set -e

# Prepare build enviromnent
./prepare-for-build.sh

# Create fake tag, so that package has proper 'version' field
git config user.email "test@package.com"
git config user.name "test package"
git tag -a 1.4.99 -m "1.4" HEAD~1 || true

# Build all and run tests
cd $WORKDIR
export PCHECK_OPTS=-j2
make -j$(nproc) $PACKAGE_MANAGER

# Install packages
if [[ "$PACKAGE_MANAGER" == "dpkg" ]]; then
	cd $PACKAGE_MANAGER
	echo $USERPASS | sudo -S dpkg --install *.deb
else
	cd $PACKAGE_MANAGER/x86_64
	echo $USERPASS | sudo -S rpm --install *.rpm
fi

# Compile and run standalone test
cd $WORKDIR/utils/docker/test_package
make -j$(nproc) LIBPMEMOBJ_MIN_VERSION=1.4
./test_package testfile1

# Use pmreorder installed in the system
pmreorder_version="$(pmreorder -v)"
pmreorder_pattern="pmreorder\.py .+$"
(echo "$pmreorder_version" | grep -Ev "$pmreorder_pattern") && echo "pmreorder version failed" && exit 1

touch testfile2
touch logfile1
pmreorder -p testfile2 -l logfile1
