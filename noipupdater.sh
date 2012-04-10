#!/bin/bash

# No-IP uses emails as passwords, so make sure that you encode the @ as %40
USERNAME=username
PASSWORD=password
HOST=hostsite
LOGFILE=logdir/noip.log
DIR=some/dir
STOREDIPFILE=$DIR/current_ip
USERAGENT="Simple Bash No-IP Updater/0.9 support@afrosoft.tk"

if [ ! -e $STOREDIPFILE ]; then 
	touch $STOREDIPFILE
fi

NEWIP=$(wget -O - http://www.whatismyip.org/ -o /dev/null | grep "Your Ip Address" | awk -F">" '{print $3}' | awk -F"<" '{print $1}')
STOREDIP=$(cat $STOREDIPFILE)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

if [ "$NEWIP" != "$STOREDIP" ]; then
	RESULT=$(wget -O - -q --user-agent="$USERAGENT" --no-check-certificate "https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP")

	echo "[$DATE] $RESULT" >>$LOGFILE
	if [ "$RESULT" == "good $NEWIP" -o "$RESULT" == "nochg $NEWIP" ]; then
		# we have a successfull change!
		echo $NEWIP > $STOREDIPFILE
	fi
else
	echo "[$DATE] No IP change" >> $LOGFILE
fi

exit 0

