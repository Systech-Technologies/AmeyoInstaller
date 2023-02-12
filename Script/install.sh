#!/bin/bash

hello_world () {
   echo 'hello, world'
}

for package in `cat ../Packages/package.list`
do
   echo "Package : $package"
done

