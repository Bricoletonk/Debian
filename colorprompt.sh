if [[ "$UID" -eq "0" ]]
then
    PS1="\[\e[01;37m\][\[\e[01;31m\]\u@\h\[\e[01;37m\]] \w \$\[\e[00m\] "
else
    PS1="\[\e[01;37m\][\[\e[01;32m\]\u@\h\[\e[01;37m\]] \w \$\[\e[00m\] "
fi
#à placer dans /etc/profile.d/colorprompt.sh
