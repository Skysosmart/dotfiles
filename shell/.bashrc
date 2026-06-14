#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# Prevent Vencord 'write EIO' crash: keep Discord's console off a closeable TTY
alias discord='/usr/bin/discord >/dev/null 2>&1 & disown'

# Show system info banner on terminal open
fastfetch
