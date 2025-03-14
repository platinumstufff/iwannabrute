<h1 align="center">iwannabrute</h1>
<p align="center">
Bruteforce A5-A6 numeric password with ease.
</p>

# Prerequsites

1. A computer running macOS.
2. A compatible device (A5-A6)

# Usage
iwannabrute needs initial setup before usage.
 - Homebrew: `brew install bash curl libusb`
 - MacPorts: `sudo port install bash curl libusb`
 - For macOS 12.7.6 and lower, use MacPorts, not Homebrew.
 
1. Clone and cd into this repository: `git clone https://github.com/platinumstufff/iwannabrute --recursive && cd iwannabrute`
2. Place your device into DFU mode
3. Run ./start.sh

# Estimated bruteforce time

| Passcode length | Finish time (80 ms/p) | 30 ms/p |
| ------------ | ------------ | ------------ |
4-digit |13 minutes |5 minutes
5-digit |2 hours |50 minutes
6-digit |22 hours |8 hours
7-digit |9 days |3.5 days
8-digit |92 days |35 days

The tool will use the AES engine as much as possible with no restrictions at the full speed. 80 milliseconds is a value that Apple uses to calibrate it's software to this day.


# Soon™

- Linux support
- A4 support
- Disable password automatically

# Other Stuff

- [Reddit Post]()

# Credits
- [AJAIZ](https://github.com/AsyJAIZ) for original bruteforce method.
- [mewcat454](https://www.reddit.com/u/meowcat454) for original ramdisk.
- [Nathan](https://github.com/verygenericname) for some code from SSHRD_Script.
- [LukeeZGD](https://github.com/LukeZGD) for a lot code.
- And anyone else I forgot to mention.
