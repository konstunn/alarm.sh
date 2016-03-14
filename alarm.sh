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

# TODO: make audio track changing more comfortable
# although using YouCompleteMe is rather comfortable, though it does not always work
# TODO: get this out to a config file
#TRACK="/home/konstunn/Music/Frank Sinatra - Fly Me To The Moon.mp3"
TRACK="/media/konstunn/data/mamedia/recovered_music/Delinquent Habits - Return Of The Tres (Instrumental).mp3"
TRACK="/home/konstunn/Music/Delinquent Habits - Return Of The Tres (Instrumental).mp3"

LOG_FILE="./alarm.log"
CONF_FILE="./alarm.conf"

TIMEOUT="5m"
SOUND_VOLUME="58"

PLAY_NOW=0
CONFIG=0

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

function read_track_conf {
	echo ""
}

function write_track_conf {
	echo ""
}

function get_time {
	echo ""
}

# TODO: add disabling feature
# sets rtcwake and cron job time
function set_time {
	if ! [[ $1 =~ ^[0-9]{1,2}:[0-9]{2}$ ]] ; then
	# check $1 for valid time value
		# TODO: redirect to stderr ?
		echo $(basename $0): invalid alarm time '$1'
		echo $(basename $0): terminating...
		return 1
	fi

	# extract minutes and hours from $1
	HOURS=$(echo $1 | awk -F':' '{print $1}')
	MINUTES=$(echo $1 | awk -F':' '{print $2}')

	DT_MIN=5 # minutes to idle between wake and cron job

	# unix time for rtcwake
	WAKE_TIME=$((`date -d "$1" +%s` - $DT_MIN*60))

	# robust way
	SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/"$(basename $0)"

	# TODO add support for more than one alarm jobs
	# set alarm time in crontab
	crontab -l | grep -q "alarm.sh"

	if [ $? == 0 ] ; then
		# if string exists, substitute time
		crontab -l | sed -e "/alarm.sh/s/[^ \t]\{1,2\}/$MINUTES/1" \
						 -e	"/alarm.sh/s/[^ \t]\{1,2\}/$HOURS/2"  | crontab -
	else
		# if that string does not exist yet, insert it
		crontab -l | sed -e "\$a\\\t$MINUTES\t$HOURS\t\*\t\*\t\*\t$SELF_PATH -p\n" | crontab -
	fi

	# TODO: check if it is already set,
	# if yes, compare. if set later, set new,
	# else leave it
	echo "sudo rtcwake -m no -t \$WAKE_TIME"
	sudo rtcwake -m no -t $WAKE_TIME

	return 0
}

# if no arguments, claim and exit
if [ $# -eq 0 ] ; then # TODO: redirect to stderr ?
	echo "`basename $0`: no options specified"
	echo "`basename $0`: for list of options specify '--help' or '-h' option."
	echo "`basename $0`: terminating..."
	exit 1 
fi

OPTS=+h,p,c
LONG_OPTS="help,play-now,config"

ARGS=`getopt -o $OPTS --long $LONG_OPTS \
     -n $(basename $0) -- "$@"`

# if getopt returned error, claim and exit
if [ $? -ne 0 ] ; then # TODO: redirect to stderr ?
	echo "`basename $0`: specify '--help' or '-h' option for help."
	echo "`basename $0`: terminating..."
	exit 1
fi

eval set -- "$ARGS"

# parse command line arguments
while true ; do
	case "$1" in --play-now | -p)	PLAY_NOW=1 ; shift ;;
		--config | --configure | -c)
			CONFIG=1 ; shift ;;
		--help | -h)	print_help; exit 0 ;;
		--)				shift ; break ;;
	esac
done

# claim if extra arguments and exit
if [ $# -gt 0 ] ; then # TODO: redirect to stderr ?
	echo "`basename $0`: extra arguments \"$@\""
	echo "`basename $0`: specify '--help' or '-h' option for help."
	echo "`basename $0`: terminating..."
	exit 1
fi

# invoke text menu
if [ $CONFIG -ne 0 ] ; then

	# read track from conf
	if [ -r $CONF_FILE ] ; then
		source $CONF_FILE
	else
		echo $CONF_FILE : no such a readable config file
		exit 1
	fi

	# get time from crontab
	MINUTES=`crontab -l | sed -ne "/alarm.sh/p" | awk '{print $1}'`
	HOURS=`crontab -l | sed -ne "/alarm.sh/p" | awk '{print $2}'`
	TIME=$HOURS:$MINUTES

	while true ; do
		echo -e "1. set time (\"$TIME\")"
		echo -e "2. set audio file (\"$TRACK\")"
		echo	"3. play"
		echo	"4. exit"
		echo -en "\nEnter your choice: "

		read DECISION
		echo ""

		case "$DECISION" in
			1)
				read -p "Enter time in 'hh:mm' format: " VAR
				set_time $VAR
				if [ $? -ne 0 ] ; then echo Time was not set 
				else TIME=$VAR ; fi
			;;
			2)
				read -ep "Enter path to audio file: " VAR
				if [ -r $VAR ] ; then 
					TRACK=$VAR
					# write to conf
					echo TRACK="$TRACK" > $CONF_FILE
				else
					echo $VAR : no such readable a file
				fi
				read -p "Press Enter.. "
			;;
			3) PLAY_NOW=1 ; break ;;
			4) exit 0 ;;
			*) read -p "Invalid input. Press Enter.. " ;;
		esac

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
