#!/bin/bash

# No-IP uses emails as username, so make sure that you encode the @ as %40
USERNAME=username
PASSWORD=password
HOST=hostsite
LOGFILE=logs/noip.log
DIR=config
STOREDIPFILE=$DIR/current_ip
USERAGENT="Simple Bash No-IP Updater/1.1 support@afrosoft.tk"

while [ $# -ge 1 ] ; do
	case $1 in
#		-c) config_file=$2; shift 2;;
		-u) USERNAME=$2; shift 2;;
		-p) PASSWORD=$2; shift 2;;
		-h) HOST=$2; shift 2;;
		-l) LOGFILE=$2; shift 2;;
		--dir) DIR=$2; shift 2;;
		-s) STOREDIPFILE=$2; shift 2;;
		-i) IP_COMMAND=$2; shift 2;;
		-d) DEBUG=true; shift 1;;
		*) shift 1 ;;
	esac
done


if [ ! -e $STOREDIPFILE ]; then 
	touch $STOREDIPFILE
fi

if [ -e $DIR/lock ]; then
	# Lock file is placed when errors require human interaction
	# the script wil not run until the file is removed
	test $DEBUG && echo "Permanent lock"
	echo "Permanently locked due to previous failure." >&2
	echo "Please see your logs and refer to the documentation for more information." >&2
	exit 64
else
	test $DEBUG && echo "No permanent lock"
fi

if [ -e $DIR/lock_temp ]; then
	# A 30 minute lock is in place. Exit if file newer than 30 minutes.
	# delete and proceed if file is older
	created_time=$(date -d"`stat -c %y $DIR/lock_temp`" +"%s")
	current_time=$(date +"%s")
	if [ $(($current_time - $created_time)) -lt 1800 ]; then
		# It has been less than 30 minutes
		test $DEBUG && echo "Temporary lock"
		echo "Temporarily locked due to previous failure." >&2
		echo "System will automatically resume after a cooldown period." >&2
		exit 65
	else
		test $DEBUG && echo "No temporary lock"
		rm $DIR/lock_temp
	fi
fi

NEWIP=$(wget -O - http://icanhazip.com/ -o /dev/null)
STOREDIP=$(cat $STOREDIPFILE)
DATE=$(date +"%Y-%m-%d %H:%M:%S")

test $DEBUG && echo "New IP: $NEWIP"
test $DEBUG && echo "Stored IP: $STOREDIP"

if [ "$NEWIP" != "$STOREDIP" ]; then
	test $DEBUG && echo "IP change detected"
	URL="https://$USERNAME:$PASSWORD@dynupdate.no-ip.com/nic/update?hostname=$HOST&myip=$NEWIP"
	test $DEBUG && echo "Update URL: $URL"
	RESULT=$(wget -O - -q --user-agent="$USERAGENT" --no-check-certificate "$URL")
	test $DEBUG && echo "Update Result: $RESULT"

	echo "[$DATE] $RESULT" >>$LOGFILE
	if [ "$RESULT" == "good $NEWIP" ]; then
		# We have a successfull change!
		echo $NEWIP > $STOREDIPFILE
	elif [ "$RESULT" == "nochg $NEWIP" ]; then
		# There is no change
		break
	else
		# We received an error
		echo $RESULT > $DIR/error
		echo "The error code received is $RESULT. Alternatively, it can also be found in '$DIR/error'." >& 2
		if [ "$RESULT" == "911" ]; then
			# API states that we should wait 30 minutes, so let's
			# create a temporary lock file
			echo "Problems with the servers. Let's try in 30 minutes" >& 2
			touch $DIR/lock_temp
			exit 66
		elif [ "$RESULT" == "nohost" ]; then
			echo "Hostname does not exist." >& 2
			touch $DIR/lock
			exit 67
		elif [ "$RESULT" == "badauth" ]; then
			echo "Username/password is not valid." >& 2
			touch $DIR/lock
			exit 68
		elif [ "$RESULT" == "badagent" ]; then
			echo "We have been blacklisted. Please contact support@afrosoft.tk." >& 2
			touch $DIR/lock
			exit 69
		elif [ "$RESULT" == "!donator" ]; then
			echo "This should not happen. Please contact support@afrosoft.tk." >& 2
			touch $DIR/lock
			exit 70
		elif [ "$RESULT" == "abuse" ]; then
			echo "Your account is blocked. Please contact http://www.no-ip.com/ticket/ ." >& 2
			touch $DIR/lock
			exit 71
		fi
	fi
else
	test $DEBUG && echo "No IP change detected"
	echo "[$DATE] No IP change" >> $LOGFILE
fi

exit 0

