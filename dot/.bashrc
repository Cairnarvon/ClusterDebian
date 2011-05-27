[ -z "$PS1" ] && return

# bash-builtins(7)
shopt -s checkwinsize
shopt -s hostcomplete
shopt -u interactive_comments
shopt -s histappend
shopt -s histverify

# ↑ and ↓ behave more usefully with partial commands
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# lessopen(1)
[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

# Never needed this before, but it can't hurt
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Prettier prompt
if [ "`whoami`" == "root" ]; then
    PS_COL="\e[1;31m"   # red!
else
    PS_COL="\e[1;32m"   # green!
fi
PS1='[\[\e[2m\]$(date +%H:%M)\[\e[0m\]] \['$PS_COL'\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
PS2='\[\e[2m\]> \[\e[0m\]'

# Colours for ls and grep
if [ "$TERM" != "dumb" ]; then
    eval "`dircolors -b`"
    alias ls='ls --color=auto --group-directories-first -x'
    alias grep='grep --color'
else
    alias ls='ls --group-directories-first -x'
fi

# Environment variablies
export HISTCONTROL=ignoreboth
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/bin:~/bin
export EDITOR=vim
export GIT_EDITOR=vim
export GIT_PAGER=less

# Misc aliases
alias mv='mv -i'
alias cp='cp -i'
alias vi='vim'
alias sprunge="curl -F 'sprunge=<-' http://sprunge.us"

# bash-builtins(7)
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
