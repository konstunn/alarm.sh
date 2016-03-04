#!/bin/bash

# TODO: 
# - integrate rtcwake into this script
# - integrate crontab into this script using 'sed'
# - add debug feature to "simulate" execution (dry-run)
# - replace audacious with more reliable audio player
# - add debug feature to simulate action

# NOTES:
# - audtool is not reliable (report audacious bug)
# - beware of light-locker blocking the audio player

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
SOUND_VOLUME="58"

export LC_TIME=en_US.utf8

echo "$(date +'%b %d %T') $(hostname) $(basename $0) started." >> $LOG_FILE

while [ true ] 
do 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): starting $(basename $PLAYER) ..." >> $LOG_FILE
	$PLAYER -V -p -h "$TRACK" 2>&1 | tee -a $LOG_FILE &
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): $(basename $PLAYER) started." >> $LOG_FILE

	# TODO: improve robustness
	sleep 5 
	
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: checking playlist repeat status ..." >> $LOG_FILE
	if [[ $(audtool --playlist-repeat-status) -eq "off" ]]
	then
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is off." >> $LOG_FILE
		audtool --playlist-repeat-toggle  # note: audtool is not reliable
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is set to on." >> $LOG_FILE 
	else
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is on." >> $LOG_FILE 
	fi

	# TODO: track sound volume
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: setting the sound volume ..." >> $LOG_FILE 
	## set volume with pactl (pulseaudio control utility) - seems to be reliable this time
	pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $SOUND_VOLUME%
	#audtool --set-volume $SOUND_VOLUME # was not reliable
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: sound volume is set." >> $LOG_FILE

	# TODO: may insert while loop checking if player is playing the track 
	# if yes, wait until it dies or stops and then timeout for 5 minutes 

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): wait for player to be killed..." >> $LOG_FILE

	wait $(pidof $(basename $PLAYER)) 

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): player was killed." >> $LOG_FILE 

	# TODO: make smth else more interesting (window or smth)
	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): gone to sleep for $TIMEOUT ..." >> $LOG_FILE
	sleep $TIMEOUT
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): $TIMEOUT is over." >> $LOG_FILE 
done
