echo
echo "[LOG: $(date -Isec) ]"

#!/bin/sh
if [ "$(cat /etc/hostname)" = "tim-desktop" ]; then
	echo "please run from laptop"
	exit 1
fi

set_settings() { # $1: settings file
	perl -i -pe 'BEGIN{undef $/;} s/\[Settings\].*?\n\n/'"$(cat $1)"'/smg' \
		~/.config/rncbc.org/QjackCtl.conf
}

trap 'trap_exit' 2
trap_exit() {
	exit 1
}

kill_and_wait() { #1: ps regex
	pid=$(ps ax | egrep "$1" | grep -v 'grep' | awk '{print $1}' | grep -v $$)
	if ! [ -z $pid ]; then kill $pid; fi
	while ! [ -z $(ps ax | egrep "$1" | grep -v 'grep' | awk '{print $1}' \
			| grep -v $$) ]
	do
		sleep 0.1
		echo "Waiting"
	done
}

# kill other instances
kill $(ps ax | egrep 'sh.*start_jack.sh$' | awk '{print $1}' | grep -v $$)

# kill qjackctl if it's running
pkill qjackctl

if ssh -o "BatchMode=yes" -o "ConnectTimeout=1" tim-desktop-local "exit" \
		2>/dev/null;
then
	# connected to desktop, do net things
	echo -e "\e[33m====> Using net configuration\e[0m"
	ssh tim-desktop-local 'jack_load netmanager -i -c'
	set_settings ~/.config/jack/qjackctl-tim-laptop-net.conf
	qjackctl -a ~/.config/jack/tim-laptop-net.xml &
	sleep 1
	ssh tim-desktop-local 'DISPLAY=:0 qjackctl -a ~/.config/jack/tim-desktop-net.xml'

elif lsusb | grep -q 08bb:2902; then
	# connected to audio device, do alsa things
	echo -e "\e[33m====> Using alsa configuration\e[0m"
	set_settings ~/.config/jack/qjackctl-tim-laptop-alsa.conf
	qjackctl -a ~/.config/jack/tim-laptop-alsa.xml &

else
	# otherwise use dummy driver
	echo -e "\e[33m====> Using dummy configuration\e[0m"
	set_settings ~/.config/jack/qjackctl-tim-laptop-dummy.conf
	qjackctl -a ~/.config/jack/tim-laptop-dummy.xml &
fi

# Keep checking for bluetooth headphones
while :; do
	while bluealsa-aplay -l | grep -q 88:D0:39:D7:A8:34; do
		echo -e "\e[33m====> Connecting to headphones...\e[0m"
		kill_and_wait 'alsa_out -d bluealsa'
		# make sure pulseaudio module loads
		if ! pactl list modules | grep -q "Name: module-jack-sink"; then
			while ! pactl load-module module-jack-sink >/dev/null 2>&1; do
				sleep 0.1
			done
			echo -e "\e[32m====> Loaded Pulseaudio Jack sink\e[0m"
		fi
		alsa_out -d bluealsa -p 4096
	done
	# make sure pulseaudio module unloads
	if pactl list modules | grep -q "Name: module-jack-sink"; then
		while ! pactl unload-module module-jack-sink >/dev/null 2>&1; do
			sleep 0.1
		done
		echo -e "\e[32m====> Unloaded Pulseaudio Jack sink\e[0m"
	fi
	sleep 2 # don't spam if it's not connected
done