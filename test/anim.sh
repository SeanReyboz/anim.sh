#!/usr/bin/env bash

#------------------------------------------------------------------------------
# Desc     - Stream animes locally
# Author   - Sean Reyboz <seanreyboz@tuta.io>
# Created  - 2021-08-15
# Modified - 2021-08-19
#------------------------------------------------------------------------------
#                          ----- DISCLAIMER -----
#             THIS PROGRAM WAS CREATED FOR LEARNING PURPOSES ONLY,
#                AND SHOULD ONLY BE USED AS LEARNING MATERIAL.
#               -----------------------------------------------
#
# Exit status:
#    0:   success
#    1:   program error
#    2:   user input error
#    130: sigint
#
# Dependencies:
#    - curl
#    - sed
#    - mpv (or any video player capable of playing a video from its URL).
#
# Known issues:
#    - Sometimes, video links of the chosen anime are deleted from the server.
#      As the script will be unable to find suitable links, it will throw an
#      error and prompt the user to choose another episode or try again later.
#
# TODO: Find another server to retrieve the videos from in order to improve
#       reliability and stability.
#

prog=${0##*/}
ver="2021-08-16"

# player MUST be able to play urls. Default: mpv
player="mpv"

# colors (bold)
red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
magen='\e[1;35m'
cyan='\e[1;36m'
rst='\e[0m'

prompt="$green>$rst "

trap "printf '\nSIGINT received... %b.\n' \"${red}Exiting{$rst}\" 1>&2; exit 130" INT

# Error handling
err () {
	printf "${red}Error:${rst} %s\n" "$1" 1>&2
	[ "$2" -gt 0 ] && exit "$2"
}

# Debug function
debug () {
	[ "$debug" ] && printf "${magen}DEBUG> ${yellow}%s${rst}: '%s'\n" "$1" "$2"
}

# usage()
# help/usage message
usage () {
	while IFS= read; do
		printf '%b\n' "$REPLY"
	done <<-EOF
			Usage: $prog -s <query> [-h] [-v]

			Options:
			  -s, --search        - Search for the anime given in parameter
			  -d, --debug         - Search for anime in debug mode
			  -h, --help          - Display this help and exit
			  -v, --version       - Display the version of $prog and exit
	EOF
}

# checkDeps()
# Check dependencies
checkDeps () {
	deps=(
		"curl"
		"sed"
		"$player"
	)

	for dep in "${deps[@]}"; do
		command -v "$dep" 1>/dev/null || err "Please install '$dep' to use $prog" 1
	done
	debug "Dependencies" "Checked"
}

# checkHealth()
# Make sure the internet and the server are both up and running
checkHealth () {
	if ! ping -c 1 wikipedia.com &>/dev/null; then
		err "Ooops. It looks like your internet is down." 1
	elif ! ping -c 1 gogoanime.vc &>/dev/null; then
		err "The server is not reachable. Try again later." 1 
	fi
	debug "Health" "Checked"
}

# searchAnime()
# Get a list of the anime(s) matching the user's query, and display them to
# stdout, before calling `animeSelection`
searchAnime () {
	url="https://gogoanime.vc//search.html"
	id=0
	data=
	query=

	# check dependencies
	checkDeps
	# check connectivity
	checkHealth

	# Check whetever the user provided the -s option with a parameter
	if [ -z "$1" ]; then
		printf "%s\n$prompt" "What is the name of the anime you're looking for?"
		read -r query
	else
		query=$1
	fi

	# Url encode the query to prevent any weird behavior from curl 
	data="keyword=$(urlencode "$query")"
	debug "Urlencoded query" "$data"

	# Get all the animes that match the query, if any
	searchResult=$(curl -s "$url" -G -d "$data" 2>/dev/null |
		sed -r -n 's/^[[:space:]]+<a href="\/category\/(.+)" title="(.*)">.*$/\1 \2/p')

	if [ -n "$searchResult" ]; then
		printf "\n $green%-18s %-s$rst\n\n" 'ID' 'NAME'

		while read _ name; do
		 	printf ' %-10b %-b\n' "$id" "${cyan}$name${rst}"
			(( id++ ))
		done <<< "$searchResult"
	else
		err "Couldn't find any anime matching your query." 1
	fi

	# Prompt the user to choose one of the anime in the list
	animeSelection
}

# animeSelection()
# Prompts the user to choose one of the animes retrieved by `searchAnime`, and
# verifies that the input is correct, before calling `getEpsisodes`
animeSelection () {
	count=0

	# Prompt the user to select an anime
	printf "\n%s\n$prompt" "Select the anime's ID you want to watch"
	read -r input

	# Verify that input is a number
	[ "$input" -eq "$input" ] 2>/dev/null || err "Not a number." 2

	# Get the url of the selected anime
	while read line _; do
		[ "$input" -eq "$count" ] && selectedAnime=$line
		(( count++ ))
	done <<< "$searchResult"

	(( count-- )) 		# Max number of episodes (i.e episodes - 1)

	# Check for invalid anime ID
	if [ "$input" -gt "$count" ] || [ "$input" -lt 0 ]; then
		err "Invalid anime ID (out of range)." 2
	fi

	# DEBUG:
	debug 'Selected anime is' "$selectedAnime"

	# Get the available episodes for the selected anime
	getEpsisodes
}

# getEpsisodes()
# Get the maximum number of episodes available for the selected anime, and
# prompt the user to choose one to watch, before calling `getLink`
getEpsisodes () {
	url="https://gogoanime.vc/category/$selectedAnime"

	# Get the maximum number of episodes for the selected anime
	episodes=$(curl -s "$url" |
		sed -n -E "s/[[:space:]]+<a href=\"#\" class=\"active\" ep_start.* ep_end = '([0-9]*)'.*/\1/p")

	[ -z "$episodes" ] && err "Can't get any episode for '$selectedAnime'" 1

	printf "%b\n%b" "Select an episode: [${yellow}1-$episodes${rst}]" "$prompt"
	read -r choosedEp

	# Make sure choosedEp is a number AND is not invalid
	[ "$choosedEp" -eq "$choosedEp" ] 2>/dev/null || err "Not a number." 2

	if [ "$choosedEp" -gt "$episodes" ] || [ "$choosedEp" -le 0 ]; then
		err "Invalid episode number (out of range)." 2
	fi

	# Get all the potentially downloadable links
	getLink
}

# getLink()
# Tries to retrieve a video link for the specified episode and calls `playAnime`
getLink () {
	if [ -n "$1" ]; then
		case $1 in
			-)
				(( choosedEp-- )) ;;
			+)
				(( choosedEp++ )) ;;
		esac
		printf '%s\n' "Getting video link for episode $choosedEp..."
	fi

	url="https://gogoanime.vc/$selectedAnime-episode-$choosedEp"
	debug "Episode url" "$url"

	link=$(curl -s "$url" |
		sed -r -n 's/^[[:space:]]+<li class="down?loads?".* href="(.*)" target.*/\1/p')

	video=$(curl -s "$link" | sed -r -n 's/.*href="(.*.mp4)".*>Download$/\1/p')

	debug 'Video link' "$video"

	# Handle empty links
	if [ -n "$video" ]; then
		playAnime "$video"
	else
		err "Could not find a link for the specified episode" 0
		getEpisodes
	fi
}

# playAnime()
# Play the video link in the player
playAnime () {
	debug "Remote video link(s)" "$video"

	if $player "$video" &>/dev/null; then
		postEpisode
	else
		err "Unable to play this episode. Try again later, or try another episode." 0
		getEpsisodes
	fi
}

# postEpisode()
# Prompts the user to choose what to do at the end of the episode.
postEpisode () {
	printf '\n%s\n' "Episode ended."
	printf 'Next Episode [%bN%b] - ' "$green" "$rst"
	printf 'Previous Episode [%bp%b] - ' "$green" "$rst"
	printf 'Quit [%bq%b]\n%b' "$yellow" "$rst" "$prompt"
	read -r choice

	case "$choice" in
		[Nn]|next|'')
			getLink "+"
			;;
		p|previous)
			getLink "-"
			;;
		q|quit)
			exit 0
			;;
		*)
			err "Invalid option '$choice'" 2
			;;
	esac
}

# urlencode() (by Dylan Araps)
# Converts a string into a URL encoded version of that string and prints 
# it out to stdout.
urlencode () {
	local LC_ALL=C
	for (( i = 0; i < ${#1}; i++ )); do
		: "${1:i:1}"
		case "$_" in
			[a-zA-Z0-9.~_-])
				printf '%s' "$_"
			;;

			*)
				printf '%%%02X' "'$_"
			;;
		esac
	done
	printf '\n'
}

while [ "$1" ]; do
	case $1 in
		-s|--search)
			searchAnime "$2"
			;;
		-d|--debug)
			debug=:
			searchAnime "$2"
			;;
		-h|--help)
			usage; exit 0
			;;
		-v|--version)
			printf '%s\n' "$prog: $ver"; exit 0
			;;
		-*)
			err "Invalid option(s) '$2'" 2
			;;
		*)
			exit 0
			;;
	esac
done

