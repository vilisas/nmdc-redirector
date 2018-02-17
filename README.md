# NMDC HUB Emulator

A simple way to redirect users to another hub

to use: 
edit redirector.pl, change port, hub addresses, name, etc..

install screen package, in debian you can do it by executing this command:

$ sudo apt-get install screen 

launch it:

$ screen perl ./redirector.pl

to stop script press Ctrl+C


to leave screen running in background press Ctrl+A then d

to reattach running screen session type in your shell

$ screen -r

and for security reasons never run hub or script as root =)


