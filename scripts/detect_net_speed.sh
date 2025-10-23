#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SPEED=1000

is_terminal() {
  [ -t 1 ]
}

trim() {
  local input="$1"
  input="${input%%*( )}"
  input="${input##*( )}"
  printf '%s' "$input"
}

numeric_mbps() {
  local value="$1"
  [[ -z "$value" ]] && return 1
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)Mb/s$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+(\.[0-9]+)?)Gb/s$ ]]; then
    local gv="${BASH_REMATCH[1]}"
    awk -v g="$gv" 'BEGIN { printf "%d\n", int(g * 1000 + 0.5) }'
    return 0
  fi
  if [[ "$value" =~ ^([0-9]+)base ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

detect_default_iface_linux() {
  local iface
  iface=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1)
  if [[ -z "$iface" ]]; then
    iface=$(ls /sys/class/net 2>/dev/null | grep -Ev '^(lo|docker|br-|veth|tun|tap)' | head -n1)
  fi
  printf '%s' "$iface"
}

detect_default_iface_darwin() {
  local iface
  iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}' | head -n1)
  if [[ -z "$iface" ]]; then
    iface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Device:/{print $2}' | head -n1)
  fi
  printf '%s' "$iface"
}

speed_from_iface_linux() {
  local iface="$1"
  local speed=""
  if command -v ethtool >/dev/null 2>&1; then
    speed=$(ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed:/{print $2}')
    speed=$(trim "$speed")
  fi
  if ! numeric_mbps "$speed" >/dev/null 2>&1; then
    if [[ -r "/sys/class/net/$iface/speed" ]]; then
      speed=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || true)
      speed=$(trim "$speed")
    fi
  fi
  numeric_mbps "$speed" 2>/dev/null || printf '%s\n' ""
}

speed_from_iface_darwin() {
  local iface="$1"
  local media
  media=$(ifconfig "$iface" 2>/dev/null | awk -F' ' '/media:/{print $2}' | head -n1)
  media=$(trim "$media")
  numeric_mbps "$media" 2>/dev/null || printf '%s\n' ""
}

main() {
  local iface="${NET_SPEED_IFACE:-}"
  local os
  os=$(uname -s)

  if [[ -z "$iface" ]]; then
    if [[ "$os" == "Linux" ]]; then
      iface=$(detect_default_iface_linux)
    elif [[ "$os" == "Darwin" ]]; then
      iface=$(detect_default_iface_darwin)
    fi
  fi

  if [[ -z "$iface" ]]; then
    printf '%d\n' "$DEFAULT_SPEED"
    exit 0
  fi

  local speed=""
  if [[ "$os" == "Linux" ]]; then
    speed=$(speed_from_iface_linux "$iface")
  elif [[ "$os" == "Darwin" ]]; then
    speed=$(speed_from_iface_darwin "$iface")
  fi

  if [[ -z "$speed" ]]; then
    case "$iface" in
      wl*|wlan*|wifi*|en[0-9]*)
        printf '%d\n' "$DEFAULT_SPEED"
        ;;
      *)
        printf '%d\n' "$DEFAULT_SPEED"
        ;;
    esac
  else
    printf '%s\n' "$speed"
  fi
}

main "$@"
