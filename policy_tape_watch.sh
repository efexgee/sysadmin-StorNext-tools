#!/bin/bash

# watches current tape activity for a specified Stornext policy
# prints which media IDs are in which drive and how many files it has on it

TIMEOUT=300 #in seconds
TIMEOUT=60 #in seconds

# check arg count
if (( $# != 1 )); then
    echo "Usage: $0 <policy name>"
    exit
fi

policy=$1

# check for root
if (( `id -u` != 0 )); then
    echo "You will probably need to be logged in as root to run this."
    echo "sudo $0 will not suffice because you will need root's environment"
    exit 2
fi

PMDC=`pmdc 2>&1`

# check for environment
if (( `echo $PMDC | wc -w` != 1 )); then
    echo "Looks like the pmdc command failed."
    echo "Is your environment set up correctly?"
    echo "Are you logged in as root?"
    exit 3
fi

# check for PMDC
if [ $PMDC != `hostname -s` ]; then
    echo "Looks like you are not on the primary domain controller"
    echo "pmdc output: "`pmdc`
    exit 4
fi

# check for valid policy
fsclassinfo $policy > /dev/null 2>&1 || echo exit

if ! fsclassinfo $policy > /dev/null 2>&1 ; then
    echo "Looks like there is no policy called $policy"
    exit 5
fi

printing_dots=false

while true; do
    # loop through all the policy's tapes which are mounted in drives (-ld option)
    media_list=`fsmedlist -c $policy -ld -F json | jq -r 'if .classes[].inDrive.total > 0 then .classes[].inDrive.medias[] | [.mediaId, .copies] | @csv else "" end' | tr -d '"'`

    if [ -z "$media_list" ]; then
        echo -n '.'
        printing_dots=true
    else
        # for each of the policy's tapes that are in a drive
        for media in $media_list; do
            if $printing_dots; then
                # print a newline to end the line of dots
    		    echo
            else
                printing_dots=false
            fi
    
            # grab media ID and copy number
            media_id=`echo $media | cut -d, -f1`
            copy_num=`echo $media | cut -d, -f2`

            # look up the drive ID it's mounted in
            drive=`fsstate | grep $media_id | awk '{print $1}'`
    
            # look up how many files (file segments) are on the tape
            files=`fsmedinfo $media_id -F JSON | jq '.medias[] | .numberOfSegments'`
    
            # print the info for that tape (without a newline)
            printf "%s: %s(%d) %'d " $drive $media_id $copy_num $files

            # cap off the line and highlight the drive ID
            done | egrep --color=always '([SI][^ ]*dr[0-9]*|$)'
    fi

    # wait
    sleep $TIMEOUT
done
