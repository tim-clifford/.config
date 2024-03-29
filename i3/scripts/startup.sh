#!/bin/sh

_METACONF_REPLACE_LOAD_TOUCHSCREEN_TOOLS $HOME/.config/scripts/start-plank.sh

_METACONF_REPLACE_LOAD_CACHE_FILESYSTEMS onedrive -m --confdir $HOME/.config/onedrive --syncdir $HOME/OneDrive-Cam &
_METACONF_REPLACE_LOAD_CACHE_FILESYSTEMS onedrive -m --confdir $HOME/.config/onedrive-personal --syncdir $HOME/OneDrive-Personal &
_METACONF_REPLACE_LOAD_CACHE_FILESYSTEMS dropbox &

_METACONF_REPLACE_LOAD_NETWORK_FILESYSTEMS google-drive-ocamlfuse $HOME/GoogleDrive-Work -label default -f &
_METACONF_REPLACE_LOAD_NETWORK_FILESYSTEMS google-drive-ocamlfuse $HOME/GoogleDrive-Cam -label cam -f &
_METACONF_REPLACE_LOAD_NETWORK_FILESYSTEMS google-drive-ocamlfuse $HOME/GoogleDrive-Personal -label personal -f &

$HOME/.config/i3/scripts/titlebar.sh &

wait
