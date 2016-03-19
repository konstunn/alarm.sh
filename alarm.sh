#!/bin/bash

# TODO:
#	- add debug feature to "simulate" execution (dry-run)
#	- replace audacious with more reliable audio player

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

LOG_FILE="./alarm.log"
CONF_FILE="./alarm.conf"

TIMEOUT="5m"
SOUND_VOLUME="60" # TODO get out to config file

PLAY_NOW=0
TEXT_MENU=0

export LC_TIME="en_US.utf8"

function log {
	echo "$(date +'%b %d %T') localhost: $(basename $0)$1" >> $LOG_FILE
}

function print_help {
	echo -e "\nUsage:\n `basename $0` [options]"
	echo -e "\nOptions: \
		\n --play-now | -p  \
		\n --config | -c \
		\n --help | -h \n"
}

# robust way to get path to itself
SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/"$(basename $0)"

# if no arguments, claim and exit
if [ $# -eq 0 ] ; then 
	echo "`basename $0`: no options specified" >&2
	echo "`basename $0`: for list of options specify '--help' or '-h' option." >&2
	echo "`basename $0`: terminating..." >&2
	exit 1 
fi

# parse command line arguments
OPTS=+h,p,c,t:
LONG_OPTS="help,play-now,config,track:"

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
		--play-now | -p)	
			PLAY_NOW=1 ; shift 
		;;
		--config | --configure | -c)
			TEXT_MENU=1 ; shift 
		;;
		--track | -t)
			PLAY_NOW=1;	TRACK="$2" ; shift 2
		;;
		--help | -h)	print_help; exit 0 ;;
		--)				shift ; break ;;
	esac
done

# claim if extra arguments and exit
if [ $# -gt 0 ] ; then
	echo "`basename $0`: extra arguments \"$@\"" >&2
	echo "`basename $0`: specify '--help' or '-h' option for help." >&2
	echo "`basename $0`: terminating..." >&2
	exit 1
fi

# $1 - alarm name variable name
function ask_alarm_spec {
	read -p "Enter name for alarm to add: " NAME

	if ! [[ -n $NAME ]] ; then
		echo Empty name not allowed.
		return 1
	fi
	
	crontab -l | grep "^# `basename $0` $NAME.*" > /dev/null
	if [ $? -eq 0 ] ; then
		echo "Alarm '$NAME' already exists."
		# TODO make output more hamster-readable
		crontab -l | grep -A 1 "^# `basename $0` $NAME.*"
		return 1
	fi

	eval $1=$NAME

	read -p "Enter alarm time in 'hh:mm' format: " TIME

	if ! [[ $TIME =~ ^[0-9]{1,2}:[0-9]{2}$ ]] ; then
		echo Invalid time input '$TIME'
		return 1
	fi

	HOURS=$(echo $TIME | awk -F':' '{print $1}')
	MINUTES=$(echo $TIME | awk -F':' '{print $2}')

	if [ $HOURS -gt 23 ] ; then
		echo Invalid time input $TIME
		return 1
	fi

	if [ $MINUTES -gt 59 ] ; then
		echo Invalid time input $TIME
		return 1
	fi

	eval $2=$TIME

	read -p "Enter day of week list, range or list of ranges: " DOW

	# validate DOW
	if ! [[ $DOW =~ ^([1-7])|([1-7]-[1-7])(,\1)+$ ]] ; then
		echo "Invalid input '$DOW'"
		return 1
	fi

	eval $3=$DOW

	read -ep "Enter path to audio track: " TRACK

	if ! [ -e "$TRACK" ] ; then
		echo "No such a readable file '$TRACK'"
		return 1
	fi

	eval $4=\"$TRACK\"

	return 0
}

# $1 - name, 
# $2 - time (hh:mm), 
# $3 - crontab day of week
# $4 - path to track 
function add_alarm {
	ALARM_HEADER="^# `basename $0` $1.*$"

	# extract minutes and hours from $1
	HOURS=$(echo $2 | awk -F':' '{print $1}')
	MINUTES=$(echo $2 | awk -F':' '{print $2}')

	DOW=$3 # crontab day of week 

	TRACK="$4"

	crontab -l \
		| sed -e \
		"\$a\# `basename $0` $1\n\t$MINUTES\t$HOURS\t\*\t\*\t\\$DOW\t$SELF_PATH -t \"$TRACK\"\n" \
		| crontab -

	if [ $? -eq 0 ] ; then
		echo "Alarm added"
	fi
}

function list_alarms {
	crontab -l \
		| grep -A 1 -e "^# alarm.sh" 
		# TODO make output hamster-readable
	return 0
}

function toggle_alarm_enabled_disabled {
	crontab -l | sed "/^# `basename $0` $1.*/{n;s/#//g;t;s/^/#/}" | crontab -
}

function ask_existing_alarm_name {
	read -p "Enter alarm name: " NAME

	if ! [[ -n $NAME ]] ; then
		echo Empty name not allowed.
		return 1
	fi
	
	crontab -l | grep "^# `basename $0` $NAME.*" > /dev/null
	if [ $? -gt 0 ] ; then
		echo "Alarm '$NAME' does not exist."
		return 1
	fi
	eval $1=$NAME
}

# invoke text menu
if [ $TEXT_MENU -eq 1 ] ; then

	# if crontab does not exist
	crontab -l > /dev/null		
	if [ $? -gt 0 ] ; then
		# create one
		echo -n "" | crontab -
	else 
		# backup crontab
		crontab -l > ./crontab.bkp/`date +%H%M%S-%d-%m-%Y`.crontab.bkp
	fi

	while true ; do
		echo -e "\n1. list alarms"
		echo "2. add alarm"
		echo "3. delete alarm"
		echo "4. set alarm"
		echo "5. enable/disable alarm"
		echo "6. exit"

		echo ""
		read -p "Enter your choice: " CHOICE

		echo ""

		case "$CHOICE" in
			1)
				# list
				list_alarms
			;;
			2)
				ask_alarm_spec NAME TIME DOW TRACK
				# add
				if [ $? -gt 0 ] ; then continue; fi
				add_alarm $NAME $TIME $DOW "$TRACK"
			;;
			3) 
				# delete
			;;
			4)
				# set
			;;
			5) 
				# enable / disable
				list_alarms
				
				ask_existing_alarm_name NAME

				if [ $? -gt 0 ] ; then continue ; fi

				toggle_alarm_enabled_disabled $NAME
				echo "Succeeded."
			;;
			6) exit 0 ;;
			*) echo -n "Invalid input. " ;;
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

	# global sound adjustment command
	pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $SOUND_VOLUME%

	#audtool --set-volume $SOUND_VOLUME # was not reliable
	log ": pactl: sound volume is set."

	# TODO: may insert while loop checking if player is playing the track 
	# if yes, wait until it dies or stops and then timeout for 5 minutes 

	log ": waiting for player to be killed ..."

	sleep 5m	# temporary audacious deadlock workaround
	killall	audacious

	#wait $(pidof $(basename $PLAYER))

	log ": player was killed."

	# TODO: make smth else more interesting (window or smth)
	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."

	log ": gone to sleep for $TIMEOUT ..."
	sleep 2m
	log ": $TIMEOUT is over."
done
