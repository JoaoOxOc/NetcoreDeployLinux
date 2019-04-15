#!/bin/bash

function configureVsftpd {
	local k
	local user
	local checkUserExists=0

	echo 'Do you wish to configure the base options for VSFTPD?[Y/N]'
        read opt
        if [ "$opt" == "Y" ] || [ "$opt" == "y" ] ; then
		echo ' '
		echo '# Allowing users to write inside /var/www...'
		sed -i -e "s|#local_enable=YES|local_enable=YES|g" /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt

		sed -i -e "s|#write_enable=YES|write_enable=YES|g" /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt

		echo -e "pasv_min_port=40000" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		echo -e "pasv_max_port=50000" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt

		echo ' '
		echo '# Users will only be able to access their folders inside /var/www...'
		sed -i -e "s|#chroot_local_user=YES|chroot_local_user=YES|g" /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		echo -e "anon_mkdir_write_enable=YES" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		echo -e "allow_writeable_chroot=YES" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt


		echo ' '
		echo '# Applying users list permitted logic...'
		
		#echo -e "userlist_enable=YES" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		#echo -e "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		#echo -e "userlist_deny=NO" >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt
		#touch /etc/vsftpd.userlist | tee -a netcore_deploy_debug.txt

		echo -e "user_config_dir=/etc/vsftpd_user_conf"  >> /etc/vsftpd.conf | tee -a netcore_deploy_debug.txt

		mkdir /etc/vsftpd_user_conf

		while [ $checkUserExists -eq 0 ]
	        do
        	        echo ' '
                	echo '::: Admin User that will have permissions to /var/www (the OS admin user for example):'
                	read user
                	checkUserExists=$(userExists $user)
                	if [ $checkUserExists -eq 0 ]
                	then
                        	echo "   the user '$user' does not exists. Insert a valid one"
                	fi
        	done

                echo 'Permitting $user in /var/www through FTP...'
		touch /etc/vsftpd_user_conf/$user
		setfacl -R -m u:$user:rwx /var/www | tee -a netcore_deploy_debug.txt

		echo 'Enable writting in /var/www for $user...'
		echo -e "local_root=/var/www" >> /etc/vsftpd_user_conf/$user | tee -a netcore_deploy_debug.txt

                echo ' '
                echo '# Config applied in /etc/vsftpd.conf. Verify the file if you need to'
                echo '# https://serverfault.com/questions/544850/create-new-vsftpd-user-and-lock-to-specify-home-login-directory'
                echo '# Restarting VSFTPD...'
                systemctl restart vsftpd | tee -a netcore_deploy_debug.txt
		if [ $? -eq 0 ]
        	then
                	echo ' '
                	echo '# VSFTPD base config applied'
        	else
                	echo ' '
                	echo "# error in /etc/vsftpd.conf. Verify logs (cat netcore_deploy_debug.txt)"
        	fi
        fi
}

function installFtpServer () {
	local k

	echo ' '
        echo 'Checking if VSFTPD is installed...'

        if [ "$OS"=="debian8" ] || [ "$OS"=="debian9" ] || [ "$OS"=="mint" ] || [ "$OS"=="ubuntu" ] ; then
                dpkg -s vsftpd &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        apt-get install vsftpd -y | tee -a netcore_deploy_debug.txt
                        if [ $? != 0 ]
                        then
                                        echo "Error installing VSFTPD. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "VSFTPD successfully installed"
                                        echo ' '
					configureVsftpd
                        fi
                else
                        echo 'VSFTPD already installed'
                        configureVsftpd
                fi
	elif [ "$OS" == "fedora" ]
        then
                rpm -qa | grep vsftpd &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        dnf install vsftpd -y | tee -a netcore_deploy_debug.txt
                        if [ $? != 0 ]
                        then
                                        echo "Error installing VSFTPD. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "VSFTPD successfully installed"
                                        echo ' '
                                        configureVsftpd
                        fi
                else
                        echo 'VSFTPD already installed'
                        configureVsftpd
                fi
        elif [ "$OS" == "centos" ] || [ "$OS"=="redhat" ]
        then
                rpm -qa | grep vsftpd &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        yum install vsftpd -y | tee -a netcore_deploy_debug.txt
                        if [ $? != 0 ]
                        then
                                        echo "Error installing VSFTPD. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "VSFTPD successfully installed"
                                        echo ' '
                                        configureVsftpd
                        fi
                else
                        echo 'VSFTPD already installed'
                        configureVsftpd
                fi
	elif [ "$OS" == "arch" ]
        then
                pacman -Qi vsftpd &> netcore_deploy_debug.txt
                if [ $? != 0 ]
                then
                        pacman -S vsftpd -y | tee -a netcore_deploy_debug.txt
                        if [ $? != 0 ]
                        then
                                        echo "Error installing VSFTPD. Check logs (cat -f netcore_deploy_debug.txt)"
                                        sucesso=0
                        else
                                        echo ' '
                                        echo "VSFTPD successfully installed"
                                        echo ' '
                                        configureVsftpd
                        fi
                else
                        echo 'VSFTPD already installed'
                        configureVsftpd
                fi
	fi

	echo ' '
        echo 'Press any key to go back to main menu'
        read k
}

function ftpShareAux() {
	echo "Permitting $3 in $1/$2..."
	mkdir $1/$2  | tee -a netcore_deploy_debug.txt
        touch /etc/vsftpd_user_conf/$3
        setfacl -R -m u:$3:rwx $1/$2 | tee -a netcore_deploy_debug.txt
	usermod -d $1/$2 $3

        echo "Enable writting in $1/$2 for $3 through FTP..."
        echo -e "local_root=$1/$2" >> /etc/vsftpd_user_conf/$3 | tee -a netcore_deploy_debug.txt

        echo ' '
        echo "# chroot Config applied in /etc/vsftpd_user_conf/$3 for $1/$2 directory. Verify the file if you need to"
        
        echo '# Restarting VSFTPD...'
        systemctl restart vsftpd | tee -a netcore_deploy_debug.txt
        if [ $? -eq 0 ]
        then
                echo ' '
                echo "# VSFTPD config applied for user $3"
        else
                echo ' '
                echo "# error in /etc/vsftpd_user_conf/$3. Verify logs (cat netcore_deploy_debug.txt)"
        fi
}

function addFtpShare () {
	local k
	local opt
	local newUser
	local user
        local checkUserExists=0
	local userDir
	local checkUserDirExists=1
	local baseUserDir="/var/www"

	while [ $checkUserExists -eq 0 ]
        do
                echo ' '
                echo '::: User that will have permissions for the shared folder inside /var/www/ directory:'
                read user
                checkUserExists=$(userExists $user)
                if [ $checkUserExists -eq 0 ]
                then
                        echo "# the user '$user' does not exists."
			echo "::: Do you wish to create $user through useradd $user command?[Y/N]"
        		read opt
        		if [ "$opt" == "Y" ] || [ "$opt" == "y" ] ; then
				useradd $user
				if [ $? -eq 0 ]
				then
					checkUserExists=1
					echo "::: Password for $user:"
					passwd $user
				fi
			fi
                fi
        done

	while [ $checkUserDirExists -eq 1 ]
        do
                echo ' '
                echo "::: User directory inside $baseUserDir (only the name, not full path to):"
                read userDir

                checkUserDirExists=$(dirExists "$baseUserDir/$userDir")
                if [ $checkUserDirExists -eq 1 ]
                then
                        echo "   The directory '$baseUserDir/$userDir' already exists. Change '$userDir' to another name"
                fi
        done
		
		ftpShareAux $baseUserDir $userDir $user
	
	echo ' '
        echo '::: Press any key to go back to main menu'
        read k
}
