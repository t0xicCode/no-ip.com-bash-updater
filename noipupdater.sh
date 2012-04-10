#!/bin/bash

# No-IP uses emails as username, so make sure that you encode the @ as %40
USERNAME=username
PASSWORD=password
HOST=hostsite
LOGFILE=logs/noip.log
DIR=config
STOREDIPFILE=$DIR/current_ip
USERAGENT="Simple Bash No-IP Updater/0.9 support@afrosoft.tk"

if [ ! -e $STOREDIPFILE ]; then 
	touch $STOREDIPFILE
fi

if [ -e $DIR/lock ]; then
	# Lock file is placed when errors require human interaction
	# the script wil not run until the file is removed
	echo "Permanently locked due to previous failure" >&2
	exit 64
fi

if [ -e $DIR/lock_temp ]; then
	# A 30 minute lock is in place. Exit if file newer than 30 minutes.
	# delete and proceed if file is older
	created_time=$(date -d"`stat -c %y $DIR/lock_temp`" +"%s")
	current_time=$(date +"%s")
	if [ $(($current_time - $created_time)) -lt 1800 ]; then
		# It has been less than 30 minutes
		echo "Temporarily locked due to previous failure" >&2
		exit 65
	else
		rm $DIR/lock_temp
	fi
fi
		

NEWIP=$(wget -O - http://www.whatismyip.org/ -o /dev/null | grep "Your Ip Address" | awk -F">" '{print $3}' | awk -F"<" '{print $1}')
STOREDIP=$(cat $STOREDIPFILE)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

if [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(wget -O - -q --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	echo "[$DATE] $RESULT" >>$LOGFILE
	if [ "$RESULT" == "good $NEWIP" -o "$RESULT" == "nochg $NEWIP" ]; then
		# We have a successfull change!
		echo $NEWIP > $STOREDIPFILE
	else
		# We received an error
		if [ "$RESULT" == "911" ]; then
			# API states that we should wait 30 minutes, so let's
			# create a temporary lock file
			touch $DIR/lock_temp
		fi
	fi
else
	echo "[$DATE] No IP change" >> $LOGFILE
fi

exit 0

