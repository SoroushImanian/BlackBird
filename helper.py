"""
SorBlack FTP/X-UI Backup Script Installer (v2.1.0)

This script automatically fetches user configuration files from a list of URLs,
saves them locally, and uploads them to a secure FTP (FTPS) server.
It is designed to be run periodically via a cron job and is managed by the
accompanying 'Blackbird.sh' script.
"""
import os
import shutil
import requests
import datetime
import io
from cryptography.fernet import Fernet
from ftplib import FTP_TLS
from concurrent.futures import ThreadPoolExecutor
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

CRED_DIR = os.path.join(SCRIPT_DIR, ".credentials")
LINKS_FILE_PATH = os.path.join(SCRIPT_DIR, "users.txt")
KEY_FILE_PATH = os.path.join(CRED_DIR, "secret.key")
ENCRYPTED_ENV_FILE_PATH = os.path.join(CRED_DIR, ".env.encrypted")
LOCAL_FOLDER = os.path.join(SCRIPT_DIR, "configs/")


def load_encrypted_env():
    try:
        with open(KEY_FILE_PATH, "rb") as key_file:
            key = key_file.read()
        
        f = Fernet(key)

        with open(ENCRYPTED_ENV_FILE_PATH, "rb") as file:
            encrypted_data = file.read()
        
        decrypted_data = f.decrypt(encrypted_data)
        
        env_file = io.StringIO(decrypted_data.decode('utf-8'))
        for line in env_file:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key.strip()] = value.strip()
        
        return True

    except FileNotFoundError:
        print(f"Error: Could not find credential files in '{CRED_DIR}'.")
        print("Please run Blackbird.sh (Option 1) to set up credentials.")
        return False
    except Exception as e:
        print(f"Failed to load encrypted .env file: {e}")
        return False


if not load_encrypted_env():
    exit(1)

FTP_HOST = os.getenv('FTP_HOST')
FTP_USER = os.getenv('FTP_USER')
FTP_PASS = os.getenv('FTP_PASS')
FTP_PORT = os.getenv('FTP_PORT', 21)
FTP_REMOTE_FOLDER = "/public_html/docs/"

retry_strategy = Retry(
    total=3,
    status_forcelist=[429, 500, 502, 503, 504],
    allowed_methods=["HEAD", "GET", "OPTIONS"],
    backoff_factor=1
)
adapter = HTTPAdapter(max_retries=retry_strategy)
http = requests.Session()
http.mount("https://", adapter)
http.mount("http://", adapter)


def get_config(link):
    try:
        response = http.get(link, timeout=10)
        response.raise_for_status()
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Failed to retrieve config from {link}: {e}")
        return None


def save_config(config, user):
    try:
        if not os.path.exists(LOCAL_FOLDER):
            os.makedirs(LOCAL_FOLDER)
        file_path = os.path.join(LOCAL_FOLDER, f"{user}")
        with open(file_path, "w", encoding='utf-8') as f:
            f.write(config)
        return file_path
    except Exception as e:
        print(f"Failed to save config for {user}: {e}")
        return None


def upload_to_ftp():
    print("\nAttempting to upload files to FTP...")
    try:
        ftps = FTP_TLS(timeout=10)
        ftps.connect(FTP_HOST, int(FTP_PORT))
        ftps.login(FTP_USER, FTP_PASS)
        ftps.prot_p()
        
        path_parts = FTP_REMOTE_FOLDER.strip('/').split('/')
        for part in path_parts:
            if part not in ftps.nlst():
                ftps.mkd(part)
            ftps.cwd(part)

        for file_name in os.listdir(LOCAL_FOLDER):
            local_path = os.path.join(LOCAL_FOLDER, file_name)
            with open(local_path, 'rb') as f:
                ftps.storbinary(f'STOR {file_name}', f)

        ftps.quit()
        print("All files uploaded successfully.")
    except Exception as e:
        print(f"Failed to upload files to FTP: {e}")


def process_link(link):
    link = link.strip()
    if not link:
        return

    username = link.split('/')[-1]
    
    print(f"Processing user: {username} | from link: {link}")
    config = get_config(link)
    if config:
        save_config(config, username)


def main():
    try:
        print("--- Starting Script ---")
        
        print("")
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d - %H:%M:%S")
        print(f"Script started at: {timestamp}")
        print("-------------------------")

        if not os.path.exists(LINKS_FILE_PATH):
            raise FileNotFoundError(f"Error: The links file was not found at {LINKS_FILE_PATH}")

        with open(LINKS_FILE_PATH, "r", encoding='utf-8') as file:
            links = [line.strip() for line in file if line.strip()]

        if not links:
            print("Warning: users.txt is empty. Nothing to process.")
            return

        with ThreadPoolExecutor(max_workers=5) as executor:
            executor.map(process_link, links)

        if os.path.exists(LOCAL_FOLDER) and os.listdir(LOCAL_FOLDER):
            upload_to_ftp()
        else:
            print("\nNo configs were generated. Skipping FTP upload.")

    except Exception as e:
        print(f"\nAn error occurred in the main process: {e}")
    finally:
        if os.path.exists(LOCAL_FOLDER):
            print(f"\nCleaning up temporary folder: {LOCAL_FOLDER}")
            shutil.rmtree(LOCAL_FOLDER)
        print("--- Script Finished ---")


if __name__ == "__main__":
    main()
