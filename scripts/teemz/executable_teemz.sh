#!/bin/bash

Help()
{
	echo "                                                   ";
	echo ".-,.-.,-.  )\.---.   )\.---.   )\   )\  .\`\`\`./(    ";
	echo ") ,, ,. ( (   ,-._( (   ,-._( (  ',/ /  )_,-,  )   ";
	echo "\( |(  )/  \  '-,    \  '-,    )    (       / / _  ";
	echo "   ) \      ) ,-\`     ) ,-\`   (  \(\ \     / \`-\` ) ";
	echo "   \ (     (  \`\`-.   (  \`\`-.   \`.) /  )   (     (  ";
	echo "    )/      )..-.(    )..-.(       '.(     ).',,'  ";
	echo "                                                   ";
	echo "Utility to manage your Microsoft Teams status on Mac"
	echo
	echo "Syntax: teemz [-t <time>|-i|-r|-n <time>|-N <time>|-d <time>|-D <time>|-h]"
	echo "Options:"
    echo "    -t   Sets amount of time to run for (format: #h#m, #h, or #m)"
    echo "         Example: -t 2h30m, -t 1h, -t 45m"
	echo "    -i   Sets program to run infinitely, until stopped"
	# echo "    -s   Stealth mode. Displays mock server responses instead of Teams Status Refreshed"
	echo "    -d   Sets minimum random delay in hours and minutes (default: 5m) (format: #m)"
    echo "         Example: -d 3m"
	echo "         Note: By default, Microsoft Teams checks your status every 5 minutes."
	echo "               A minimum delay over 5 minutes will cause you to go idle."
	echo "    -h   Displays this help text"
	echo
	echo "Realism Mode Options:"
	echo "    -r   Realism mode. Enables a random additional delay of 2-4 minutes between status refreshes, once every 30-60 minutes."
	echo "         Note: Can be configured with -n, -N, -d, and -D options."
	echo "    -n   Sets minimum delay timer in hours and minutes for realism mode (default: 20m) (format: #h#m, #h, or #m)"
	echo "         Example: -n 2h30m, -n 1h, -n 45m"
    echo "    -N   Sets maximum delay timer in hours and minutes for realism mode (default: 1h) (format: #h#m, #h, or #m)"
	echo "         Example: -N 2h30m, -N 1h, -N 45m"
    echo "    -D   Sets maximum random delay in seconds. (default: 12m) (format: #m)"
    echo "         Example: -D 5m"
	echo "         Note: Only works in realism mode. Random delay will be added once every n-N minutes, if configured."
	echo
	echo "Examples:"
    echo "    teemz -i                          # Run indefinitely with default 5 minute refresh"
    echo "    teemz -t 4h                       # Run for 4 hours"
    echo "    teemz -i -r                       # Run indefinitely with default random delays"
    echo "    teemz -t 8h -r -n 15m -N 45m      # Run for 8 hours with random delays every 15-45 minutes"
    echo "    teemz -i -r -d 5m -D 16m          # Run indefinitely with 5-16 minute random delays every 20-60 minutes"
	echo
}

# status_msg="Teams Status Refreshed"
# random_delay_msg="Random Delay Added"
# idle_msg="Going idle for"

caffeinate_pid=""

status_msg="SUCCESS: Server responded 200 OK."
random_delay_msg="INFO: Delay detected."
idle_msg="WARN: Server idled for"

random_delay=false
last_random_time=$(date +%s)
min_delay_timer=1200
max_delay_timer=3600
min_delay=300
max_delay=720

Exit()
{
    if [ ! -z "$caffeinate_pid" ]; then
        kill $caffeinate_pid 2>/dev/null
        #clear
        echo "[$(date +%H:%M:%S)] Process finished."
    fi
    exit 0
}


trap Exit SIGINT SIGTERM EXIT

GetRandomDelay()
{
    # Return random delay between 1800-3600 (30-60 minutes)
    echo $(($min_delay_timer + RANDOM % ($max_delay_timer - $min_delay_timer)))
}

ParseTime()
{
    local time_str=$1
    local hours=0
    local minutes=0

    if [[ $time_str =~ ([0-9]+)h ]]; then
        hours=${BASH_REMATCH[1]}
    fi
    if [[ $time_str =~ ([0-9]+)m ]]; then
        minutes=${BASH_REMATCH[1]}
    fi

    echo $((hours * 3600 + minutes * 60))
}

FormatTime()
{
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))

    if [ $hours -gt 0 ] && [ $minutes -gt 0 ]; then
        echo "${hours}h${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h"
    else
        echo "${minutes}m"
    fi
}

Startup()
{
    echo "[$(date +%H:%M:%S)] INFO: Starting process."
    if [ "$random_delay" = true ]; then
        echo "[$(date +%H:%M:%S)] RAND: Every $(FormatTime $min_delay_timer) to $(FormatTime $max_delay_timer) for $(FormatTime $min_delay) to $(FormatTime $max_delay)."
    else
        echo "[$(date +%H:%M:%S)] INFO: Refreshing every $(FormatTime $min_delay)."
    fi

    if [ "$infinite_mode" = true ]; then
        echo "[$(date +%H:%M:%S)] INFO: Running indefinitely."
    elif [ "$timed_mode" = true ]; then
        echo "[$(date +%H:%M:%S)] INFO: Running for $(FormatTime $duration)"
    fi
}

current_random_time=$(GetRandomDelay)

ActivateTeams()
{
	current_time=$(date +%s)
	osascript -e 'tell application "Microsoft Teams" to activate'
	osascript -e 'tell application "System Events" to keystroke "4" using {command down}'

	echo "[$(date +%H:%M:%S)] $status_msg"
	if [ "$random_delay" = true ] && [ $((current_time - last_random_time)) -ge $current_random_time ]; then
        # Add random 2-4 minute delay
		echo "[$(date +%H:%M:%S)] $random_delay_msg"
        random_sleep=$(($min_delay + RANDOM % ($max_delay - $min_delay)))
        echo "[$(date +%H:%M:%S)] $idle_msg $((($random_sleep - $min_delay) / 60)) minutes."
        sleep $random_sleep
        last_random_time=$current_time
		current_random_time=$(GetRandomDelay)
    else
        sleep $min_delay
    fi
}

while getopts "hit:rn:N:d:D:" option; do
    case $option in
        n) # Set minimum delay timer
            min_delay_timer=$(ParseTime "$OPTARG")
            if [ $min_delay_timer -eq 0 ]; then
                echo "ERR: Invalid time format. Use format like 1h, or 30m"
                exit 1
            fi
            ;;
        N) # Set maximum delay timer
            max_delay_timer=$(ParseTime "$OPTARG")
            if [ $max_delay_timer -eq 0 ]; then
                echo "ERR: Invalid time format. Use format like 1h, or 30m"
                exit 1
            fi
            if [ $max_delay_timer -le $min_delay_timer ]; then
                echo "ERR: Maximum delay must be greater than minimum delay"
                exit 1
            fi
            ;;
        d) # Set minimum random delay
            min_delay=$(ParseTime "$OPTARG")
			echo "$min_delay"
            if [ $min_delay -eq 0 ]; then
                echo "ERR: Invalid time format. Use format like 2m"
                exit 1
            fi
            ;;
        D) # Set maximum random delay
            max_delay=$(ParseTime "$OPTARG")
            if [ $max_delay -eq 0 ]; then
                echo "ERR: Invalid time format. Use format like 4m"
                exit 1
            fi
            if [ $max_delay -le $min_delay ]; then
                echo "ERR: Maximum delay must be greater than minimum delay"
                exit 1
            fi
            ;;
        # s)
        #     status_msg="SUCCESS: Server responded 200 OK."
        #     random_delay_msg="INFO: Delay detected."
        #     idle_msg="WARN: Server idled for"
        #     ;;
        r) # Enable random delays
            random_delay=true
            ;;
        h) # Display helper text
            Help
            exit
            ;;
        t) # Set timed mode
            timed_mode=true
            duration=$(ParseTime "$OPTARG")
            if [ $duration -eq 0 ]; then
                echo "ERR: Invalid time format. Use format like 2h30m, 1h, or 45m"
                exit 1
            fi
            ;;
        i) # Set infinite mode
            infinite_mode=true
            ;;
        \?) # Invalid option
            echo "ERR: Invalid option. Use teams-status -h for help"
            exit
            ;;
    esac
done

if [ $# -eq 0 ]; then
    Help
    exit 1
fi

if [ "$infinite_mode" = true ]; then
    Startup
    caffeinate -d & caffeinate_pid=$!
    while true; do
        ActivateTeams
    done
elif [ "$timed_mode" = true ]; then
    end_time=$(($(date +%s) + duration))
    Startup
    caffeinate -d & caffeinate_pid=$!
    while [ $(date +%s) -lt $end_time ]; do
        ActivateTeams
    done
fi
