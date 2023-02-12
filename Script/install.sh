#!/bin/bash

check_package () {
   rpm -qa |grep "$1"
   status=$?
   [ $status -eq 0 ] && echo "command successful" || echo "command unsuccessful"
}

for package in `cat ./Packages/package.list`
do
   echo "Package : $package"
   check_package "$package"
done

