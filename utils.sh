# This file contains functions required by other nginx-rtmp-backup scripts

die() { # Exit with the proper stderr output
	echo "$CURRENT_APPLICATION_NAME: $*" >&2
	exit 1
}

parse_argv() {	# Checks that the streamname for scripts is provided
				# and set the variable
	[ "$#" -ge 1 ] || die "too few arguments"
	STREAMNAME=$1
}

pid_for() { # Gets a pid, according to stream kind (main/backup) and streamname
	echo "$PIDS_FOLDER/$1_$STREAMNAME.pid"
}

is_running() {	# Checks if the process pushing stream
				# of provided kind (main/backup) is running
	pidfile="$(pid_for "$1")"
	echo $pidfile
	[ -r "$pidfile" ] && pgrep --pidfile "$pidfile"
}

get_var() { # Gets variable value by its name
	eval echo "$"$1""
}

kill() {	# Kills a process pushing stream of provided kind (main/backup)
			# if it is running and removes its pidfile
	if is_running "$1"; then
		pidfile="$(pid_for "$1")"
	echo "got pidfile for killing"
		/bin/kill -9 "$(cat "$pidfile")" > /dev/null
		rm -f "$pidfile"
	fi
}

assert_one_of() { # Checks that the value for a variable provided in config is rigth
	varname="$1"; shift # Get variable name and remove it from arguments list
	value="$(get_var $varname)"
	expected="$*" # Values left in arguments list are expected values

	while [ "$#" -gt 0 ]; do
		if [ "$value" = "$1" ]; then return; fi # If a value of the varibale is one of the expected, return
		shift
	done

	# If we are here, the variable value do not match any of expected, exit
	die "unexpected value \`$value' for \`$varname' (expected one of '$expected')"
}

push_stream() { # Starts pushing stream
	stream_kind="$1" # backup or main
	# Get a value of either $MAIN_STREAM_NAME or $BACKUP_STREAM_NAME
	appname="$(get_var "$(echo "${stream_kind}_STREAM_APPNAME" | tr '[:lower:]' '[:upper:]')")"

	LOGFILE="$LOGS_FOLDER/${appname}_${STREAMNAME}.log"

	assert_one_of RUNNER avconv ffmpeg

	nohup "$RUNNER" \
		-re -i "rtmp://localhost/$appname/$STREAMNAME" \
		-threads 8 \
        -c:a aac -b:a 128k -c:v libx264 -b:v 3500k -f flv -g 30 -r 30 -s 1920x1080 -preset medium -profile:v baseline "rtmp://localhost:1935/${OUT_STREAM_APPNAME}/${STREAMNAME}_1080p3500kbs" \
        -c:a aac -b:a 128k -c:v libx264 -b:v 2500k -f flv -g 30 -r 30 -s 1280x720 -preset medium -profile:v baseline "rtmp://localhost:1935/${OUT_STREAM_APPNAME}/${STREAMNAME}_720p2628kbs" \
        -c:a aac -b:a 128k -c:v libx264 -b:v 1000k -f flv -g 30 -r 30 -s 854x480 -preset superfast -profile:v baseline "rtmp://localhost:1935/${OUT_STREAM_APPNAME}/${STREAMNAME}_480p1128kbs" \
		-c:a aac -b:a 64k -c:v libx264 -b:v 200k -f flv -g 15 -r 15 -s 426x240 -preset superfast -profile:v baseline "rtmp://localhost:1935/${OUT_STREAM_APPNAME}/${STREAMNAME}_240p264kbs" \
		-max_muxing_queue_size 9999
		\
		</dev/null \
		>"$LOGFILE" \
		2>&1 \
		&

	echo $! > "$(pid_for "$stream_kind")"
}
