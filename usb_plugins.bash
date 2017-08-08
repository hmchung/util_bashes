#!/bin/bash

#Color setting
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0;37m'
RED_BOLD='\033[1;31m'
GREEN_BOLD='\033[1;32m'
BLUE_BOLD='\033[1;34m'
NC_BOLD='\033[1;37m'

#Rules file name
rules_file_dir="/etc/udev/rules.d/"
rules_file_name="99-usb-serial.rules"

#Rules related config
subsystem="tty"

function main {
if [ "$1" == "--reset" ]; then
	echo -e "${RED_BOLD}ATTEMPT TO RESET RULES${NC}"
	reset_udev_rule
else

	if [ -z "$1" ] && [ -z "$2" ]; then
		echo -e "${BLUE_BOLD}LISTING AVAILABLE PORTS${NC}"
		list_ports
	else
		echo -e "${NC_BOLD}LINKING PORT${RED_BOLD} /dev/$1 ${NC_BOLD} TO PORT ${RED_BOLD} /dev/$2 ${NC}"
		port_found=$(check_port $1)
		if [ "$port_found" == "1" ] ; then
			echo -e "PORT ${GREEN_BOLD}$1${NC} FOUND"
			echo "$(form_udev_rule $1 $2)"
		else
			echo -e "${RED}PORT $1 NOT FOUND"
		fi
	fi
fi
}

function list_ports() {
        for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do
        (
                syspath="${sysdevpath%/dev}"
                devname="$(udevadm info -q name -p $syspath)"
                [[ "$devname" == "bus/"* ]] && continue
                eval "$(udevadm info -q property --export -p $syspath)"
                [[ -z "$ID_SERIAL" ]] && continue
                echo -e "/dev/${BLUE_BOLD}$devname${NC} - $ID_SERIAL"
        )
        done
}

function check_port() {
	local found=0
	for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do
        (
                syspath="${sysdevpath%/dev}"
                devname="$(udevadm info -q name -p $syspath)"
                [[ "$devname" == "bus/"* ]] && continue
                eval "$(udevadm info -q property --export -p $syspath)"
                [[ -z "$ID_SERIAL" ]] && continue
		if [ "$devname" == "$1" ]; then
			echo "1"
			return 1
		fi
        )
        done
}

function form_udev_rule() {
	port=$1
	symlink=$2
	port_found=$(check_port $port)
	if [ "$port_found" == "1" ] ; then
		m_serial=$(udevadm info -a -n $port | grep '{serial}' | head -n1)
		m_idProduct=$(udevadm info -a -n $port | grep '{idProduct}' | head -n1)
		m_idVendor=$(udevadm info -a -n $port | grep '{idVendor}' | head -n1)
		rule="SUBSYSTEM==\"$subsystem\", $m_idVendor, $m_idProduct, $m_serial, SYMLINK+=\"$symlink\""
		echo -e "WRITING TO FILE: ${GREEN_BOLD}$rules_file_dir$rules_file_name${NC}"
		if [ ! -f $rules_file_dir$rules_file_name ]; then
			echo "CREATING NEW RULE FILE"
			sudo echo "$rule" > $rules_file_dir$rules_file_name
		else
			echo "APPENDING TO EXISTING RULE FILE"
			sudo echo "$rule" >> $rules_file_dir$rules_file_name
		fi
		echo -e "${GREEN}$rule${NC}"
		sudo udevadm control --reload-rules && udevadm trigger
	fi
}

function reset_udev_rule() {
	if [ ! -f $rules_file_dir$rules_file_name ]; then
		echo "RULE FILE NOT EXISTING YET"
        else
                rm $rules_file_dir$rules_file_name
		echo -e "${RED_BOLD}DELETED RULE FILE: $rules_file_dir$rules_file_name ${NC}"
	fi
}

main "$@"
