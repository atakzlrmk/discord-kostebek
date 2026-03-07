#!/bin/bash
# Bulunduğu klasöre otomatik geç (Finder üzerinden çift tıklandığında doğru çalışması için)
cd "$(dirname "$0")"

clear
echo "=========================================================="
echo "             👾 Discord Kostebek Dashboard 👾"
echo "=========================================================="
echo "Starting server, please wait..."

# Find an available port starting from 1337
PORT=1337
while lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; do
    PORT=$((PORT+1))
done

# Start Python server background
python3 server.py $PORT &
SERVER_PID=$!

sleep 1

# Open default browser
open "http://localhost:$PORT"

echo ""
echo "[SUCCESS] Dashboard opened in your browser!"
echo "If it didn't open automatically, go to: http://localhost:$PORT"
echo ""
echo "[!] WARNING: If you close this window, the UI WILL CLOSE."
echo "However, SpoofDPI running in the background (if active) will continue working."
echo "To exit this interface, you can close this window."

# Wait for server process to keep terminal open
wait $SERVER_PID
