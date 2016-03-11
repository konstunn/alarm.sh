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

TIMEOUT="5m" 
SOUND_VOLUME="58"

export LC_TIME=en_US.utf8

function log {
	echo "$(date +'%b %d %T') localhost$2 $(basename $0)$1" >> $LOG_FILE 
}

# TODO: parse command line arguments

# alarm time set mode
if [ $# == 1 ] ; then

	# check $1 for valid time value
	if ! [[ $1 =~ ^[0-9]{1,2}:[0-9]{2}$ ]] ; then
		echo $(basename $0): invalid alarm time '$1'
		echo $(basename $0): terminating...
		exit 1
	fi

	# extract minutes and hours from $1
	HOURS=$(echo $1 | awk -F':' '{print $1}')
	MINUTES=$(echo $1 | awk -F':' '{print $2}')

	DT_MIN=5 # minutes for rest between wake and cron job

	# unix time for rtcwake
	WAKE_TIME=$((`date -d "$1" +%s` - $DT_MIN*60))

	# robust way
	SELF_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/"$(basename $0)"

	# TODO add support for more than one alarm jobs
	# set alarm time in crontab
	crontab -l | grep -q "alarm.sh$"

	if [ $? == 0 ] ; then
		# if string exists, substitute time
		crontab -l | sed -e "/alarm.sh$/s/[^ \t]\{1,2\}/$MINUTES/1" \
						 -e	"/alarm.sh$/s/[^ \t]\{1,2\}/$HOURS/2"  | crontab -
	else
		# if that string does not exist yet, insert it
		crontab -l | sed -e "\$a\\\t$MINUTES\t$HOURS\t\*\t\*\t\*\t$SELF_PATH\n" | crontab -
	fi

	# TODO: check if it is already set,
	# if yes, compare. if set later, set new,
	# else leave it
	sudo rtcwake -m no -t $WAKE_TIME

	exit 0

else
	if [ $# -gt 1 ] ; then
		echo $(basename $0): unsupported mode, argc should be 1 or 0
		# TODO: print help
		echo $(basename $0): terminating...
		exit 1
	fi
fi


# alarm mode

log " started." ":"

while true
do 
	log ": starting $(basename $PLAYER) ..."
	$PLAYER $PLAYER_OPTS "$TRACK" 2>&1 | tee -a $LOG_FILE &
	log ": $(basename $PLAYER) started."

	# take a break before call audtool
	sleep 5 
	
	log ": audtool: checking playlist repeat status ..."
	if [[ $(audtool --playlist-repeat-status) -eq "off" ]]
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
	killall audacious

	#wait $(pidof $(basename $PLAYER))

	log ": player was killed."

	# TODO: make smth else more interesting (window or smth)
	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."

	log ": gone to sleep for $TIMEOUT ..."
	sleep $TIMEOUT
	log ": $TIMEOUT is over."
done
