#!/bin/sh

#------------------------------------------------------------------------------
# Desc     - Stream anime locally
# Author   - Sean Reyboz <seanreyboz@tuta.io>
# Created  - 2021-08-18
# Modified - 2021-08-26 - 21:32:13 CEST
#------------------------------------------------------------------------------
#                              --- DISCLAIMER ---
#             THIS PROGRAM WAS CREATED FOR LEARNING PURPOSES ONLY,
#                       AND SHOULD ONLY BE USED AS SUCH.
#           --------------------------------------------------------
#
# Exit status:
#   0:    program success
#   1:    program error
#   2:    user input error
#   130:  interrupt signal
#
# Dependencies:
#   - curl     Retrieve web page content.
#   - mpv      Play the anime episode locally.
#   - ping     Check network connectivity and server availability.
#   - sed      Retrieve wanted data and links.
#
# Known issues:
#   - Sometimes, video links of the chosen anime are deleted from the server.
#     As the script will be unable to find suitable links, it will throw an
#     error and prompt the user to choose another episode or try again later.
#
# TODO: Find another server to retrieve the videos from in order to improve
#       reliability and stability.
#

prog=${0##*/}
ver="2021-08-26"

# player MUST be able to play urls. Default: mpv
player="mpv"

# colors (bold)
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
blue="\033[1;34m"
magen="\033[1;35m"
cyan="\033[1;36m"
rst="\033[0m"

prompt="$blue>$rst "
notify="$green*$rst "

trap "printf '\nSIGINT received. %b.\n' \"${red}Exiting${rst}\" 1>&2; exit 130" INT

# Error handling
err() {
	printf "${red}Error:${rst} %s\n" "$1" 1>&2
	[ "$2" -gt 0 ] && exit "$2"
}

# Debug function
debug() {
	[ "$debug" ] && printf "${magen}DEBUG> ${yellow}%s${rst}: '%s'\n" "$1" "$2"
}

# usage()
# help/usage message
usage() {
	while IFS= read line; do
		printf '%s\n' "$line"
	done <<-EOF
			Usage: $prog <query> [-d] [-h] [-v]

			Options:
			  -d, --debug         - Search for anime in debug (verbose) mode
			  -h, --help          - Display this help and exit
			  -v, --version       - Display the version of $prog and exit
	EOF
}

# checkDeps()
# Check dependencies
checkDeps() {
	for dep in "curl" "sed" "ping" "$player"; do
		command -v "$dep" >/dev/null || err "Please install '$dep' to use $prog" 1
	done
	debug "Dependencies" "Checked"
}

# checkHealth()
# Make sure the internet and the server are both up and running
checkHealth() {
	if ! ping -c 1 wikipedia.com >/dev/null 2>&1; then
		err "Ooops. It looks like your internet is down." 1
	elif ! ping -c 1 gogoanime.vc >/dev/null 2>&1; then
		err "The server is not reachable. Try again later." 1
	fi
	debug "Health" "Checked"
}

# searchAnime()
# Get a list of the anime(s) matching the user's query, and display them to
# stdout, before calling `animeSelection`
searchAnime() {
	url="https://gogoanime.vc//search.html"
	id=0
	data=
	query=

	checkDeps
	checkHealth

	# Check whetever the user provided the -s flag with an anime name
	if [ -z "$1" ]; then
		printf "%s\n$prompt" "What is the name of the anime you're looking for?"
		read -r query
	else
		query=$1
	fi

	# Translate input spaces to prevent errors
	data="keyword=$(urlEncodeSpaces "$query")"
	debug "Urlencoded query" "$data"

	# Get the title & proper name of every anime that match the query, if any.
	searchResult=$(curl -s "$url" -G -d "$data" 2>/dev/null |
		sed -E -n 's/^[[:space:]]+<a href="\/category\/(.+)" title="(.*)">.*$/\1 \2/p')

	if [ -n "$searchResult" ]; then
		printf "\n %-20b %-b\n\n" "${green}ID" "NAME$rst"

		while read _ name; do
		 	printf ' %-10b %-b\n' "$id" "${cyan}$name${rst}"
			id=$((id + 1))
		done <<-EOF
		$searchResult
		EOF
	else
		err "Couldn't find any results for '$query'." 1
	fi
}

# animeSelection()
# Prompts the user to choose one of the animes retrieved by `searchAnime`, and
# make sure that the input is correct
animeSelection() {
	count=0

	# Prompt the user to select an anime
	printf "\n%s\n$prompt" "Select the ID of the anime you want to watch"
	read -r input

	# Verify that input is a number
	[ "$input" -eq "$input" ] 2>/dev/null || err "Not a number." 2

	# Get the url of the selected anime
	while read line _; do
		[ "$input" -eq "$count" ] && selectedAnime=$line
		count=$((count + 1))
	done <<-EOF
	$searchResult
	EOF

	count=$((count - 1)) 		# Max number of episodes (i.e episodes - 1)

	# Check for invalid anime ID
	if [ "$input" -gt "$count" ] || [ "$input" -lt 0 ]; then
		err "Invalid anime ID (out of range)." 2
	fi

	# DEBUG:
	debug 'Selected anime is' "$selectedAnime"
}

# getEpisodes()
# Get the maximum number of episodes available for the selected anime, and
# prompt the user to choose one to watch, before calling `getLink`
getEpisodes() {
	url="https://gogoanime.vc/category/$selectedAnime"

	# Get the maximum number of episodes for the selected anime
	episodes=$(curl -s "$url" |
		sed -E -n "s/[[:space:]]+<a href=\"#\" class=\"active\" ep_start.* ep_end = '([0-9]*)'.*/\1/p")

	[ -z "$episodes" ] && err "Can't find any episode for '$selectedAnime'" 1

	printf 'Select an episode: %b\n%b' "[${yellow}1-$episodes${rst}]" "$prompt"
	read -r choosedEp

	# Make sure choosedEp is a number AND is not invalid
	[ "$choosedEp" -eq "$choosedEp" ] 2>/dev/null || err "Not a number." 2

	if [ "$choosedEp" -gt "$episodes" ] || [ "$choosedEp" -le 0 ]; then
		err "Invalid episode number (out of range)." 2
	fi

	getLink
}

# getLink()
# Tries to retrieve a video link for the specified episode and calls `playAnime`
getLink() {
	if [ -n "$1" ]; then
		case $1 in
			-)
				choosedEp=$((choosedEp - 1))
				;;
			+)
				choosedEp=$((choosedEp + 1))
				;;
		esac
		printf '%bGetting video link for episode %d...\n' "$notify" "$choosedEp"
	fi

	url="https://gogoanime.vc/$selectedAnime-episode-$choosedEp"
	debug "Episode url" "$url"

	link=$(curl -s "$url" |
		sed -E -n 's/^[[:space:]]+<li class="down?loads?".* href="(.*)" target.*/\1/p')

	video=$(curl -s "$link" | sed -E -n 's/.*href="(.*.mp4)".*>Download$/\1/p')
	debug 'Video link' "$video"

	# if a video link exists, try to play it
	if [ -n "$video" ]; then
		printf '%b%s\n' "$notify" "Now playing $selectedAnime ep. $choosedEp..."
		playAnime "$video"
	else
		err "Could not find a link for the specified episode" 0
		getEpisodes
	fi
}

# playAnime()
# Play the video link in the player
playAnime() {
	debug "Video link" "$video"

	if $player "$video" >/dev/null 2>&1; then
		# exit once the last episode has been watched.
		if [ "$choosedEp" -eq "$episodes" ]; then
			exit 0
		else
			postEpisode
		fi
	else
		err "Unable to play this episode. Try again later, or try another episode." 0
		getEpisodes
	fi
}

# postEpisode()
# Prompts the user to choose what to do at the end of the episode.
postEpisode() {
	printf '\n%b%s.\n' "$notify" "Episode ended"
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
			err "Invalid option '$choice'." 2
			;;
	esac
}

# urlEncodeSpaces() (based on Dylan Araps' split function)
# Split the input string on spaces, and reconstruct the string by replacing
# them with '%20', the URL translation for spaces, and print the result.
urlEncodeSpaces() {
	set -f

	oldIFS=$IFS
	IFS=' '
	toPrint=

	set -- $1

	for word in "$@"; do
		toPrint=$toPrint$(printf '%s%%20' "$word")
	done

	IFS=$oldIFS
	set +f

	# Get rid of the trailing '%20' & display the result
	printf '%b\n' "${toPrint%\%20}"
}

# main()
# Call the different functions to play the desired anime.
main() {
	searchAnime "$1"
	animeSelection
	getEpisodes
}

## HANDLE ARGUMENTS
case $1 in
	-d|--debug)
		debug=:
		main "$2"
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
		main "$*"
		;;
esac

