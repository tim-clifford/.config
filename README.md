# Tim Clifford's personal config files

### Warning!

I use my own keyboard layout (based on colemak) so there are many mappings in
here which don't make sense for most people.

### Organisation

Everything is tracked in this repo (which should exist at `$HOME/.config`), and
anything starting with a . is symlinked into `$HOME` by `install.sh`

See also my [vim](https://github.com/tim-clifford/vimrc) and
[firefox](https://github.com/tim-clifford/minimal-functional-firefox-dracula)
configs, which can be installed with `install.sh`. Anything automatically put
in my `$HOME/.config` by packages which I haven't configured will be in the
gitignore.

The user will be prompted to install packages from `pkglist.conf`, separated
by the comment header.

### Metaconfiguration

The system of metaconfiguration employed here allows for different but linked
configurations between machines. This is configured both by a configuration
file at `metaconfig/hostname.metaconf` (which defines global identifiers to
replace), and any file ending with `.METACONF_FILE_APPEND_hostname`, which will
be appended to the base file for that specific machine.

### Usage

```
Usage: ./install.sh [OPTION]...
Install or update configurations

When the installation is finished, a new commit will be made to distinguish
between the application of metaconfigurations and any further changes.

  --help                display this help and exit
  --no-install          don't install any packages
  --no-link             don't symlink dotfiles into $HOME
  --no-firefox          don't install firefox theme
  --no-vimrc            don't install vimrc
  --minimal-vimrc       install minimal vim (no plugins)
  --no-fish             don't set fish as the default config (default is to ask)
  --wallpapers          install nonfree wallpapers (default is to ask)
  --update              update configurations without installing or symlinking
                        anything. Can also be used without reverting to before
                        the last use.
```
```
Usage: ./gith.sh [OPTION]
Execute common git workflows for this repository

  --help                display this help and exit
  --push                push the last commit before the metaconf was applied
  --pull                pull the latest config, automatically handling metaconf
  --reset               revert to before the metaconf, keeping any changes
```
