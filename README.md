<div align="center">

<div align="center">
  <img height="200"src="Photo\blackbird.png"/>
</div>

<h1> Black Bird ..🐦‍⬛.. </h1>

<p>
  <strong>A smart, automated solution for securely syncing X-UI subscription configurations to a remote FTP/FTPS host.</strong>
</p>

<p>
  <a href="#-key-features">Key Features</a> •
  <a href="#-how-it-works">How It Works</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-management">Management</a> •
  <a href="#-security">Security</a> •
  <a href="#️-roadmap--future-plans">Roadmap</a>
</p>

</div>

---

**Black Bird** is a powerful automation tool designed for administrators who need to manage X-UI panel configurations and make them available to users securely and reliably. The script automates the entire process from fetching configs to uploading them to a web host, all managed through an interactive and user-friendly command-line interface.

It handles everything: dependency installation, credential encryption, subscription URL setup, user management, and automated execution via cron job.

## ✨ Key Features

This script is more than just a sync tool; it's a complete management suite.

#### ⚙️ Automation & Reliability
* **Automated Cron Job Management**: Automatically creates, updates, and removes the system cron job for periodic execution.
* **Intelligent Syncing**: A robust Python worker script runs reliably in the background to keep configs up-to-date.
* **HTTP Retry Logic**: For robust config fetching, the script automatically retries failed downloads from the X-UI panel.
* **Self-Healing Directory Creation**: Automatically creates the destination directory on the remote FTP host if it doesn't exist.
* **Atomic File Operations**: Uses temporary files for critical operations to prevent data corruption in case of interruptions.

#### 💻 Interactive Management
* **All-in-One Management Menu**: A single script (`BlackBird.sh`) provides a powerful menu for all operations.
* **Full User Lifecycle Management**: Interactively add, delete, enable, and disable users right from the terminal.
* **Bulk User Addition**: Add multiple users in one go by providing a simple comma-separated list.
* **Dynamic Scheduling**: Easily change the cron schedule with a list of predefined intervals or set a custom time.
* **Live Status Dashboard**: A detailed report on cron status, last run success, FTP uploads, and a countdown to the next scheduled run.
* **Manual Run Trigger**: Execute the sync process on-demand directly from the menu.

#### 🔒 Security First
* **End-to-End Encrypted Transport**: Utilizes **FTPS (FTP over TLS)** to encrypt both credentials and configuration data during transit to your web host.
* **Robust Credential Encryption**: Sensitive FTP settings are never stored in plain text. They are encrypted on-disk using industry-standard symmetric encryption algorithms.
* **Secure File Permissions**: The script automatically applies strict, root-only file permissions to sensitive credential files, isolating them from other processes on the server.

#### 💡 Smart Setup Wizard
* **Guided Installation**: An interactive wizard handles the entire setup process, from Python dependencies to subscription settings.
* **Automatic Dependency Checks**: Checks for necessary system tools like `python3`, `pip`, and `nc`, and offers to install them if they are missing.
* **Smart IP Detection**: Automatically detects the server's public IP address for easy setup or allows for a manual override with a custom domain.
* **Connection Validation**: Actively tests the connection to the X-UI panel before finalizing settings to prevent misconfigurations.

---

## ⚙️ How It Works

The system consists of two main components:

1.  **`Blackbird.sh` (The Management Script)**: This is the main entry point and your command center. You use this script to install, uninstall, manage users, change settings, and check the status of the whole system.
2.  **`helper.py` (The Worker Script)**: This is the Python script that runs in the background via the cron job. It performs the core logic:
    * Securely decrypts and loads the FTP and subscription settings.
    * Reads the list of active users.
    * Fetches the latest configuration for each user from the X-UI panel.
    * Uploads the configuration files securely to your FTP host.

This separation ensures that the core logic is robust and the management interface is powerful and user-friendly.

---

## 🚀 Installation

Getting started is simple. All you need are the script files and a server with `git` installed.

1.  **Clone the Repository**

    Clone this repository to a location of your choice on your server (e.g., `/root/source`).

    ```bash
    git clone https://github.com/SoroushImanian/BlackBird.git
    cd BlackBird
    ```

2.  **Make the Installer Executable**

    ```bash
    chmod +x Blackbird.sh
    ```

3.  **Run the Installer**

    The interactive wizard will launch and guide you through the rest of the setup. It will ask for your X-UI panel's subscription details and your FTP host credentials.

    ```bash
    ./Blackbird.sh
    ```

Once completed, the cron job will be set up, and the first sync will run immediately.

---

## 🔧 Management

All management tasks are handled through the installer's main menu. Simply run `./BlackBird.sh` at any time in the script's directory to access it. The menu allows you to perform all the powerful actions listed in the features section.

``

---

## 🛡️ Security

Security is a core feature of this project. Your sensitive information is protected through multiple layers:

* **Secure Transport**: The script uses FTPS (FTP over TLS) to ensure that your login credentials and configuration files are fully encrypted during transit to your web host.
* **On-Disk Encryption**: Credentials are never stored in plain text. They are encrypted using robust, industry-standard symmetric encryption before being saved to the disk.
* **Restricted Permissions**: The script automatically sets strict file permissions on all sensitive files, ensuring they are isolated and only accessible by the root user.
* **Open Source**: The code is fully open-source, so you can review the entire process and be confident that your data is handled securely and is not being sent anywhere else.

---

## 🗺️ Roadmap & Future Plans

We are constantly working to improve BlackBird. Here are some of the features planned for future releases:

- [ ] **Advanced Obfuscation**: Implement advanced obfuscation for configuration files on the host to enhance security against GFW and prevent host discovery.
- [ ] **VPS as a Destination**: Add the ability to use a Virtual Private Server (VPS) via SCP/SFTP as an alternative destination for storing configuration files, with full setup and management options.
- [ ] **Expanded Subscription Support**: Add support for advanced subscription types (e.g., JSON, with fragment & noise parameters) for greater compatibility.
- [ ] **Remote File Management**: Introduce a feature for real-time viewing and management of configuration files on the remote host directly from the script's menu.
- [ ] **Enhanced Uninstallation**: Add an optional feature to the uninstall process to remotely wipe all user configuration files from the FTP host upon confirmation.
- [ ] **High Availability Sync**: Support for multi-host and multi-VPS destinations, allowing the script to synchronize configurations to several providers simultaneously for improved uptime and resilience against network disruptions.
- [ ] ... and many more community-driven enhancements!

---

<div align="center">
  <font color="silver">
    Powered By SorBlack
    <br>
      SorBlack.com
  </font>
</div>
