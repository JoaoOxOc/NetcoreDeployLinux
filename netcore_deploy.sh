#!/bin/bash

source $(dirname "$0")/utils.sh
source $(dirname "$0")/ftp_gest.sh
source $(dirname "$0")/netcore_mngmt.sh

touch netcore_deploy_debug.txt

function initialCheck () {
	currentUser=$(whoami)
	if ! isRoot; then
		echo "Sorry, this wiil run as root..."
		[ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"
	fi
	checkOS

	echo 'It will install the Dialog app for script interface...'
	echo $OS
        if [ "$OS"=="debian8" ] || [ "$OS"=="debian9" ] || [ "$OS"=="mint" ] || [ "$OS"=="ubuntu" ] ; then
        	dpkg -s dialog &> netcore_deploy_debug.txt
        	if [ $? != 0 ]
	        then
	        	apt-get install dialog | tee -a netcore_deploy_debug.txt
		fi
        elif [ "$OS"=="fedora" ]
        then
		rpm -qa | grep dialog &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
			dnf install dialog | tee -a netcore_deploy_debug.txt
        	fi
	elif [ "$OS"=="centos" ] || [ "$OS"=="redhat" ]
        then
		rpm -qa | grep dialog &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        yum install dialog | tee -a netcore_deploy_debug.txt
                fi
        elif [ "$OS"=="arch" ]
        then
		pacman -Qi dialog &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        pacman -S dialog | tee -a netcore_deploy_debug.txt
                fi
        fi

}

function configureApache () {
	local opt

	echo ' '

	echo 'Do you wish to configure the base options for Apache2?[Y/N]'
	read opt
	if [ "$opt" == "Y" ] || [ "$opt" == "y" ] ; then
		echo 'Configuring apache mods for proxing and SSL...'
		sudo a2enmod rewrite
		sudo a2enmod proxy
		sudo a2enmod proxy_http
		sudo a2enmod proxy_html
		sudo a2enmod headers
		sudo a2enmod ssl
		a2enmod proxy_wstunnel

		echo ' '
		echo 'Testing apache2 config files...'
		apachectl configtest
		echo 'Restarting apache2...'
		apachectl restart
	fi
}

function installApache () {
	local k
	
	echo ' '
	echo 'Checking if apache 2 is installed...'

	if [ "$OS"=="debian8" ] || [ "$OS"=="debian9" ] || [ "$OS"=="mint" ] || [ "$OS"=="ubuntu" ] ; then
                dpkg -s apache2 &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        apt-get install apache2 -y | tee -a netcore_deploy_debug.txt
			if [ $? != 0 ]
                        then
                                echo "Error installing apache2. Check logs (cat -f netcore_deploy_debug.txt)"
                                sucesso=0
                        else
                                echo ' '
                                echo "Apache2 successfully installed"
                                echo ' '
				configureApache
                        fi
                else
			echo 'Apache2 already installed'
			configureApache
		fi
        elif [ "$OS" == "fedora" ]
        then
                rpm -qa | grep apache2 &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        dnf install apache2 -y | tee -a netcore_deploy_debug.txt
                	if [ $? != 0 ]
                        then
                                        echo "Error installing apache2. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "Apache2 successfully installed"
                                        echo ' '
				configureApache
                        fi
		else
                        echo 'Apache2 already installed'
			configureApache
		fi
        elif [ "$OS" == "centos" ] || [ "$OS"=="redhat" ]
        then
                rpm -qa | grep apache2 &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        yum install apache2 -y | tee -a netcore_deploy_debug.txt
                	if [ $? != 0 ]
                        then
                                        echo "Error installing apache2. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "Apache2 successfully installed"
                                        echo ' '
				configureApache
                        fi
		else
                        echo 'Apache2 already installed'
			configureApache
		fi
        elif [ "$OS" == "arch" ]
        then
                pacman -Qi apache2 &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        pacman -S apache2 -y | tee -a netcore_deploy_debug.txt
                	if [ $? != 0 ]
                        then
                                        echo "Error installing apache2. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "Apache2 successfully installed"
                                        echo ' '
				configureApache
                        fi
		else
                        echo 'Apache2 already installed'
			configureApache
		fi
        fi

	echo ' '
	echo 'Press any key to go back to main menu'
	read k
}


function newApacheVirtualHost () {
	local k
        local user
        local baseConfDir="/etc/apache2/sites-available"
	local baseConfDir2="/etc/apache2/sites-enabled"
        local serverName
        local baseAppDir="/var/www"
        local appDir=
	local checkAppDirExists=1
        local checkConfFileExists=1
        local lowerDllName
	local user
	local checkUserExists=0

        echo '#####################################################################################################################'
        echo '#                                         new Apache 2 virtual host '
        echo '#####################################################################################################################'

        echo "# every virtual host defined through this script will be stored in $baseConfDir directory"

	echo ' '
	echo "# the app will be stored in $baseAppDir directory"

        echo ' '
        echo "# The conf file name will be the server name defined for the virtual host"
        echo '#####################################################################################################################'

	while [ $checkUserExists -eq 0 ]
        do
                echo ' '
                echo '::: FTP User that will have permissions to upload app to virtual host:'
                read user
                checkUserExists=$(userExists $user)
                if [ $checkUserExists -eq 0 ]
                then
                        echo "   the user '$user' does not exists. Insert a valid one"
                fi
        done

	while [ $checkAppDirExists -eq 1 ]
        do
                echo ' '
                echo '::: App directory (only the name, not full path to):'
                read appDir

                checkAppDirExists=$(dirExists "$baseAppDir/$appDir")
                if [ $checkAppDirExists -eq 1 ]
                then
                        echo "   The directory '$baseAppDir/$appDir' already exists. Change '$appDir' to another name"
                fi
        done

	while [ $checkConfFileExists -eq 1 ]
        do
                echo ' '
                echo '::: server name (FQDN - DNS name):'
                read serverName

                checkConfFileExists=$(fileExists "$baseConfDir/$serverName.conf")
                if [ $checkConfFileExists -eq 1 ]
                then
                        echo "   The conf file '$baseConfDir/$serverName.conf' already exists. Change '$serverName' to another name"
                fi
        done

	echo ' '
	echo "# Creating app directory '$baseAppDir/$appDir' and applying permissions..."
	mkdir $baseAppDir/$appDir
	setfacl -R -m u:$user:rwx $baseAppDir/$appDir | tee -a netcore_deploy_debug.txt

	echo ' '
        echo "# Now, upload app content to $baseAppDir/$appDir before continue (maybe through FTP)"
        echo '::: Press any key after upload finishes to continue'
        read k

	echo ' '
	echo "# Applying permissions to '$baseAppDir/$appDir'..."
	setfacl -R -m u:www-data:rwx $baseAppDir/$appDir | tee -a netcore_deploy_debug.txt

	chmod -R 2750 $baseAppDir/$appDir | tee -a netcore_deploy_debug.txt

	echo ' '
	echo "# Creating $baseConfDir/$serverName.conf..."
	touch $baseConfDir/$serverName.conf

	echo -e "<VirtualHost *:80>" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "DocumentRoot \"$baseAppDir/$appDir\"" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "ServerName $serverName" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "<Directory \"$baseAppDir/$appDir\">" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "Require all granted" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "</Directory>" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "</VirtualHost>" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

	cat $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

	cp $baseConfDir/$serverName.conf $baseConfDir2/$serverName.conf | tee -a netcore_deploy_debug.txt

	echo ' '
	echo '# Testing config files of apache...'
	apachectl configtest | tee -a netcore_deploy_debug.txt
	if [ $? -eq 0 ]
	then
		echo ' '
		echo '# Reloading apache2 to apply new virtual host...'
		apachectl graceful | tee -a netcore_deploy_debug.txt

		echo '# if necessary, map the server name in /etc/hosts file (if you do not have DNS server):'
		echo "<server IP>	$serverName"
	else
		echo ' '
		echo "# error in $baseConfDir/$serverName.conf. Deleting everything..."

		rm -R $baseAppDir/$appDir
		rm $baseConfDir/$serverName.conf
		rm $baseConfDir2/$serverName.conf

		echo 'Check netcore_deploy_debug.txt for logs'
	fi

	echo ' '
	echo '# apache2 status'
	apachectl status | tee -a netcore_deploy_debug.txt

	echo ' '
        echo 'Press any key to go back to main menu'
        read k

}

function newApacheProxyVirtualHost () {
        local k
        local user
        local baseConfDir="/etc/apache2/sites-available"
        local baseConfDir2="/etc/apache2/sites-enabled"
        local serverName
        local netCoreAppAddress="127.0.0.1"
        local netCoreAppPort
        local baseAppDir="/var/www"
        local appDir=
        local checkAppDirExists=0
        local checkConfFileExists=1
        local lowerDllName
        local user
        local checkUserExists=0
	local checkPortFree=1
	local checkPortIsNumber=0
        local checkPortFree=0
        local checkPortInRange=0

        echo '#####################################################################################################################'
        echo '#                                         new Apache 2 proxy virtual host for NET core apps'
        echo '#####################################################################################################################'

        echo "# every virtual host defined through this script will be stored in $baseConfDir directory"

        echo ' '
        echo "# The conf file name will be the server name defined for the virtual host"
        echo '#####################################################################################################################'

	while [ $checkPortIsNumber -eq 0 ] || [ $checkPortFree -eq 1 ] || [ $checkPortInRange -eq 0 ]
        do
                echo ' '
                echo '::: NET core App kestrel port:'
                read netCoreAppPort

                checkPortIsNumber=$(isNumber $netCoreAppPort)
                if [ $checkPortIsNumber -eq 1 ]
                then
                        checkPortInRange=$(portInRange $netCoreAppPort)
                        if [ $checkPortInRange -eq 1 ]
                        then
                                checkPortFree=$(is_port_free $netCoreAppPort)
                                if [ $checkPortFree -eq 1 ]
                                then
                                        echo "   The port '$appPort' is not in use. Please check that the NET core app is running."
                                fi
                        else
                                echo "   The NET core App kestrel port must be between 1 and 65536."
                        fi
                else
                        echo "   The NET core App kestrel port must be a numeric value."
                fi
        done

        while [ $checkAppDirExists -eq 0 ]
        do
                echo ' '
                echo '::: NET core App directory (only the name, not full path to):'
                read appDir

                checkAppDirExists=$(dirExists "$baseAppDir/$appDir")
                if [ $checkAppDirExists -eq 0 ]
                then
                        echo "   The directory '$baseAppDir/$appDir' does not exist. Change '$appDir' to another name"
                fi
        done

        while [ $checkConfFileExists -eq 1 ]
        do
                echo ' '
                echo '::: server name (FQDN - DNS name):'
                read serverName

                checkConfFileExists=$(fileExists "$baseConfDir/$serverName.conf")
                if [ $checkConfFileExists -eq 1 ]
                then
                        echo "   The conf file '$baseConfDir/$serverName.conf' already exists. Change '$serverName' to another name"
                fi
        done

        echo ' '
        echo "# Creating $baseConfDir/$serverName.conf..."
        touch $baseConfDir/$serverName.conf

        echo -e "<VirtualHost *:*>" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
        echo -e "RequestHeader set \"X-Forwarded-Proto\" expr=%{REQUEST_SCHEME}" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "</VirtualHost>\n" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "<VirtualHost *:80>">> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "ProxyPreserveHost On" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

	echo -e "ProxyPass / http://$netCoreAppAddress:$netCoreAppPort/" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
        echo -e "ProxyPassReverse / http://$netCoreAppAddress:$netCoreAppPort/" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
        echo -e "ServerName $serverName" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

	echo -e "RewriteEngine on" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "RewriteCond %{HTTP:UPGRADE} ^WebSocket\$ [NC]" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "RewriteCond %{HTTP:CONNECTION} Upgrade\$ [NC]" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
	echo -e "RewriteRule /(.*) ws://$netCoreAppAddress:$netCoreAppPort/\$1 [P]" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

	echo -e "ErrorLog ${APACHE_LOG_DIR}$appDir-error.log" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
        echo -e "CustomLog ${APACHE_LOG_DIR}$appDir-access.log common" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt
        echo -e "</VirtualHost>" >> $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

        cat $baseConfDir/$serverName.conf | tee -a netcore_deploy_debug.txt

        cp $baseConfDir/$serverName.conf $baseConfDir2/$serverName.conf | tee -a netcore_deploy_debug.txt

        echo ' '
        echo '# Testing config files of apache...'
        apachectl configtest | tee -a netcore_deploy_debug.txt
        if [ $? -eq 0 ]
        then
                echo ' '
                echo '# Reloading apache2 to apply new virtual host...'
                apachectl graceful | tee -a netcore_deploy_debug.txt

                echo '# if necessary, map the server name in /etc/hosts file (if you do not have DNS server):'
                echo "<server IP>       $serverName"
        else
                echo ' '
                echo "# error in $baseConfDir/$serverName.conf. Deleting everything..."

                rm $baseConfDir/$serverName.conf
		rm $baseConfDir2/$serverName.conf

                echo 'Check netcore_deploy_debug.txt for logs'
        fi

        echo ' '
        echo '# apache2 status'
        apachectl status | tee -a netcore_deploy_debug.txt

        echo ' '
        echo 'Press any key to go back to main menu'
        read k
}

#main menu
initialCheck
op=-0
while [ $op != 0 ]
do

	op=$( dialog --stdout --menu 'NET Core deploy with Apache2' 0 0 0 \
	a 'Install Apache2'	\
	b 'Install FTP Server'	\
	c 'Install NET core 2'	\
	d 'Deploy new NET core app'	\
	e 'Generate apache virtual host'	\
	f 'Generate apache virtual host proxy for NET core app'	\
	g 'Verify NET core app logs'	\
	h 'Stop NET core app'	\
	i 'Start NET core app'	\
	j 'Delete NET core app'	\
	k 'Configure FTP share'	\
	0 'Exit')

	case $op in
	a) clear
	installApache
	;;
	b) clear
	installFtpServer
	;;
	c) clear
	installNetcore
	;;
	d) clear
	deployNetcoreApp
	;;
	e) clear
	newApacheVirtualHost
	;;
	f) clear
	newApacheProxyVirtualHost
	;;
	g) clear
	checkNetcoreLogging
	;;
	h) clear
	stopNetcoreApp
	;;
	i) clear
	startNetcoreApp
	;;
	j) clear
	deleteNetcoreApp
	;;
	k) clear
	addFtpShare
	;;
	0) clear
	;;
	esac

done
