#!/bin/bash

# TODO:
#	- add debug feature to "simulate" execution (dry-run)
#	- replace audacious with more reliable audio player
#	- integrate rtcwake
#	- install to home dir
#	- check if sound is muted globally and unmute if so

# NOTES:
# - audtool is not reliable (report audacious bug)
# - beware of light-locker blocking the audio player (bullshit)

# BUGS: damn audacious seems to catch deadlock sometimes
# - repeat is being reset
# - cause seems that audtool falls off. (report audacious bug)
# - beware of light-locker blocking the audio player
# - seems that audtool falls off. (report audacious bug)
# - maybe it is fixed with setting repeat in gui last time (yes, it works)
#		so setting it by default this way
# - audacious falls down

# select display (in case of starting gui apps)
export DISPLAY=:0

PLAYER_OPTS="-p -h"
PLAYER="/usr/bin/audacious"

LOG_FILE="./alarm.log" # TODO specify constant absolute path

TIMEOUT="2m"
SOUND_VOLUME="70" # TODO get out to config file or crontab

PLAY_NOW=0
TEXT_MENU=0

export LC_TIME="en_US.utf8" # for logging

function log {
	echo "$(date +'%b %d %T') localhost: $(basename $0)$1" >> $LOG_FILE
}

function print_help {
	echo -e "\nUsage:\n `basename $0` [options]"
	echo -e "\nOptions:		\
		\n --menu | -m		\
		\n --track | -t	<path_to_audio_file> \
		\n --help | -h \n"
}

# robust way to get path to itself
SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/"$(basename $0)"

cd `dirname $SELF_PATH`

# if no arguments, invoke text menu
if [ $# -eq 0 ] ; then 
	TEXT_MENU=1
fi

# parse command line arguments
OPTS=+h,t:,m
LONG_OPTS="help,menu,track:"

ARGS=`getopt -o $OPTS --long $LONG_OPTS \
     -n $(basename $0) -- "$@"`

# if getopt returned error, claim and exit
if [ $? -ne 0 ] ; then
	echo "`basename $0`: specify '--help' or '-h' option for help." >&2
	echo "`basename $0`: terminating..." >&2
	exit 1
fi

eval set -- "$ARGS"

while true ; do
	case "$1" in 
		--menu | -m)
			TEXT_MENU=1 ; shift ;;
		--track | -t)
			PLAY_NOW=1;	TRACK="$2" ; shift 2 ;;
		--help | -h)
			print_help; exit 0 ;;
		--)
			shift ; break ;;
	esac
done

# claim if extra arguments and exit
if [ $# -gt 0 ] ; then
	echo "`basename $0`: extra arguments \"$@\"" >&2
	echo "`basename $0`: specify '--help' or '-h' option for help." >&2
	echo "`basename $0`: terminating..." >&2
	exit 1
fi

# $1 - hours variable name, $2 - minutes variable name
function ask_check_alarm_time {
	read -p "Enter alarm time in 'hh:mm' format: " TIME

	if ! [[ $TIME =~ ^[0-9]{1,2}:[0-9]{2}$ ]] ; then
		echo Invalid time input \'$TIME\'
		return 1
	fi

	HOURS=$(echo $TIME | awk -F':' '{print $1}')
	MINUTES=$(echo $TIME | awk -F':' '{print $2}')

	if [ $HOURS -gt 23 -o $MINUTES -gt 59 ] ; then
		echo Invalid time input \'$TIME\'
		return 1
	fi

	eval $1=$HOURS
	eval $2=$MINUTES
}

# $1 - alarm dow variable name
function ask_check_alarm_dow {
	read -p "Enter day of week list, range or list of ranges: " DOW

	# validate DOW
	if ! [[ $DOW =~ ^([1-7])|([1-7]-[1-7])(,\1)+$ ]] ; then
		echo "Invalid input '$DOW'"
		return 1
	fi

	eval $1=$DOW
}

# $1 - track path variable name
function ask_check_audio_track_path {
	read -ep "Enter path to audio track: " TRACK

	if ! [ -e "$TRACK" ] ; then
		echo "No such a readable file '$TRACK'"
		return 1
	fi

	eval $1=\"$TRACK\"
}

# prints alarm
# $1 - name of existing alarm
# TODO: simplify, use print_all_alarms and grep by name
function print_alarm_by_name {
	crontab -l | grep -A 1 -e "^# alarm.sh $1$" \
			| awk -F' |\t' \
				'/^# alarm.sh/ { printf "%s\t",$3 }
				/^#?\t[0-9]/ { printf "%s:%s\t%s\t",$3,$2,$6;
					match($0,/\".+\"/,a); print a[0] }'
}

# $1 - alarm name variable name
# $2 - time variable name
# $3 - day of week variable name
# $4 - path to audio file string variable name
function ask_check_alarm_spec {
	read -p "Enter name for alarm to add: " NAME

	if ! [[ -n $NAME ]] ; then
		echo Empty name not allowed.
		return 1
	fi
	
	crontab -l | grep "^# alarm.sh $NAME$" > /dev/null
	if [ $? -eq 0 ] ; then
		echo -e "\nAlarm '$NAME' already exists.\n"
		print_alarm_by_name $NAME
		return 1
	fi

	eval $1=$NAME

	ask_check_alarm_time HOURS MINUTES
	if [ $? -gt 0 ] ; then return 1 ; fi

	eval $2=$HOURS:$MINUTES

	ask_check_alarm_dow DOW
	if [ $? -gt 0 ] ; then return 1 ; fi

	eval $3=$DOW

	ask_check_audio_track_path TRACK
	if [ $? -gt 0 ] ; then return 1 ; fi
	
	eval $4=\"$TRACK\"

	return 0
}

JOB_HEADER="alarm.sh"

# $1 - name, 
# $2 - time (hh:mm), 
# $3 - crontab day of week
# $4 - path to track 
function add_alarm {
	HOURS=$(echo $2 | awk -F':' '{print $1}')
	MINUTES=$(echo $2 | awk -F':' '{print $2}')

	DOW=$3 # crontab day of week 

	TRACK="$4"

	(crontab -l 
	echo -e "# $JOB_HEADER $1\n\t$MINUTES\t$HOURS\t*\t*\t$DOW\t$SELF_PATH -t \"$TRACK\"\n") \
		| crontab -

	if [ $? -eq 0 ] ; then
		echo -e "\nAlarm was added"
	fi
}

# list all alarms
function print_all_alarms {
	crontab -l | grep -A 1 "^# alarm.sh" \
		| awk -F' |\t' \
			'BEGIN { print "name\tstate\ttime\tweekday\ttrack"; i=0 }
			/^# alarm.sh/ { printf "%s\t",$3; i++ }
			/^#?\t[0-9]/ { 
				if ($1 == "#") printf "%s\t","off"
				else printf "%s\t","on"
				printf "%s:%s\t%s\t",$3,$2,$6;
				match($0,/".+"/,a); print a[0] 
			}
			END { if (i == 0) print "\nNo alarms." }'
}

# $1 - existing alarm name
function toggle_alarm_on_off {
	crontab -l | sed "/^# $JOB_HEADER $1.*/{n;s/#//g;t;s/^/#/}" | crontab -
}

# $1 - existing alarm name variable name
function ask_check_existing_alarm_name {
	echo ""
	read -p "Enter alarm name: " NAME

	if ! [[ -n $NAME ]] ; then
		echo Empty name not allowed. Cancelled.
		return 1
	fi
	
	crontab -l | grep "^# `basename $0` $NAME$" > /dev/null
	if [ $? -gt 0 ] ; then
		echo "Alarm '$NAME' does not exist."
		return 1
	fi
	eval $1=$NAME
}

# $1 - alarm name
function delete_alarm {
	crontab -l | sed "/^# $JOB_HEADER $1$/,+2d" | crontab -
}

# $1 - alarm name, $2 - hours, $2 - minutes
function set_alarm_time {
	crontab -l \
		| sed -e \
			"/^# $JOB_HEADER $1$/{n;s%^\(\#\?\)\t[^ \t]\+\t[^ \t]\+%\1\t$3\t$2%}" \
		| crontab -
	return $?
}

function print_set_alarm_menu {
	echo "1. set time"
	echo "2. set day of week"
	echo "3. set audio track path"
	echo "4. set all one by one"
	echo "5. exit"
}

# $1 - name
function set_alarm {
	while true ; do
		echo ""
		read -p "Press Enter..."
		clear
		echo ""
		echo "Setting alarm \"$1\""
		print_alarm_by_name $1
		echo ""
		print_set_alarm_menu
		echo ""

		read -p "Enter your choice: " CHOICE

		echo ""
		case $CHOICE in
			1) 
				ask_check_alarm_time HOURS MINUTES
				if [ $? -gt 0 ] ; then continue; fi
				set_alarm_time $1 $HOURS $MINUTES	
				if [ $? -gt 0 ] ; then echo "Fail"; continue 
				else echo "Success" ; fi
				;;
			2) echo "Not implemented yet"
				;;
			3) echo "Not implemented yet"

				ask_check_audio_track_path TRACK
				if [ $? -gt 0 ] ; then continue ; fi

				crontab -l \
					| sed -e \
						"/^# $JOB_HEADER $1/{n;s%-t \".*\"%-t \"$TRACK\"%}" | crontab -
				;;
			4) 
				ask_check_alarm_time HOURS MINUTES
				if [ $? -gt 0 ] ; then continue ; fi

				ask_check_alarm_dow DOW
				if [ $? -gt 0 ] ; then continue ; fi

				ask_check_audio_track_path TRACK
				if [ $? -gt 0 ] ; then continue ; fi

				crontab -l \
					| sed -e \
						"/^# $JOB_HEADER $1$/{n;s%^\(\#\?\).*$%\1\t$MINUTES\t$HOURS\t\*\t\*\t$DOW\t$SELF_PATH -t \"$TRACK\"%}" \
					| crontab -
				if [ $? -gt 0 ] ; then echo "Fail"
				else echo "Success" ; fi
			;;
			5) return 0 ;;
		esac
	done
}

# $1 - start, $2 - finish 
function pa_increment_volume_smoothly {
	SOUND_VOLUME=$1
	while [ $SOUND_VOLUME -le $2 ] ; do
		# global sound adjustment command
		pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $SOUND_VOLUME%
		sleep 1
		SOUND_VOLUME=$(($SOUND_VOLUME + 1))
	done
}

function print_main_menu {
	echo "1. list alarms"
	echo "2. add alarm"
	echo "3. delete alarm"
	echo "4. set alarm"
	echo "5. enable/disable alarm"
	echo "6. exit"
}

# invoke text menu
if [ $TEXT_MENU -eq 1 ] ; then

	# if crontab does not exist
	crontab -l &> /dev/null
	if [ $? -gt 0 ] ; then
		# create one
		echo "" | crontab -
	else 
		while true ; do
			# backup crontab
			read -p "Back up crontab [y/n]? " CRONTAB_BACKUP
			if [[ $CRONTAB_BACKUP =~ ^[yY]$ ]] ; then
				mkdir -p ./crontab.bkp
				crontab -l > ./crontab.bkp/`date +%H%M%S-%d-%m-%Y`.crontab.bkp
				break
			elif ! [[ $CRONTAB_BACKUP =~ ^[nN]$ ]] ; then
				echo "Invalid input."
			else
				break
			fi
		done
	fi

	# TODO check if rtcwake job exists in crontab
	#	if yes, go on
	#	if no, create one

	# TODO Every time alarm.sh is invoked, 
	# rtcwake wrapper routine should be invoked, if enabled.
	# rtcwake wrapper routine browses through alarm jobs,
	# and invoke rtcwake with corresponding argument.

	while true ; do
		echo ""
		print_main_menu
		echo ""
		read -p "Enter your choice: " CHOICE

		echo ""

		case "$CHOICE" in
			1) print_all_alarms ;;
			2)
				ask_check_alarm_spec NAME TIME DOW TRACK
				if [ $? -eq 0 ] ; then 
					add_alarm $NAME $TIME $DOW "$TRACK"
				fi
			;;
			3) 
				print_all_alarms
				ask_check_existing_alarm_name NAME
				if [ $? -eq 0 ] ; then
					delete_alarm $NAME
					echo -e "\nDeletion succeeded"
				fi
			;;
			4)
				print_all_alarms
				ask_check_existing_alarm_name NAME
				if [ $? -eq 0 ] ; then 
					set_alarm $NAME
					#if [ $? -eq 0 ] ; then echo "Success" ; fi
				fi
			;;
			5)	
				print_all_alarms
				ask_check_existing_alarm_name NAME
				if [ $? -eq 0 ] ; then 
					toggle_alarm_on_off $NAME
					echo -e "\nSucceeded."
				fi
			;;
			6) exit 0 ;;
			*) echo "Invalid input." ;;
		esac

		echo ""
		read -p "Press Enter..."
		clear

	done
fi

if [ $PLAY_NOW -eq 0 ] ; then exit 0; fi

# play now

log " started."

while true
do 
	log ": starting $(basename $PLAYER) ..."
	$PLAYER $PLAYER_OPTS "$TRACK" 2>&1 | tee -a $LOG_FILE &
	log ": $(basename $PLAYER) started."

	START_VOLUME=20

	pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $START_VOLUME%

	# take a break before call audtool
	sleep 5 
	
	log ": audtool: checking playlist repeat status ..."
	if [ `audtool --playlist-repeat-status` == "off" ]
	then
		log ": audtool: playlist repeat status is off."
		audtool --playlist-repeat-toggle  # note: audtool is not reliable
		log ": audtool: playlist repeat status is set to on."
	else
		log ": audtool playlist repeat status is on."
	fi

	# TODO: track sound volume

	log ": pactl: setting the sound volume ..." 

	# TODO fork and track and adjust sound volume while (true)
	pa_increment_volume_smoothly $START_VOLUME $SOUND_VOLUME

	#audtool --set-volume $SOUND_VOLUME # was not reliable
	log ": pactl: sound volume is set."

	# TODO: may insert while loop checking if player is playing the track 
	# if yes, wait until it dies or stops and then timeout for 5 minutes 

	log ": waiting for player to be killed ..."

	ALARM_TIMEOUT="4m" # get out to config file or crontab

	sleep $ALARM_TIMEOUT # possible player deadlock workaround

	killall	`basename $PLAYER`

	#wait $(pidof $(basename $PLAYER))

	log ": player was killed."

	# TODO: make smth else more interesting (window or smth)
	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."

	log ": gone to sleep for $TIMEOUT ..."
	sleep $TIMEOUT
	log ": $TIMEOUT is over."
done
