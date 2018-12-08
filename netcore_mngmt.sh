#!/bin/bash

source $(dirname "$0")/utils.sh

function installNetcore () {
	local k
	local opt
	
	 if [ "$OS"=="debian8" ] || [ "$OS"=="debian9" ] || [ "$OS"=="mint" ] || [ "$OS"=="ubuntu" ] ; then
		echo ' '
		echo 'Getting microsoft signing keys...'
		wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg
		sudo mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
		
		if [ "$OS"=="mint" ] || [ "$OS"=="ubuntu" ] ; then
			wget -q https://packages.microsoft.com/config/ubuntu/18.04/prod.list | tee -a netcore_deploy_debug.txt
		elif [ "$OS"=="debian8" ]
		then
			wget -q https://packages.microsoft.com/config/debian/8/prod.list
		elif [ "$OS"=="debian9" ]
		then
			wget -q https://packages.microsoft.com/config/debian/9/prod.list
		fi
		sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list | tee -a netcore_deploy_debug.txt
		sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg | tee -a netcore_deploy_debug.txt
		sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list | tee -a netcore_deploy_debug.txt

		echo 'Installing NET core 2.1 runtime...'
		sudo apt-get install apt-transport-https -y | tee -a netcore_deploy_debug.txt
		if [ $? != 0 ]
        	then
            		echo "Error installing apt-transport-https. Check logs (cat -f netcore_deploy_debug.txt)"
            		sucesso=0
        	else
            		apt-get update -y
			apt-get install aspnetcore-runtime-2.1 -y | tee -a netcore_deploy_debug.txt
			if [ $? != 0 ]
            		then
                		echo "Error installing NET core runtime. Check logs (cat -f netcore_deploy_debug.txt)"
                		sucesso=0
        		else
                		echo ' '
				echo 'Installing NET core SDK...'
				apt-get install dotnet-sdk-2.1 -y | tee -a netcore_deploy_debug.txt
				if [ $? != 0 ]
                		then
                    			echo "Error installing NET core SDK. Check logs (cat -f netcore_deploy_debug.txt)"
                    			sucesso=0
                		else
                        		echo ' '
					echo 'NET core installed. Info:'
					dotnet --info | tee -a netcore_deploy_debug.txt
				fi

	        	fi

        	fi
	elif [ "$OS" == "fedora" ]
	then
		sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
		wget -q https://packages.microsoft.com/config/fedora/27/prod.repo
		sudo mv prod.repo /etc/yum.repos.d/microsoft-prod.repo
		sudo chown root:root /etc/yum.repos.d/microsoft-prod.repo
		
		sudo dnf update -y
		
		dnf install aspnetcore-runtime-2.1 -y | tee -a netcore_deploy_debug.txt
		if [ $? != 0 ]
		then
			echo "Error installing NET core runtime. Check logs (cat -f netcore_deploy_debug.txt)"
			sucesso=0
		else
			echo ' '
			echo 'Installing NET core SDK...'
			dnf install dotnet-sdk-2.1 | tee -a netcore_deploy_debug.txt
			if [ $? != 0 ]
			then
				echo "Error installing NET core SDK. Check logs (cat -f netcore_deploy_debug.txt)"
				sucesso=0
			else
				echo ' '
				echo 'NET core installed. Info:'
				dotnet --info | tee -a netcore_deploy_debug.txt
			fi

		fi
	elif [ "$OS"=="centos" ]
	then
		sudo rpm -Uvh https://packages.microsoft.com/config/rhel/7/packages-microsoft-prod.rpm | tee -a netcore_deploy_debug.txt
		
		sudo yum update -y
		
		yum install aspnetcore-runtime-2.1 -y | tee -a netcore_deploy_debug.txt
		if [ $? != 0 ]
		then
			echo "Error installing NET core runtime. Check logs (cat -f netcore_deploy_debug.txt)"
			sucesso=0
		else
			echo ' '
			echo 'Installing NET core SDK...'
			yum install dotnet-sdk-2.1 | tee -a netcore_deploy_debug.txt
			if [ $? != 0 ]
			then
				echo "Error installing NET core SDK. Check logs (cat -f netcore_deploy_debug.txt)"
				sucesso=0
			else
				echo ' '
				echo 'NET core installed. Info:'
				dotnet --info | tee -a netcore_deploy_debug.txt

			fi

		fi
	elif [ "$OS"=="redhat" ]
    then
		yum install rh-dotnet21 -y | tee -a netcore_deploy_debug.txt
		if [ $? != 0 ]
		then
			echo "Error obtaining NET core script. Check logs (cat -f netcore_deploy_debug.txt)"
			sucesso=0
		else
			echo ' '
			echo 'Running script...'
			scl enable rh-dotnet21 bash | tee -a netcore_deploy_debug.txt
			if [ $? != 0 ]
			then
				echo "Error installing NET core SDK. Check logs (cat -f netcore_deploy_debug.txt)"
				sucesso=0
			else
				echo ' '
				echo 'NET core installed. Info:'
				dotnet --info | tee -a netcore_deploy_debug.txt

			fi

		fi
	elif [ "$OS" == "arch" ]
    then
		echo 'Missing NET core installation code'
	fi

	echo ' '
    echo 'Press any key to go back to main menu'
    read k
}

function deployNetcoreApp () {
	local k
	local user
	local baseAppDir="/var/www"
	local appDir
	local dllName
	local appPort
	local baseServiceDir="/etc/systemd/system"
	local checkUserExists=0
	local checkPortIsNumber=0
	local checkPortFree=0
	local checkPortInRange=0
	local checkSysFileExists=1
	local checkAppDirExists=1
	local lowerDllName

	echo '#####################################################################################################################'
	echo '#						new NET core app runtime '
	echo '#####################################################################################################################'

	echo "# every app defined through this script will be stored in $baseAppDir directory"
	echo "# The selected user to run the app will have full permissions for the app directory created inside /var/www"

	echo ' '
	echo "# The bootable service for the app will be created inside $baseServiceDir with the name 'kestrel-<DLL name>.service'"
	echo '#####################################################################################################################'
	while [ $checkUserExists -eq 0 ]
	do
		echo ' '
		echo '::: User that will have permissions to run the NET core app:'
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

	while [ $checkSysFileExists -eq 1 ]
	do
		echo ' '
		echo '::: DLL name that the NET core should start inside the app directory (without extension, only the name and case Sensitive):'
		read dllName
		lowerDllName=$(toLower $dllName)
		checkSysFileExists=$(fileExists "$baseServiceDir/kestrel-$lowerDllName.service")
		if [ $checkSysFileExists -eq 1 ]
                then
                        echo "   The file '$baseServiceDir/kestrel-$lowerDllName.service' already exists. Change '$dllName' (DLL name) to another name"
                fi
	done

	while [ $checkPortIsNumber -eq 0 ] || [ $checkPortFree -eq 0 ] || [ $checkPortInRange -eq 0 ]
	do
		echo ' '
		echo '::: App kestrel port (not in use) where the app should be available at localhost:'
		read appPort

		checkPortIsNumber=$(isNumber $appPort)
		if [ $checkPortIsNumber -eq 1 ]
		then
			checkPortInRange=$(portInRange $appPort)
			if [ $checkPortInRange -eq 1 ]
			then
				checkPortFree=$(is_port_free $appPort)
				if [ $checkPortFree -eq 0 ]
                		then
                        		echo "   The port '$appPort' is already in use. Please choose another port for the app."
                		fi
			else
				echo "   The App kestrel port must be between 1 and 65536."
			fi
		else
			echo "   The App kestrel port must be a numeric value."
		fi
	done

	echo ' '
	echo '# Input data completed. Applying new NET core app runtime config...'

	chmod -R 777 /home/$user/.dotnet/

	echo ' '
	echo "# Creating app directory '$baseAppDir/$appDir' and applying permissions to '$user'..."
	mkdir $baseAppDir/$appDir | tee -a netcore_deploy_debug.txt
	setfacl -R -m u:$user:rwx $baseAppDir/$appDir | tee -a netcore_deploy_debug.txt

	echo ' '
	echo "# Now, upload app content to $baseAppDir/$appDir before continue (maybe through FTP with the user '$user')"
	echo '::: Press any key after upload finishes to continue'
	read k

	echo ' '
	echo "# Creating app service file '$baseServiceDir/kestrel-$lowerDllName.service'..."
	touch $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "[Unit]\nDescription=NET core $dllName running on $OS\n" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "[Service]" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "WorkingDirectory=$baseAppDir/$appDir" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "ExecStart=/usr/bin/dotnet $baseAppDir/$appDir/$dllName.dll --urls \"http://localhost:$appPort\""  >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "Restart=always\n# Restart service after 10 seconds if the dotnet service crashes:\nRestartSec=10" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "KillSignal=SIGINT" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "SyslogIdentifier=dotnet-$dllName" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "User=$user" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "Environment=ASPNETCORE_ENVIRONMENT=Production" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false\n" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	echo -e "[Install]\nWantedBy=multi-user.target" >> $baseServiceDir/kestrel-$lowerDllName.service | tee -a netcore_deploy_debug.txt

	cat $baseServiceDir/kestrel-$lowerDllName.service

	echo ' '
	echo "# starting $dllName..."

	serviceName="kestrel-$lowerDllName.service"

	systemctl enable $baseServiceDir/kestrel-$lowerDllName.service

	systemctl start $serviceName

	systemctl status $serviceName

	echo ' '
	echo "# Check logs: sudo journalctl -fu $serviceName"

	echo ' '
        echo 'Press any key to go back to main menu'
        read k
}

function checkNetcoreLogging {
	local k
	local baseServiceDir="/etc/systemd/system"
	local dllName
        local checkSysFileExists=0
        local lowerDllName

	while [ $checkSysFileExists -eq 0 ]
        do
                echo ' '
                echo '::: DLL name (without extension, only the name and case Sensitive):'
                read dllName
                lowerDllName=$(toLower $dllName)
                checkSysFileExists=$(fileExists "$baseServiceDir/kestrel-$lowerDllName.service")
                if [ $checkSysFileExists -eq 0 ]
                then
                        echo "   The file 'baseServiceDir/kestrel-$lowerDllName.service' does not exist. Change '$dllName' (DLL name) to an existent NET core app"
                fi
        done

	serviceName="kestrel-$lowerDllName.service"

	systemctl status $serviceName

	journalctl -fu $serviceName

	echo ' '
        echo 'Press any key to go back to main menu'
        read k
}

function stopNetcoreApp () {
	local k
	local baseServiceDir="/etc/systemd/system"
        local dllName
        local checkSysFileExists=0
        local lowerDllName

        while [ $checkSysFileExists -eq 0 ]
        do
                echo ' '
                echo '::: DLL name (without extension, only the name and case Sensitive):'
                read dllName
                lowerDllName=$(toLower $dllName)
                checkSysFileExists=$(fileExists "$baseServiceDir/kestrel-$lowerDllName.service")
                if [ $checkSysFileExists -eq 0 ]
                then
                        echo "   The file 'baseServiceDir/kestrel-$lowerDllName.service' does not exist. Change '$dllName' (DLL name) to an existent NET core app"
                fi
        done

        serviceName="kestrel-$lowerDllName.service"

	echo ' '
	echo "# Stopping $dllName..."

	systemctl stop $serviceName

	kill $(ps aux | grep "$dllName.dll" | awk '{print $2}')

	systemctl status $serviceName

	echo ' '
        echo 'Press any key to go back to main menu'
        read k
}

function startNetcoreApp () {
	local k
	local baseServiceDir="/etc/systemd/system"
        local dllName
        local checkSysFileExists=0
        local lowerDllName

        while [ $checkSysFileExists -eq 0 ]
        do
                echo ' '
                echo '::: DLL name (without extension, only the name and case Sensitive):'
                read dllName
                lowerDllName=$(toLower $dllName)
                checkSysFileExists=$(fileExists "$baseServiceDir/kestrel-$lowerDllName.service")
                if [ $checkSysFileExists -eq 0 ]
                then
                        echo "   The file 'baseServiceDir/kestrel-$lowerDllName.service' does not exist. Change '$dllName' (DLL name) to an existent NET core app"
                fi
        done

        serviceName="kestrel-$lowerDllName.service"

        echo ' '
        echo "# Starting $dllName..."

        systemctl start $serviceName

        systemctl status $serviceName

        echo ' '
        echo 'Press any key to go back to main menu'
        read k

}

function deleteNetcoreApp () {
	local k
	local baseServiceDir="/etc/systemd/system"
	local dllName
        local checkSysFileExists=0
        local lowerDllName

        while [ $checkSysFileExists -eq 0 ]
        do
                echo ' '
                echo '::: DLL name (without extension, only the name and case Sensitive):'
                read dllName
                lowerDllName=$(toLower $dllName)
                checkSysFileExists=$(fileExists "$baseServiceDir/kestrel-$lowerDllName.service")
                if [ $checkSysFileExists -eq 0 ]
                then
                        echo "   The file 'baseServiceDir/kestrel-$lowerDllName.service' does not exist. Change '$dllName' (DLL name) to an existent NET core app"
                fi
        done

	serviceName="kestrel-$lowerDllName.service"

	echo "# Stopping $dllName..."

        systemctl stop $serviceName

        kill $(ps aux | grep "$dllName.dll" | awk '{print $2}')

        systemctl status $serviceName

	sudo rm /etc/systemd/system/$serviceName

	#sudo rm -R /var/www/

	echo ' '
        echo 'Press any key to go back to main menu'
        read k
}


