In the repository I will put some scripts that a network engineer may find handy during field work.


# xerox_enable_dhcp.zsh: Xerox WorkCentre DHCP Activation Script

This script automates the process of enabling DHCP on a Xerox WorkCentre printer using Firefox browser.

## Prerequisites

- macOS operating system
- Firefox web browser
- zsh shell

## Usage

1. Clone or download the repository to your local machine.

2. Open a terminal and navigate to the directory containing the script.

3. Make the script executable by running the following command:
    ```bash
    chmod +x xerox_dhcp_activation.zsh
    ```

4. Run the script with the following command, providing the printer's IP address, username, and password as arguments:
    ```bash
    ./xerox_dhcp_activation.zsh <printer_ip_address> <username> <password>
    ```

    Replace `<printer_ip_address>`, `<username>`, and `<password>` with the actual IP address of your Xerox WorkCentre printer, the username required to log in to the printer's web interface, and the corresponding password.

5. The script will open Firefox, navigate to the printer's web interface, log in with the provided credentials, enable DHCP, and restart the printer if DHCP activation is successful.

## Notes

- Adjust the delay values in the script as needed to ensure proper execution, especially for page loading and action completion.

- Ensure that the provided username and password are correct and have administrative privileges to access and modify the printer settings.

- This script assumes that the printer's web interface follows a standard structure. If your printer's interface is different, you may need to modify the script accordingly.

- Use this script responsibly and only on devices that you are authorized to access and modify.

