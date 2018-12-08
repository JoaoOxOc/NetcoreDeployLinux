#!/bin/bash

export OS=""
export currentUser=""

function toLower {
        echo "$1" | tr '[:upper:]' '[:lower:]'
}

function toUpper {
        echo "$1" | tr '[:lower:]' '[:upper:]'
}

function isRoot () {
        if [ "$EUID" -ne 0 ]; then
                return 1
        fi
}

function userExists {
        if id "$1" >/dev/null 2>&1; then
                echo 1
        else
                echo 0
        fi
}

function is_port_free {

        #netstat -ntpl | grep ${1:-8080} | tee -a netcore_deploy_debug.txt ;
        data=$(lsof -Pi :$1 -sTCP:LISTEN -t | tee -a netcore_deploy_debug.txt) #>/dev/null
        if [ -z $data ]
        then
                echo 1
        else
                echo 0
        fi
}

function portInRange {
        if [ $1 -gt 0 ] && [ $1 -lt 65537 ]
        then
                echo 1
        else
                echo 0
        fi
}

function fileExists {
        if [ -e $1 ]
        then
                echo 1
        else
                echo 0
        fi
}

function dirExists {
        if [ -d $1 ]
        then
                echo 1
        else
                echo 0
        fi
}

function isNumber {
        numberRegex='^[0-9]+$'
        if [[ $1 =~ $numberRegex ]]
        then
                echo 1
        else
                echo 0
        fi
}


function checkOS () {
        if [[ -e /etc/debian_version ]]; then
                OS="debian"
                source /etc/os-release

                if [[ "$ID" == "debian" ]]; then
                        OS="debian$VERSION_ID"
                        if [[ ! $VERSION_ID =~ (8|9) ]]; then
                                echo "⚠️ Your version of Debian is not supported."
                                echo ""
                                echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
                                echo "Keep in mind they are not supported, though."
                                echo ""
                                until [[ $CONTINUE =~ (y|n) ]]; do
                                        read -rp "Continue? [y/n]: " -e CONTINUE
                                done
                                if [[ "$CONTINUE" = "n" ]]; then
                                        exit 1
                                fi
                        fi
                elif [[ "$ID" == "ubuntu" ]];then
                        OS="ubuntu"
                        if [[ ! $VERSION_ID =~ (16.04|18.04) ]]; then
                                echo "⚠️ Your version of Ubuntu is not supported."
                                echo ""
                                echo "However, if you're using Ubuntu > 17 or beta, then you can continue."
                                echo "Keep in mind they are not supported, though."
                                echo ""
                                until [[ $CONTINUE =~ (y|n) ]]; do
                                        read -rp "Continue? [y/n]: " -e CONTINUE
                                done
                                if [[ "$CONTINUE" = "n" ]]; then
                                        exit 1
                                fi
                        fi
                elif [[ -d /etc/linuxmint ]]; then
                        OS=mint
                fi
        elif [[ -d /etc/linuxmint ]]; then
                OS=mint
        elif [[ -e /etc/redhat-release ]]; then
                OS=redhat
        elif [[ -e /etc/fedora-release ]]; then
                OS=fedora
	elif [[ -e /etc/centos-release ]]; then
                if ! grep -qs "^CentOS Linux release 7" /etc/centos-release; then
                        echo "Your version of CentOS is not supported."
                        echo "The script only support CentOS 7."
                        echo ""
                        unset CONTINUE
                        until [[ $CONTINUE =~ (y|n) ]]; do
                                read -rp "Continue anyway? [y/n]: " -e CONTINUE
                        done
                        if [[ "$CONTINUE" = "n" ]]; then
                                echo "Ok, bye!"
                                exit 1
                        fi
                fi
                OS=centos
        elif [[ -e /etc/arch-release ]]; then
                OS=arch
        else
                echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS, Mint, Red Hat or Arch Linux system"
                exit 1
        fi
}

