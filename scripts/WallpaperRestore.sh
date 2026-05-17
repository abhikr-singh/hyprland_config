#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# Script to restore wallpapers for each monitor on startup

wallpaper_dir="$HOME/.config/hypr/wallpaper_effects"
default_wallpaper="$wallpaper_dir/.wallpaper_current"

# Ensure awww-daemon is running
if ! pgrep -x "awww-daemon" >/dev/null; then
  awww-daemon --format xrgb &
  sleep 1
fi

# Get all connected monitors
monitors=$(hyprctl monitors -j | jq -r '.[] | .name')

for mon in $monitors; do
  mon_wallpaper="$wallpaper_dir/.wallpaper_$mon"
  
  if [[ -f "$mon_wallpaper" ]]; then
    wallpaper_path=$(cat "$mon_wallpaper")
    if [[ -f "$wallpaper_path" ]]; then
      awww img -o "$mon" "$wallpaper_path" --transition-type none
    else
      awww img -o "$mon" "$default_wallpaper" --transition-type none
    fi
  else
    awww img -o "$mon" "$default_wallpaper" --transition-type none
  fi
done
