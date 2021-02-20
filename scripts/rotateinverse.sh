#!/bin/sh
xrandr --output DisplayPort-0 --off --output eDP --rotate inverted --auto
xinput set-prop pointer:"ELAN2514:00 04F3:2AF0" --type=float "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
xinput set-prop "ELAN2514:00 04F3:2AF0 Pen (0)" --type=float "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
xinput set-prop "ELAN2514:00 04F3:2AF0 Eraser (0)" --type=float "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
echo -n "2" > /home/tim/scripts/currentrotation
pkill -9 polybar
pkill -9 picom
touch /home/tim/.config/i3/display_already_setup
i3-msg restart
