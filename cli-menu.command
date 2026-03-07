#!/bin/bash
cd "$(dirname "$0")"

while true; do
    clear
    echo "=========================================================="
    echo "             👾 Discord Kostebek CLI Menu 👾"
    echo "=========================================================="
    echo "1) ⚡ Run temporarily in this window"
    echo "2) 🔄 Install as background service"
    echo "3) ⏸️  Pause background service"
    echo "4) ▶️  Resume background service"
    echo "5) 🗑️  Uninstall completely"
    echo "6) 🚪 Exit"
    echo "=========================================================="
    read -p "Choice (1-6): " choice

    case $choice in
        1)
            echo ""
            sudo ./run-temp.sh
            read -p "Press ENTER to return..."
            ;;
        2)
            echo ""
            sudo ./manage-service.sh install
            read -p "Press ENTER to return..."
            ;;
        3)
            echo ""
            sudo ./manage-service.sh pause
            read -p "Press ENTER to return..."
            ;;
        4)
            echo ""
            sudo ./manage-service.sh resume
            read -p "Press ENTER to return..."
            ;;
        5)
            echo ""
            sudo ./manage-service.sh uninstall
            read -p "Press ENTER to return..."
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            sleep 1
            ;;
    esac
done
