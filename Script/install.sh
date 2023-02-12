#!/bin/bash

check_package () {
   rpm -qa |grep "$1"
   status=$?
   if [[ $status -eq 0 ]];
   then
      echo "command successful"
   else
      echo "command unsuccessful"
   fi
}

for package in `cat ./Packages/package.list`
do
   echo "Package : $package"
   check_package "$package"
done

