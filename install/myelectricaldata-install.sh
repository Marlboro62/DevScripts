#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Marlboro62
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/MyElectricalData/myelectricaldata_new

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y nginx
msg_ok "Installed Dependencies"

PG_VERSION="16" setup_postgresql
PG_DB_NAME="myelectricaldata_client" PG_DB_USER="myelectricaldata" setup_postgresql_db
PYTHON_VERSION="3.12" setup_uv
NODE_VERSION="24" setup_nodejs

fetch_and_deploy_gh_release "myelectricaldata" "MyElectricalData/myelectricaldata_new" "tarball"

msg_info "Configuring MyElectricalData Backend"
cat <<EOF >/opt/myelectricaldata/.env
MED_CLIENT_ID=${var_med_client_id}
MED_CLIENT_SECRET=${var_med_client_secret}
MED_API_URL=https://www.v2.myelectricaldata.fr/api
DATABASE_URL=postgresql+asyncpg://${PG_DB_USER}:${PG_DB_PASS}@127.0.0.1:5432/${PG_DB_NAME}
VICTORIAMETRICS_URL=
SECRET_KEY=$(random_password 43)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=43200
ALLOWED_HOSTS=
TZ=Europe/Paris
DEBUG=false
API_HOST=127.0.0.1
API_PORT=8000
PYTHONUNBUFFERED=1
EOF
chmod 600 /opt/myelectricaldata/.env
cd /opt/myelectricaldata/apps/api
$STD uv sync --locked --no-dev --no-install-project
msg_ok "Configured MyElectricalData Backend"

msg_info "Building MyElectricalData Frontend"
cd /opt/myelectricaldata/apps/web
$STD npm ci
$STD npm run build
msg_ok "Built MyElectricalData Frontend"

msg_info "Configuring Nginx"
cat <<'EOF' >/etc/nginx/sites-available/myelectricaldata
server {
    listen 8100;
    server_name _;

    root /opt/myelectricaldata/apps/web/dist;
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_read_timeout 300s;
    }

    location = /index.html {
        add_header Cache-Control "no-cache";
    }
    location = /env.js {
        add_header Cache-Control "no-cache";
    }

    location /assets/ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
nginx_enable_site "myelectricaldata"
msg_ok "Configured Nginx"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/myelectricaldata.service
[Unit]
Description=MyElectricalData Backend
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/myelectricaldata/apps/api
EnvironmentFile=/opt/myelectricaldata/.env
ExecStartPre=/opt/myelectricaldata/apps/api/.venv/bin/alembic upgrade head
ExecStart=/opt/myelectricaldata/apps/api/.venv/bin/uvicorn src.main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now myelectricaldata
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
