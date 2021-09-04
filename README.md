
# Anim.sh &ndash; Stream Anime Locally.


![anim.sh preview](./preview/preview.gif)


### Table of Contents

* [About anim.sh](#about-animsh)
	- [Usage](#usage)
	- [Dependencies](#dependencies)
	- [Disclaimer](#disclaimer)
* [Installation](#installation)
* [Uninstall](#uninstall)
* [Known Issues](#known-issues)

## About anim.sh?

`anim.sh` is a pretty simple shell script that allows you to stream animes
locally on *mpv*(1), or any other player that supports URLs.

### Usage

Once `anim.sh` is installed on your system, simply run...

```shell
anim.sh "name of the anime"
```
...to start watching the desired anime.

### Dependencies

To work properly, `anim.sh` relies on *sed*(1), *curl*(1), *ping*(8)
and *mpv*(1), so you will have to install these programs in order to use
`anim.sh`.
<br>
<br>
**Note**: Even though `anim.sh` was written to use *mpv*(1), it is possible to
use a different player. However, it **must** be capable of playing videos from
a URL.
<br>
If you want to use another player, simply open `anim.sh` in your text editor
of choice, and modify the value of the variable `player`.

```sh
player="mpv"
```

### Disclaimer

This script was written for learning purposes *only*.
<br>
This "program" is distributed as is, without any form of warranty.

## Installation

The installation process requires root privileges.
<br>
The one-liner below assume that you have *sudo*(8) and *curl*(1) installed on
your system.

```shell
curl -O https://raw.githubusercontent.com/SeanReyboz/anim.sh/main/anim.sh && sudo chmod 755 anim.sh && sudo mv anim.sh /usr/bin/
```

## Uninstall

To remove `anim.sh` from your system, simply run the following command
**_as root_**:

```shell
rm -v /usr/bin/anim.sh
```

## Known Issues

* Some episodes of a given anime may sometimes **not** be playable because the
  video links retrieved by `anim.sh` are sometimes modified or deleted on the
  queried server.
  <br>
  As `anim.sh` will not be able to find any suitable
  links, it will throw the following error: `Could not find a link for the
  specified episode`. Your best bet is to try another episode/anime, or just
  wait until the episode gets a playable link.


