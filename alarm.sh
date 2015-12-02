#!/bin/bash

# TODO: 
# - integrate rtcwake into this script
# - integrate crontab into this script with 'sed' command
# - add logging (cope with aliases, command variables and date format)
# - improve robustness
# - replace audacious with more reliable audio player
# - add log function
# - add debug feature to simulate action

# NOTES:
# - does not work after pm-suspend ?
# - audtool is not reliable
# - beware of light-locker blocking the audio player

# BUGS:
	# repeat is being reset
	# cause seems that audtool falls off.
	# maybe it is fixed with setting repeat in gui last time (yes, it is really so)
	# so setting it by default this way


# select display (in case of starting gui apps)
export DISPLAY=:0

PLAYER="/usr/bin/audacious"

# TODO: make audio track changing more comfortable
# although using YouCompleteMe is rather comfortable
TRACK="/home/konstunn/Music/Frank Sinatra - Fly Me To The Moon.mp3"

LOG_FILE="./alarm.log"

TIMEOUT="5m" 
SOUND_VOLUME="56"

export LC_TIME=en_US.utf8

echo "$(date +'%b %d %T') $(hostname) $(basename $0) started." >> $LOG_FILE

while [ true ] 
do 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): starting $(basename $PLAYER) coproc ..." >> $LOG_FILE
	coproc $PLAYER -p -h "$TRACK" 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): $(basename $PLAYER) coproc started." >> $LOG_FILE

	# TODO: improve robustness
	sleep 5 
	
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: checking playlist repeat status ..." >> $LOG_FILE
	if [[ $(audtool --playlist-repeat-status) -eq "off" ]]
	then
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is off." >> $LOG_FILE
		audtool --playlist-repeat-toggle  # using audtool is not reliable
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is set to on." >> $LOG_FILE 
	else
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is on." >> $LOG_FILE 
	fi

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: setting the sound volume ..." >> $LOG_FILE 

	## set volume with pactl (pulseaudio control utility)
	pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $SOUND_VOLUME%
	#
	#audtool --set-volume $SOUND_VOLUME # was not reliable

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: sound volume is set." >> $LOG_FILE

	# TODO: may insert while loop checking if audacious is playing the track 
	# if yes, wait until it dies or stops, otherwise timeout for 5 minutes 
	wait $(pidof $(basename $PLAYER)) 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audacious was killed." >> $LOG_FILE 

	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): gone to sleep for $TIMEOUT ..." >> $LOG_FILE
	sleep $TIMEOUT
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): $TIMEOUT is over." >> $LOG_FILE 
done
