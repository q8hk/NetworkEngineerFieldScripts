import os
import subprocess

def check_ftdi_device(vendor_id):
    """Check for connected FTDI devices using the given vendor ID."""
    try:
        result = subprocess.run(['ioreg', '-p', 'IOUSB', '-l', '-w', '0'],
                                capture_output=True, text=True)
        return vendor_id in result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Failed to run ioreg command: {e}")
        return False

def check_device_permissions(device_path):
    """Check if the current user has write permissions to the specified device path."""
    try:
        if not os.path.exists(device_path):
            return f"Error: The device path '{device_path}' does not exist."
        if os.access(device_path, os.W_OK):
            return f"Permission Check: Current user has write access to {device_path}."
        else:
            return f"Permission Check: Current user does NOT have write access to {device_path}."
    except Exception as e:
        return f"An error occurred: {str(e)}"

def adjust_permissions(device_path):
    """Adjust permissions on the device path to be writable by everyone, using sudo."""
    try:
        result = subprocess.run(['sudo', 'chmod', '666', device_path], capture_output=True, text=True)
        if result.returncode == 0:
            return f"Permissions adjusted to 666 for {device_path}."
        else:
            return f"Failed to adjust permissions: {result.stderr}"
    except Exception as e:
        return f"Exception occurred: {str(e)}"

def main():
    FTDI_VENDOR_ID = "0403"  # Example FTDI Vendor ID, replace with the actual one
    device_path = "/dev/tty.usbserial"  # Replace with your actual device path
    
    # Check for FTDI device
    if check_ftdi_device(FTDI_VENDOR_ID):
        print("FTDI device detected.")
        permission_result = check_device_permissions(device_path)
        print(permission_result)
        
        # If no write access, prompt for permission adjustment
        if "does NOT have write access" in permission_result:
            if input("Do you want to adjust device permissions to 666? [y/n]: ").lower() == 'y':
                print(adjust_permissions(device_path))
            else:
                print("Permission adjustment declined.")
    else:
        print("No FTDI device detected. Please check your connection.")

if __name__ == "__main__":
    main()
