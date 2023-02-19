#!/bin/bash


#Paths
tmp_file_path=./tmp
package_tmp_path=./Packages/package.tmp
package_version=./Packages/package.version
repository_dir=./Packages/Repository
service_status=$tmp_file_path/service.status

art_hibernate_prop=/dacx/var/ameyo/dacxdata/ameyo.art.product/conf/hibernate.properties
art_ini=/dacx/var/ameyo/dacxdata/ameyo.art.product/conf/AmeyoART.ini

server_hibernate_prop=/dacx/var/ameyo/dacxdata/com.drishti.dacx.server.product/conf/hibernate.properties

pg_hba_conf=/var/lib/pgsql/10/data/pg_hba.conf
psql_conf=/ameyo_mnt/var_pgsql/pgsql/10/data/postgresql.conf

service_check () {
   service=$1
   ameyoctl service $service status > $service_status
   grep NOT_RUNNING $service_status
   status=$?
   if [[ $status -eq 0 ]];then
      ameyoctl service $service restart
   else
      grep RUNNING $service_status
   fi

}

apply_patch () {
   service=$1
   if [[ "$service" == "asterisk13" ]]; then
      ls -al /usr/lib64/libcrypto.so.1.0.0
      status=$?
      if [[ $status -ne 0 ]];then
         ln -s /usr/lib64/libcrypto.so /usr/lib64/libcrypto.so.1.0.0
         ls -al /usr/lib64/libcrypto.so.1.0.0
      fi
      ls -al /usr/lib64/libssl.so.1.0.0
      status=$?
      if [[ $status -ne 0 ]];then
         ln -s  /usr/lib64/libssl.so  /usr/lib64/libssl.so.1.0.0
         ls -al /usr/lib64/libssl.so.1.0.0
      fi
   fi
   if [[ "$service" == "ameyo-art" ]]; then
      createdb -U postgres art_configuration_db
      createdb -U postgres reportsdb
      sed -i -e "/^hibernate.connection.url/s/ameyo_archiver_db/art_configuration_db/" $art_hibernate_prop
      sed -i -e "/^archiverSourceDbUrl/s/127.0.0.1/localhost/" $art_ini
      sed -i -e "/^archiverDestinationDbUrl/s/127.0.0.1/localhost/" $art_ini
   fi
   if [[ "$service" == "appserver" ]]; then
      sed -i -e "/^hibernate.connection.url/s/oneproduct/ameyodb/" $server_hibernate_prop
   fi
   if [[ "$service" == "postgresql" ]]; then
         /usr/pgsql-10/bin/postgresql-10-setup initdb
         updatedb
         sed -i -e "/^host/s/ident/trust/" $pg_hba_conf
         sed -i -e "/^local/s/peer/trust/" $pg_hba_conf

         sed -i -e "/^#listen_addresses/s/#//" $psql_conf
         sed -i -e "/^listen_addresses/s/localhost/*/" $psql_conf
         sed -i -e "/^max_connections/s/100/700/" $psql_conf
         systemctl restart postgresql-10.service
         ameyoctl confmanager postgres -cas
         createdb -U postgres ameyodb
   fi
   
}

check_package () {
   rpm -qa |grep "$1" > $package_tmp_path
   status=$?
   if [[ $status -eq 0 ]];
   then
      grep "$1" $package_version >> $package_tmp_path
      cat $package_tmp_path |sort -r |head -1
      latest_version=`cat $package_tmp_path |sort -r |head -1`
      #if [[ "$1" == *"$latest_version"* ]]; then
      if grep -q "$1" <<< "$latest_version"; then
         echo "Package: $1 | version is up to date"
      else
         echo "Package: $1 | has an updated version"
         sshpass -p "$2" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2242 haseebkc@ccu.systech.ae:/dacx/Ameyo_package/$latest_version $repository_dir
         FILE=$repository_dir/$latest_version
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
      if grep -q "ameyo-zabbix" <<< "$package"; then
         zabbix_agent=`rpm -qa |grep zabbix-agent`
         rpm -e $zabbix_agent
      fi
      grep "$1" $package_version > $package_tmp_path
      cat $package_tmp_path |sort -r |head -1
      latest_version=`cat $package_tmp_path |sort -r |head -1`
      echo $latest_version
      sshpass -p "$2" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 2242 haseebkc@ccu.systech.ae:/dacx/Ameyo_package/$latest_version $repository_dir
      du -sch $repository_dir/$latest_version

      FILE=$repository_dir/$latest_version
         FILE=$repository_dir/$latest_version
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

gen_banner () {

echo "";echo "";echo ""
echo $1
echo "";echo "";echo ""
}
gen_header () {

echo "";echo "";echo ""
echo $1
echo "";echo "";echo ""
}
gen_info () {

echo "";echo "";echo ""
echo $1
echo "";echo "";echo ""
}



gen_banner " --- Welcome to Ameyo Package Installer Script --- "

gen_header " ----- !!!!!      Generating the Latest Package List      !!!!! ----- "

gen_info " Please enter the Repository Server Password : "


#password='*******'

stty -echo
read -p "Password: " password; echo
stty echo
sshpass -p "$password" ssh -p 2242 haseebkc@ccu.systech.ae -q -o "StrictHostKeyChecking no" "cd /dacx/Ameyo_package;ls" > $package_version

for package in `cat ./Packages/package.list`
do
   echo "Package : $package"
   if grep -q "postgres" <<< "$package"; then
      echo "Fresh Install ?  initilize DB ?(Y/N)"
      read -p "initilize DB ?(Y/N): " dbresp; echo
      if [[ "$dbresp" == "Y" ]]; then
         apply_patch postgresql
         service_check postgresql

         ameyoctl service postgresql status
      fi
   else
      #zabbix_agent=`rpm -qa |grep zabbix-agent`

      check_package "$package" "$password"
      if grep -q "ameyo-server" <<< "$package"; then
         apply_patch appserver
         service_check appserver
      fi
      if grep -q "ameyo-djinn" <<< "$package"; then
         systemctl start djinn.service
         systemctl status djinn.service
      fi
      if grep -q "ameyocrm" <<< "$package"; then
         service_check asterisk13
      fi
      if grep -q "acp" <<< "$package"; then
         service_check acp
      fi
      if grep -q "asterisk13" <<< "$package"; then
         apply_patch asterisk13
         service_check asterisk13
      fi
      if grep -q "ameyo-art" <<< "$package"; then
         apply_patch ameyo-art
         service_check asterisk13
      fi
      if grep -q "ameyo-zabbix" <<< "$package"; then
         apply_patch ameyo-zabbix
         #service_check asterisk13
      fi

      
   fi
   echo " ---- Completed : $package ----- "
   echo " ---- Press Enter to continue ----- "
   read next
done

