#!/bin/bash

# TODO: 
# - integrate rtcwake into this script
# - integrate crontab into this script using 'sed'
# - add debug feature to "simulate" execution (dry-run)
# - replace audacious with more reliable audio player

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

PLAYER="/usr/bin/audacious"

# TODO: make audio track changing more comfortable
# although using YouCompleteMe is rather comfortable, though it does not always work
#TRACK="/home/konstunn/Music/Frank Sinatra - Fly Me To The Moon.mp3"
TRACK="/media/konstunn/data/mamedia/recovered_music/Delinquent Habits - Return Of The Tres (Instrumental).mp3"
TRACK="/home/konstunn/Music/Delinquent Habits - Return Of The Tres (Instrumental).mp3"

LOG_FILE="./alarm.log"

TIMEOUT="5m" 
SOUND_VOLUME="50"

export LC_TIME=en_US.utf8

function log {
	echo "$(date +'%b %d %T') localhost$2 $(basename $0)$1" >> $LOG_FILE 
}

log " started." ":"

while [ true ] 
do 
	log ": starting $(basename $PLAYER) ..."
	#$PLAYER -V -p -h "$TRACK" 2>&1 | tee -a $LOG_FILE &
	$PLAYER -p -h "$TRACK" 2>&1 | tee -a $LOG_FILE &
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

	wait $(pidof $(basename $PLAYER)) 

	log ": player was killed."

	# TODO: make smth else more interesting (window or smth)
	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."

	log ": gone to sleep for $TIMEOUT ..."
	sleep $TIMEOUT
	log ": $TIMEOUT is over."
done
