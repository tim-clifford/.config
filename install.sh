#!/bin/sh

# things that will be left to do after this script finishes
todo=""

# default arguments
vim=true
link_to_home=true
firefox=true
zsh=true
grub=true
install=true
nonfree=false
no_nonfree=false
ignore_metaconfig=false
submodules=true
help=false
for i in "$@"; do
	case "$i" in
		--help)              help=true;;
		--install=false)     install=false;;
		--link=false)        link_to_home=false;;
		--firefox=false)     firefox=false;;
		--vim=false)         vim=false;;
		--vim=minimal)       vim=minimal;;
		--zsh=false)         zsh=false;;
		--grub=false)        grub=false;;
		--grub=true)         grub=true;;
		--nonfree=true)      nonfree=true;;
		--nonfree=false)     nonfree=false;;
		--update)
			submodules=false
			;&
		--update-submodules)
			vim=true
			firefox=false
			zsh=false
			grub=false
			keyboard=false
			install=false
			nonfree=true
			;;
		--firefox-only)
			vim=false
			firefox=true
			link_to_home=false
			install=false
			zsh=false
			grub=false
			no_nonfree=true
			ignore_metaconfig=true
			keyboard=false
			;;
	esac
done
if $help; then
	echo \
"Usage: ./install.sh [OPTION]...
Install or update configurations

When the installation is finished, a new commit will be made to distinguish
between the application of metaconfigurations and any further changes.

  --help                display this help and exit
  --install=false       don't install any packages
  --link=false          don't symlink dotfiles into $HOME
  --firefox=false       don't install firefox theme
  --vim=false           don't install vimrc
  --zsh=false           don't set zsh as the default config (default is to ask)
  --grub=false          don't install grub theme (default is to ask)
  --grub=true           install grub theme (default is to ask)
  --nonfree=true        install nonfree content (default is to ask)
  --nonfree=false       don't install any nonfree content (default is to ask)
  --firefox-only        install the custom firefox theme and exit
  --update              update configurations without installing or symlinking
                        anything. Can also be used without reverting to before
                        the last use. Doesn't update submodules
  --update-submodules   like --update, but also update submodules"

	exit 0
fi

if $install || $submodules; then
	git submodule update --init --remote
fi

if ! $ignore_metaconfig; then
	# Check that there are not uncommited changes
	if ! [ "$(git diff HEAD)" = "" ]; then
		if [ "$(git log --oneline -1 --no-decorate | awk '{print $2}')" \
				= "METACONF_APPLIED" ]; then
			echo "ERROR: revert host specific configuration and commit first"
			exit 1
		else
			echo "ERROR: please commit changes first"
			exit 1
		fi
	else
		if git log --oneline --no-decorate | awk '{print $2}' \
				| grep -q METACONF_APPLIED; then
			if $update; then
				# check that only the last commit was automatic
				if git log --oneline --no-decorate | tail -n +2 | awk '{print $2}' \
						| grep -q METACONF_APPLIED; then
					echo "ERROR: host specific configurations not properly reverted"
					exit 1
				else
					git reset --hard HEAD~
					git pull
				fi
			else
				echo "ERROR: host specific configurations not properly reverted"
				exit 1
			fi

		fi
	fi
fi

if $install; then
	# Install AUR helper
	while true; do
		read -p "Install aurutils? " yn
		case $yn in
			[Yy]* )
				git clone https://aur.archlinux.org/aurutils.git
				cd aurutils
				if makepkg -si; then
					cd - >/dev/null
					rm -rf aurutils

					# Stop telling me my shell is disgusting, it's just shell ok?
					echo "
[custom]
SigLevel = Optional TrustAll
Server = file:///home/custompkgs" | sudo tee -a /etc/pacman.conf >/dev/null
					sudo install -d /home/custompkgs -o $USER
					repo-add /home/custompkgs/custom.db.tar.gz
					sudo pacman -Syu
				else
					exit 1
				fi
				break;;
			[Nn]* )
				break;;
			*)
				echo "Please respond";;
		esac
	done

	# Install packages
	INSTALL='sudo pacman -S'
	INSTALL_AUR="aur sync"
	export AUR_PAGER="$HOME/.config/scripts/rangerp.sh"

	IFS="#" # Split on the package section comment, don't care that it's hacky
	for pkgs in $(cat pkglist.conf); do
		if [ "$pkgs" = "" ]; then continue; fi
		while true; do
		read -p "Install $(echo "$pkgs" | head -n1 | sed 's/^ *//')? " yn
			case $yn in
				[Yy]* )
					# remove comment
					pkgs=$(echo "$pkgs" | tail -n +2)
					if echo "$pkgs" | egrep '^aur/'; then
						if ! eval "$INSTALL_AUR $(echo "$pkgs" \
								| sed -n 's|^aur/||p' | tr '\n' ' ')"
						then
							exit $?
						fi
					fi
					if ! eval "$INSTALL $(echo "$pkgs" \
								| sed 's|^aur/||' | tr '\n' ' ')"
					then
						exit $?
					fi
					break;;
				[Nn]* )
					break;;
				*)
					echo "Please respond";;
			esac
		done
	done
fi
IFS="
"

if ! $ignore_metaconfig; then
	# Apply metaconfig
	if [ ! -f metaconfig/$(cat /etc/hostname).metaconf ]; then
		echo "No metaconfig defined for this hostname"
		exit 1
	fi

	PREFIX=''
	POSTFIX_FILE_APPEND_PREFIX=''
	POSTFIX_FILE_APPENDED=''

	# Build file list once only. Cheaper to look at extension than use `file`
	FILETYPE_IGNORE='png svg jpg gz dll msi klc exe'

	echo "====> building file list..."
	files=$(comm -23 \
			<(git ls-tree -r --name-only $(git branch --show-current) | sort) \
			<(git submodule status | awk '{print $2}' | sort) \
		| egrep -v '\.(png|svg|jpg|pdf|gif|gz|dll|msi|klc|exe)$' \
		| xargs -I'{}' sh -c 'test -L {} || echo {}')

	echo "====> applying metaconfig variables..."
	for line in $(cat "metaconfig/$(cat /etc/hostname).metaconf"); do

		# Parse config
		if echo $line | egrep -q "^\s*#"; then
			continue
		fi

		KEY=$(echo $line | sed -n 's/^\([^ ]\+\) *= *\([^ ].*\)/\1/p')
		VAL=$(echo $line | sed -n '
			s/^\([^ ]\+\) *= *\([^ ].*\)/\2/;
			s/\([^\\]\)#.*/\1/; s/^#.*//;
			s/\\#/#/g; s/\s*$//gp
		')

		if [ "$KEY" = '' ]; then
			echo "Syntax Error: $line"
			exit 1

		elif [ "$KEY" = 'PREFIX' ]; then
			PREFIX=$VAL

		elif [ "$KEY" = 'POSTFIX_FILE_APPEND_PREFIX' ]; then
			POSTFIX_FILE_APPEND_PREFIX=$VAL

		elif [ "$KEY" = 'POSTFIX_FILE_APPENDED' ]; then
			POSTFIX_FILE_APPENDED=$VAL

		elif [ "$PREFIX" = '' ]; then
			echo "A prefix must be defined first"
			exit 1

		else
			# Apply to all files, skipping non-ascii and ignoring sed errors
			echo "$files" | xargs -n1 sed -i "s/$PREFIX$KEY/$VAL/g"
		fi

		echo "  ==> set $KEY to $VAL"
	done

	# Apply file appends
	if [ "$POSTFIX_FILE_APPEND_PREFIX" = '' ] \
			|| [ "$POSTFIX_FILE_APPENDED" = '' ]; then
		echo "ERROR: file append prefixes must be defined"
		exit 1
	fi

	POSTFIX_FILE_APPEND_ALL="$POSTFIX_FILE_APPEND_PREFIX""all"
	POSTFIX_FILE_APPEND_HOST="$POSTFIX_FILE_APPEND_PREFIX$(cat /etc/hostname)"

	echo "====> applying append files..."
	# Get all files with either all or host extension, take off the extension,
	# and remove duplicates
	for orig_file in $(find -L . -type f -regextype sed -regex \
		".*\($POSTFIX_FILE_APPEND_HOST\|$POSTFIX_FILE_APPEND_ALL\)" \
		| sed "s/$POSTFIX_FILE_APPEND_PREFIX.*//" | uniq -u)
	do
		if ! [ -f $orig_file ]; then
			echo "WARNING: $orig does not exist but append files for it do"
			continue
		fi

		# Build the append to add
		append=""
		if [ -f "$orig_file$POSTFIX_FILE_APPEND_ALL" ]; then
			append="$append$(cat "$orig_file$POSTFIX_FILE_APPEND_ALL")"
		fi

		if [ -f "$orig_file$POSTFIX_FILE_APPEND_HOST" ]; then
			append="$append$(cat "$orig_file$POSTFIX_FILE_APPEND_HOST")"
		fi

		last_append="$orig_file$POSTFIX_FILE_APPENDED"

		if [ -f $last_append ]; then
			if diff <(echo "$append") $last_append > /dev/null; then
				echo "====> skipping $i"
				continue
			fi

			echo "====> found existing append for $orig_file, removing..."
			cp $orig_file "$orig_file.orig"

			# fuck it i would need a gnuism anyway to deal with newlines so may
			# as well use vim
			if ! which vim >/dev/null; then
				echo "ERROR: You need vim for this operation"
				exit 1
			fi

			vim -u NONE +"s/\n$(cat $last_append)\%$//" +wq $orig_file

			if diff "$orig_file" "$orig_file.orig" > /dev/null; then
				echo "ERROR: failed to remove append from file $orig_file"
				continue
			fi

		fi

		echo "$append" >> $orig_file
		echo "$append" >  $last_append
		echo "  ==> appended to $orig_file"
	done
fi

if $link_to_home; then
	echo "====> applying links..."
	# Install dotfiles to $HOME
	for i in $(find . -maxdepth 1 -regex '\.\/\..+'); do
		if echo "$i" | egrep -q \
				".git|$POSTFIX_FILE_APPENDED|$POSTFIX_FILE_APPEND_PREFIX"
		then
			continue
		fi
		fullpath=$(eval echo $(echo $i | sed 's|^\.|$(pwd)|'))
		homepath=$(eval echo $(echo $i | sed 's|.*/\(.*\)$|$HOME/\1|'))
		if [ -L "$homepath" ]; then
			rm "$homepath"
		fi
		if [ -f "$homepath" ]; then
			mv "$homepath" "$homepath.orig"
		fi
		ln -s "$fullpath" $HOME
		echo "  ==> linked $homepath -> $fullpath"
	done
	echo "====> applying .desktop file links..."
	for f in $(ls applications); do
		# -b makes backup
		ln -sb $(pwd)/applications/$f $HOME/.local/share/applications/$f
	done
fi

if $vim; then
	git submodule update --init --remote nvim
fi

if $firefox; then
	## Firefox
	if [ -d $HOME/.mozilla ]; then
		firefox_dir=$(find $HOME/.mozilla -type d \
				-regex ".*/firefox/.*\.default-release")
		if [ "$firefox_dir" = "" ]; then
			todo="$todo firefox "
			echo "Firefox must be run once before the config can be made, skipping..."
		elif ! [ "$(echo "$firefox_dir" | wc -l)" = "1" ]; then
			echo "Multiple firefox installs located, skipping..."
		else
			echo "Installing firefox theme..."
			if [ -d "$firefox_dir/chrome" ]; then
				cd "$firefox_dir/chrome"
				if git config --get remote.origin.url | grep -q "tim-clifford"; then
					git pull
					cd - >/dev/null
				else
					cd - >/dev/null
					rm -r "$firefox_dir/chrome"
					git clone https://github.com/tim-clifford/minimal-functional-fox-dracula
					mv minimal-functional-fox-dracula "$firefox_dir/chrome"
					todo="$todo firefox_postinstall "
				fi
			else
				git clone https://github.com/tim-clifford/minimal-functional-fox-dracula
				mv minimal-functional-fox-dracula "$firefox_dir/chrome"
				todo="$todo firefox_postinstall "
			fi
		fi
	else
		echo "Firefox must be run once before the config can be made, skipping..."
	fi
fi

## Less
lesskey lessrc

if $zsh; then
	while true; do
		read -p "Change shell to zsh? " yn
		case $yn in
			[Yy]* )
				chsh -s /usr/bin/zsh
				break;;
			[Nn]* ) break;;
			*)      echo "Please respond"; exit 1;
		esac
	done
fi

if $grub; then
	while true; do
		read -p "Install grub theme? " yn
		case $yn in
			[Yy]* )
				sudo sh -c '
				if [ -d /boot/grub/themes/tux-grub-theme ]; then
					echo "grub theme already installed"
				else
					cp -r tux-grub-theme /boot/grub/themes
					# check if a theme is defined
					if cat /etc/default/grub | egrep -q "^GRUB_THEME"; then
						sed -i '"'"'s|^GRUB_THEME|GRUB_THEME="/boot/grub/themes/tux-grub-theme/theme.txt"|'"'"'
					else
						echo '"'"'GRUB_THEME="/boot/grub/themes/tux-grub-theme/theme.txt"'"'"' \
							>> /etc/default/grub
					fi
					grub-mkconfig -o /boot/grub/grub.cfg
				fi
				'
				break;;
			[Nn]* ) break;;
			*)      echo "Please respond"; exit 1;
		esac
	done
fi

if $keyboard; then
	while true; do
		read -p "Install keyboard layout? " yn
		case $yn in
			[Yy]* )
				sudo cp ./colemak-custom/colemak-custom \
					     /usr/share/X11/xkb/symbols/
				sudo cp ./colemak-custom/colemak-custom.map.gz \
					     /usr/share/kbd/keymaps/i386/colemak/
				break;;
			[Nn]* ) break;;
			*)      echo "Please respond"; exit 1;
		esac
	done
fi

if ! $nonfree && ! $no_nonfree; then
	while true; do
		read -p "Get nonfree content? (you must have access) " yn
		case $yn in
			[Yy]* )
				$nonfree=true
				break;;
			[Nn]* )
				break;;
			*)
				echo "Please respond"; exit 1;
		esac
	done
fi

if ! $no_nonfree && $nonfree; then
	# Wallpapers
	git submodule update --init
	git submodule update --remote
	cd nonfree
	git lfs install
	git lfs fetch
	git lfs checkout
	cd ../wallpapers
	# I'm not sure I fully understand links tbh
	ln -sf ../nonfree/wallpapers/current.png current.png
	cd ..

	# Icons
	cd nonfree/icons
	mkdir -p ~/.local/share/icons
	ln -s $(pwd)/Linebit ~/.local/share/icons/Linebit
	cd ../..
else
	# Set up default wallpaper
	cd wallpapers
	ln -sf default_wallpaper.png current.png
	cd ..
fi

if ! $ignore_metaconfig; then
	echo "====> Commiting host-specific configuration..."
	git add .
	git commit -m "METACONF_APPLIED at $(date -u +"%Y-%m-%d %H:%M:%S")"
	if ! [ -f ".git/hooks/pre-push" ]; then
		ln -s "$(pwd)/pre-push" "$(pwd)/.git/hooks"
	fi

	# Reload i3 if we're doing this on the fly
	if pgrep i3 >/dev/null; then
		i3-msg restart
	fi
fi
if ! [ "$todo" = "" ]; then
	echo "\
	====> TODO LIST:"
fi
if echo $todo | grep -q "firefox_postinstall "; then
	echo "To finish Firefox configuration:
  - Type \`:installnative\` and follow the instructions,
    then type \`:source\` to enable tridactyl config
  - in \`about:config\`:
    * Clear \`extensions.webextensions.restrictedDomains\`
      to allow extensions on all pages
	* Enable \`toolkit.legacyUserProfileCustomizations.stylesheets\`
      to use the custom firefox theme.
	* Enable \`full-screen-api.ignore-widgets\`
	  to enable windowed fullscreen"
elif echo $todo | grep -q "firefox "; then
	echo "\
  - Firefox must be run before you can install the custom theme
	You can then use \`./install.sh --firefox-only\`"
fi
if $install; then
	echo "To enable gpg key unlocking with i3lock:
  - follow the instructions at https://github.com/cruegge/pam-gnupg"
fi
