#!/bin/bash

LOG_SIZE=10485760 # after this size (in byte) the log is rotated
DAYS_2_ROTATE=7   # but only after these days has been passed
RETENTION=52      # how many logs to keep?

DEBUG=0	# 1=enable verbose logging, 0=normal logging

log(){
        echo -n "$(date +%a" "%d-%m-%Y" "%H:%M:%S) --- "
        echo "$1"
}

debug(){
	if [ $DEBUG -eq 1 ]; then
		log "$1"
	fi
}

if [ -z "$1" ]; then
        log "no logs to rotate"
        exit 1
fi

log_rotate(){
        LOG_R="$1"
        if [ -d "$1" ]; then
                for logfile in $(ls "$1"); do
                        log_rotate "$1/$logfile"
                done
        else
                EXT=${LOG_R:(-4)}
                if [ "$EXT" = ".log" ] || [[ "$LOG_R" =~ (.*mainlog$|.*rejectlog$|.*paniclog$) ]] ; then
                        size="$(stat -c %s "$LOG_R" 2>/dev/null || echo "0")"
			# check if exists the first rotated log file
			# and catch the modified date.
			# otherwise set the modified date to the 01 Jan 1970 first second ;-)
			if [ -f "$LOG_R".1.gz ]; then
				mod_date="$(stat -c %Y "$LOG_R".1.gz)"
			else
				mod_date=1
			fi
			retention_date="$[$mod_date + $[$DAYS_2_ROTATE * 3600 * 24]]"
			today_epoch="$(date +%s)"
			debug "$LOG_R file size: $size, mod_date=$mod_date, retention_date=$retention_date, today_epoch=$today_epoch"
                        if [ -s "$LOG_R" ] && [ $size -gt $LOG_SIZE ] && [ $today_epoch -gt $retention_date ]; then
                                for num in $(seq $[$RETENTION - 1] -1 1); do
                                        if [ -f "$LOG_R".$num.gz ]; then
                                                mv "$LOG_R".$num.gz "$LOG_R".$[$num+1].gz
                                        fi
                                done
                                if [ -f "$LOG_R" ]; then
                                        log "Rotating $LOG_R"
                                        cp "$LOG_R" "$LOG_R".1
                                        cat /dev/null > "$LOG_R"
                                        gzip -9 "$LOG_R".1
                                fi
                        else
                                if [ -f "$LOG_R" ]; then
					if [ $today_epoch -le $retention_date ]; then
						log "$LOG_R.1.gz is not enough old to be rotated"
					else
	                                        log "$LOG_R has size < $LOG_SIZE bytes, not rotating"
					fi
                                else
                                        log "$LOG_R does not exists"
                                fi
                        fi
                else
			if [[ "$LOG_R" =~ (.*\.gz$) ]] ; then
				debug "we don't touch $LOG_R"
			else
	                        log "$LOG_R file will not be rotated (for security reason only files with '.log' extensions or 'mainlog|rejectlog|paniclog' names will be parsed"
			fi
                fi
        fi
}

log_rotate "$1"
