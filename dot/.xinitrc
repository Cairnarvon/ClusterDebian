#!/bin/sh

xrdb -merge $HOME/.Xresources
feh --bg-fill $HOME/.wallpape.png &
exec WM
