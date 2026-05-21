#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Wallust: derive colors from the current wallpaper and update templates
# Usage: WallustSwww.sh [absolute_path_to_wallpaper]

set -euo pipefail

# Inputs and paths
passed_path="${1:-}"
cache_dir="$HOME/.cache/awww/"
rofi_link="$HOME/.config/rofi/.current_wallpaper"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# Helper: get focused monitor name (prefer JSON)
get_focused_monitor() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
  else
    hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}'
  fi
}

# Determine wallpaper_path
wallpaper_path=""
if [[ -n "$passed_path" && -f "$passed_path" ]]; then
  wallpaper_path="$passed_path"
else
  # Try to read from awww cache for the focused monitor, with a short retry loop
  current_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
  cache_file="$cache_dir$current_monitor"

  # Wait briefly for awww to write its cache after an image change
  for i in {1..10}; do
    if [[ -f "$cache_file" ]]; then
      break
    fi
    sleep 0.1
  done

  if [[ -f "$cache_file" ]]; then
    wallpaper_path=$(awww query | grep "$current_monitor" | awk -F 'image: ' '{print $2}')
  fi
fi

if [[ -z "${wallpaper_path:-}" || ! -f "$wallpaper_path" ]]; then
  # Nothing to do; avoid failing loudly so callers can continue
  exit 0
fi

# Track the old global wallpaper path before we update it
old_path_file="$(dirname "$wallpaper_current")/.wallpaper_path_current"
old_global_path=""
if [[ -f "$old_path_file" ]]; then
  old_global_path=$(cat "$old_path_file")
fi

# Update helpers that depend on the path
ln -sf "$wallpaper_path" "$rofi_link" || true
mkdir -p "$(dirname "$wallpaper_current")"
cp -f "$wallpaper_path" "$wallpaper_current" || true
echo "$wallpaper_path" > "$old_path_file"

# Save per-monitor wallpaper path for persistence
# If a second argument is passed, use it as the monitor name
if [[ -n "${2:-}" ]]; then
  target_monitor="$2"
else
  target_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
fi

# Save the wallpaper for the target monitor
echo "$wallpaper_path" > "$(dirname "$wallpaper_current")/.wallpaper_$target_monitor"

# Optional: Ensure other monitors have their current wallpaper saved 
# if they don't already have a per-monitor file.
# This prevents them from falling back to the newly updated .wallpaper_current on next boot.
monitors=$(hyprctl monitors -j | jq -r '.[] | .name')
for mon in $monitors; do
  mon_file="$(dirname "$wallpaper_current")/.wallpaper_$mon"
  if [[ ! -f "$mon_file" ]]; then
    # Get current wallpaper for this monitor from awww query
    mon_wallpaper=$(awww query | grep "$mon" | awk -F 'image: ' '{print $2}')
    
    # If the monitor is using the fallback (.wallpaper_current), 
    # we should use the old global path to "freeze" it.
    if [[ "$mon_wallpaper" == "$wallpaper_current" ]]; then
       if [[ -n "$old_global_path" && -f "$old_global_path" ]]; then
          mon_wallpaper="$old_global_path"
       fi
    fi

    if [[ -n "$mon_wallpaper" && -f "$mon_wallpaper" && "$mon_wallpaper" != "$wallpaper_current" ]]; then
      echo "$mon_wallpaper" > "$mon_file"
    fi
  fi
done

# Run wallust (silent) to regenerate templates defined in ~/.config/wallust/wallust.toml
# -s is used in this repo to keep things quiet and avoid extra prompts
wallust run -s "$wallpaper_path" || true
