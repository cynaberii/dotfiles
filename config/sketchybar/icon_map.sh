#!/bin/bash
__icon_map() {
  case "$1" in
  "WezTerm") icon_result="󰆍";;
  "Zen") icon_result="󰈹";;
  "Discord") icon_result="󰙯";;
  "Anki") icon_result="󰓎";;
  "Finder") icon_result="󰀶";;
  "Safari") icon_result="󰀹";;
  "Notes") icon_result="󰠮";;
  "Mail") icon_result="󰇮";;
  "System Settings") icon_result="󰒓";;
  *) icon_result="󰘔";;
  esac
}
