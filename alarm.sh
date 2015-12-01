#!/bin/bash

# TODO: 
# - integrate rtcwake into this script
# - integrate crontab into this script with 'sed' command
# - add logging (cope with aliases, command variables and date format)
# - improve robustness
# - replace audacious with more reliable audio player

# NOTE:
# - does not work after pm-suspend ?
# - audtool is not reliable
# - beware of light-locker blocking the audio player

# select display (in case of starting gui apps)
export DISPLAY=:0

# TODO: make audio track changing more comfortable
# although using YouCompleteMe is rather comfortable
TRACK="/home/konstunn/Music/Frank Sinatra - Fly Me To The Moon.mp3"

TIMEOUT="5m" 
SOUND_VOLUME="56"

export LC_TIME=en_US.utf8

while [ true ] 
do 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): starting audacious coproc..." >> ~/alarm.log
	coproc audacious -p -h "$TRACK" 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audacious coproc started" >> ~/alarm.log

	# TODO: improve robustness
	sleep 5 
	
	# bug: repeat is being reset
	# cause seems that audtool falls off.
	# maybe it is fixed with setting repeat in gui last time (yes, it is really so)
	# so setting it by default this way

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: checking playlist repeat status..." >> ~/alarm.log
	if [[ $(audtool --playlist-repeat-status) -eq "off" ]]
	then
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is off" >> ~/alarm.log
		audtool --playlist-repeat-toggle  # using audtool is not reliable
		echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is set to on" >> ~/alarm.log    
	fi
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audtool: playlist repeat status is on" >> ~/alarm.log

	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: setting the sound volume..." >> ~/alarm.log
	## set volume with pactl (pulseaudio control utility)
	pactl set-sink-volume alsa_output.pci-0000_00_1b.0.analog-stereo $SOUND_VOLUME%
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): pactl: sound volume is set" >> ~/alarm.log
	#
	#audtool --set-volume $SOUND_VOLUME # was not reliable

	# TODO: may insert while loop checking if audacious is playing the track 
	# if yes, wait until it dies or stops, otherwise timeout for 5 minutes 
	wait $(pidof audacious) 
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): audacious was killed" >> ~/alarm.log

	notify-send OK "I WILL WAKE YOU UP AFTER $TIMEOUT ..."
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): gone to sleep for $TIMEOUT" >> ~/alarm.log
	sleep $TIMEOUT
	echo "$(date +'%b %d %T') $(hostname) $(basename $0): $TIMEOUT is over" >> ~/alarm.log 
done
