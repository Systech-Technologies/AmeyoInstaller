#!/bin/bash

check_package () {
   rpm -qa |grep "$1" > ./Packages/package.tmp
   status=$?
   if [[ $status -eq 0 ]];
   then
      grep "$1" ./Packages/package.version >> ./Packages/package.tmp
      cat ./Packages/package.tmp |sort -r |head -1
      latest_version=`cat ./Packages/package.tmp |sort -r |head -1`
      #if [[ "$1" == *"$latest_version"* ]]; then
      if grep -q "$1" <<< "$latest_version"; then
         echo "Package: $1 | version is up to date"
      else
         echo "Package: $1 | has an updated version"
         sshpass -p "$2" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2242 haseebkc@ccu.systech.ae:/dacx/Ameyo_package/$latest_version ./Packages/Repository
         FILE=./Packages/Repository/$latest_version
         if [ -f "$FILE" ]; then
            rpm -Uvh $FILE
            rpm -qa |grep "$1"
            status=$?
            if [[ $status -eq 0 ]];then
               echo "Package: $1 | Package Updated"
            fi
         fi
      fi
   else
      echo "Package: $1 | Not yet installed |pulling the Package"
      grep "$1" ./Packages/package.version > ./Packages/package.tmp
      cat ./Packages/package.tmp |sort -r |head -1
      latest_version=`cat ./Packages/package.tmp |sort -r |head -1`
      sshpass -p "$2" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2242 haseebkc@ccu.systech.ae:/dacx/Ameyo_package/$latest_version ./Packages/Repository
      FILE=./Packages/Repository/$latest_version
         FILE=./Packages/Repository/$latest_version
         if [ -f "$FILE" ]; then
            rpm -Uvh $FILE
            rpm -qa |grep "$1"
            status=$?
            if [[ $status -eq 0 ]];then
               echo "Package: $1 | Package Installed"
            fi
         fi
   fi
}

echo "Generating the Latest Package List"

echo " Please enter the Repository Server Password"
read password
#password='*******'
sshpass -p "$password" ssh -p 2242 haseebkc@ccu.systech.ae -q -o "StrictHostKeyChecking no" "cd /dacx/Ameyo_package;ls" > ./Packages/package.version

for package in `cat ./Packages/package.list`
do
   echo "Package : $package"
   if grep -q "postgres" <<< "$package"; then
      echo "Fresh Install ?  initilize DB ?(Y/N)"
      read dbresp
      if [[ "$dbresp" == "Y" ]]; then
         /usr/pgsql-10/bin/postgresql-10-setup initdb
         updatedb
         sed -i -e "/^host/s/ident/trust/" /var/lib/pgsql/10/data/pg_hba.conf
         sed -i -e "/^local/s/peer/trust/" /var/lib/pgsql/10/data/pg_hba.conf

         sed -i -e "/^#listen_addresses/s/#//" /ameyo_mnt/var_pgsql/pgsql/10/data/postgresql.conf
         sed -i -e "/^listen_addresses/s/localhost/*/" /ameyo_mnt/var_pgsql/pgsql/10/data/postgresql.conf
         sed -i -e "/^max_connections/s/100/700/" /ameyo_mnt/var_pgsql/pgsql/10/data/postgresql.conf
         systemctl restart postgresql-10.service
         ameyoctl confmanager postgres -cas
         createdb -U postgres ameyodb

         
         ameyoctl service postgresql status
      fi
   else
      check_package "$package" "$password"
      if grep -q "ameyo-server" <<< "$package"; then
         sed -i -e "/^hibernate.connection.url/s/oneproduct/ameyodb/" /dacx/var/ameyo/dacxdata/com.drishti.dacx.server.product/conf/hibernate.properties
      fi
      if grep -q "ameyo-djinn" <<< "$package"; then
         systemctl start djinn.service
         systemctl status djinn.service
      fi
      if grep -q "asterisk13" <<< "$package"; then
         ameyoctl service asterisk13 restart
         ameyoctl service asterisk13 status
      fi
      if grep -q "ameyo-art" <<< "$package"; then
         createdb -U postgres art_configuration_db
         createdb -U postgres reportsdb
         sed -i -e "/^hibernate.connection.url/s/ameyo_archiver_db/art_configuration_db/" /dacx/var/ameyo/dacxdata/ameyo.art.product/conf/hibernate.properties
         sed -i -e "/^archiverSourceDbUrl/s/127.0.0.1/localhost/" /dacx/var/ameyo/dacxdata/ameyo.art.product/conf/AmeyoART.ini
         sed -i -e "/^archiverDestinationDbUrl/s/127.0.0.1/localhost/" /dacx/var/ameyo/dacxdata/ameyo.art.product/conf/AmeyoART.ini
         ameyoctl service ameyoart start

      fi
      
   fi
   echo " ---- Completed : $package ----- "
   echo " ---- Press Enter to continue ----- "
   read next
done

