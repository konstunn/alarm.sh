# alarm.sh
Morning wake up alarm menu-driven bash script. Uses mainly cron scheduler and audacious audio player.

### Features
1. Add / remove, set (time, days of week, audio track), enable / disable several alarm jobs.
2. Robust repeated run.
3. Sets system sound volume using pulse audio. Smooth volume incrementation.
4. Logging.
5. Crontab backup.
6. Desktop notifications.

### Usage
1. Use text menu interface to manage alarm jobs (add / remove, set, enable / disable).
2. When the time has come to be awaken and music is playing, issue `killall audacious` and go back to sleep. :-)
3. When your are definitely awaken, issue `killall audacious ; killall alarm.sh` and go brush your teeth. :-)

### TODO
Integrate rtcwake

### Bugs
Many
