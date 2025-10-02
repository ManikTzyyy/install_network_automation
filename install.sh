#!/bin/bash

# ========= CONFIG =========
PROJECT_NAME="network_automation"
PROJECT_DIR="/opt/$PROJECT_NAME"
GITHUB_REPO="https://github.com/ManikTzyyy/plumnet"
PYTHON_VERSION="python3"
SERVICE_USER="www-data"

# ========= STEP 1: INSTALL DEPENDENCIES =========
echo "[*] Install Python, pip, venv, dan dependencies sistem..."
sudo apt update
sudo apt install -y $PYTHON_VERSION $PYTHON_VERSION-venv $PYTHON_VERSION-pip git \
    nginx curl

# ========= STEP 2: CLONE PROJECT =========
echo "[*] Clone project dari GitHub..."
sudo rm -rf $PROJECT_DIR
sudo git clone $GITHUB_REPO $PROJECT_DIR
cd $PROJECT_DIR

# ========= STEP 3: VIRTUALENV =========
echo "[*] Buat virtual environment..."
$PYTHON_VERSION -m venv venv
source venv/bin/activate

# ========= STEP 4: INSTALL REQUIREMENTS =========
echo "[*] Install dependencies Python..."
pip install --upgrade pip
pip install -r requirements.txt

# ========= STEP 5: SETUP .env =========
echo "[*] Setup file .env..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ">>> Jangan lupa update isi file .env sesuai kebutuhan!"
fi

# ========= STEP 6: DJANGO MIGRATIONS =========
echo "[*] Jalankan migration Django..."
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput

# ========= STEP 7: GUNICORN SERVICE =========
echo "[*] Setup Gunicorn systemd service..."
sudo tee /etc/systemd/system/$PROJECT_NAME.service > /dev/null <<EOL
[Unit]
Description=Gunicorn service for $PROJECT_NAME
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --workers 3 --bind unix:$PROJECT_DIR/$PROJECT_NAME.sock $PROJECT_NAME.wsgi:application

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable $PROJECT_NAME
sudo systemctl restart $PROJECT_NAME


# ========= STEP 8: SCHEDULER SERVICE =========
echo "[*] Setup Django Scheduler systemd service..."
sudo tee /etc/systemd/system/$PROJECT_NAME-scheduler.service > /dev/null <<EOL
[Unit]
Description=Django Scheduler for $PROJECT_NAME
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python manage.py run_scheduler
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl enable $PROJECT_NAME-scheduler
sudo systemctl restart $PROJECT_NAME-scheduler

# ========= STEP 9: BOT TELEGRAM SERVICE (opsional) =========
echo "[*] Setup Telegram Bot systemd service..."
sudo tee /etc/systemd/system/$PROJECT_NAME-bot.service > /dev/null <<EOL
[Unit]
Description=Telegram Bot for $PROJECT_NAME
After=network.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python bot.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl disable $PROJECT_NAME-bot
sudo systemctl restart $PROJECT_NAME-bot
echo ">>> Bot service dibuat, aktifkan manual pakai: sudo systemctl enable $PROJECT_NAME-bot && sudo systemctl start $PROJECT_NAME-bot"



echo "[*] Instalasi selesai!"
