#!/bin/bash

# This script checks for the necessary setup to connect to a Cisco SG 300 switch using an FTDI USB to serial cable.
# It prompts the user before attempting to resolve any issues, including checking for and installing Homebrew if necessary.

# Define the vendor ID for FTDI devices and the name of the FTDI kernel extension
FTDI_VENDOR_ID="0403"
KEXT_NAME="FTDIUSBSerialDriver.kext"

echo "Checking for FTDI USB to Serial Cable..."

# Check for connected FTDI devices
ftdi_device=$(ioreg -p IOUSB -l -w 0 | grep -i FTDI | grep "$FTDI_VENDOR_ID")

if [ -z "$ftdi_device" ]; then
    echo "No FTDI USB to Serial cable detected. Please connect your FTDI device."
    exit 1
else
    echo "FTDI USB to Serial cable detected."
fi

# Function to ask for user confirmation
confirm() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Check for Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed."
    if confirm "Do you want to install Homebrew?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew installation declined. Unable to install required drivers without Homebrew."
        exit 1
    fi
fi

# Check if the FTDI driver is loaded
ftdi_driver=$(kextstat | grep FTDIUSBSerialDriver)

if [ -z "$ftdi_driver" ]; then
    echo "FTDI driver is not loaded."
    if confirm "Do you want to check for and load the driver?"; then
        # Check if the driver is installed but not loaded
        if [ -e "/Library/Extensions/$KEXT_NAME" ]; then
            echo "Driver found. Attempting to load..."
            sudo kextload /Library/Extensions/$KEXT_NAME
        else
            if confirm "Driver not found. Do you want to install the driver?"; then
                # Install FTDI driver using Homebrew
                brew install --cask ftdi-vcp-driver
                sudo kextload /Library/Extensions/$KEXT_NAME
            fi
        fi
    fi
fi

# Check again if driver is loaded
ftdi_driver=$(kextstat | grep FTDIUSBSerialDriver)
if [ ! -z "$ftdi_driver" ]; then
    echo "FTDI driver is successfully loaded."
else
    echo "Driver loading failed or was skipped. Please ensure the driver is properly installed and loaded."
    exit 1
fi

# Find the device name assigned to the USB serial port
device_path=$(ls /dev | grep -i tty.usbserial)

if [ -z "$device_path" ]; then
    echo "No serial device found. Please check your connections and drivers."
    exit 1
else
    device_path="/dev/$device_path"
    echo "Serial device found at $device_path"
fi

# Ensure user has proper permissions to access the serial device
if [ ! -w "$device_path" ]; then
    if confirm "Current user does not have write access to $device_path. Do you want to change permissions?"; then
        sudo chmod 666 $device_path
    fi
fi

# Connect to the Cisco SG 300 switch using screen
echo "Connecting to the Cisco SG 300 switch..."
screen $device_path 9600

# Note: The baud rate is set to 9600, which is typical for Cisco devices. Adjust as necessary.
