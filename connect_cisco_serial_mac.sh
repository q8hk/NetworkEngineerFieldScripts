#!/bin/bash

# This script checks for the necessary setup to connect to a Cisco SG 300 switch using an FTDI USB to serial cable.
# It tries to resolve issues automatically, such as installing missing drivers.

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

# Check if the FTDI driver is loaded
ftdi_driver=$(kextstat | grep FTDIUSBSerialDriver)

if [ -z "$ftdi_driver" ]; then
    echo "FTDI driver is not loaded. Checking for installed driver..."

    # Check if the driver is installed but not loaded
    if [ -e "/Library/Extensions/$KEXT_NAME" ]; then
        echo "Driver found. Attempting to load..."
        sudo kextload /Library/Extensions/$KEXT_NAME
    else
        echo "Driver not found. Attempting to install..."
        # Install FTDI driver using Homebrew
        brew install --cask ftdi-vcp-driver
        sudo kextload /Library/Extensions/$KEXT_NAME
    fi

    # Check again if driver is loaded
    ftdi_driver=$(kextstat | grep FTDIUSBSerialDriver)
    if [ -z "$ftdi_driver" ]; then
        echo "Failed to load FTDI driver after installation. Please check manually."
        exit 1
    fi
fi

echo "FTDI driver is successfully loaded."

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
    echo "Current user does not have write access to $device_path. Attempting to fix..."
    sudo chmod 666 $device_path
fi

# Connect to the Cisco SG 300 switch using screen
echo "Connecting to the Cisco SG 300 switch..."
screen $device_path 9600

# Note: The baud rate is set to 9600, which is typical for Cisco devices. Adjust as necessary.
