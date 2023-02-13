#!/bin/bash

check_package () {
   rpm -qa |grep "$1" > ./Packages/package.tmp
   status=$?
   if [[ $status -eq 0 ]];
   then
      grep "$1" ./Packages/package.version >> ./Packages/package.tmp
      cat ./Packages/package.tmp |sort -r |head -1
      latest_version=`cat ./Packages/package.tmp |sort -r |head -1`
      if [[ "$1" == *$latest_version* ]]; then
         echo "Package: $1 | version is up to date"
      else
         echo "Package: $1 | has an updated version"
         sshpass -p "$2" scp -P 2242 haseebkc@ccu.systech.ae:/dacx/Ameyo_package/$latest_version ./Packages/Repository
         FILE=./Packages/Repository/$latest_version
         if [ -f "$FILE" ]; then
            rpm -Uvh $FILE
         fi
      fi
   else
      echo "command unsuccessful"
   fi
}

echo "Generating the Latest Package List"

echo " Please enter the Repository Server Password"
read password
sshpass -p "$password" ssh -p 2242 haseebkc@ccu.systech.ae -q -o "StrictHostKeyChecking no" "cd /dacx/Ameyo_package;ls" > ./Packages/package.version

for package in `cat ./Packages/package.list`
do
   echo "Package : $package"
   check_package "$package" "$password"
done

