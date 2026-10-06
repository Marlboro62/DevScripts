#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Marlboro62
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/MyElectricalData/myelectricaldata_new

APP="MyElectricalData"
var_tags="${var_tags:-energy;linky;home-automation}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/myelectricaldata ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "myelectricaldata" "MyElectricalData/myelectricaldata_new"; then
    msg_info "Stopping MyElectricalData"
    systemctl stop myelectricaldata
    msg_ok "Stopped MyElectricalData"

    create_backup /opt/myelectricaldata/.env

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "myelectricaldata" "MyElectricalData/myelectricaldata_new" "tarball"

    restore_backup

    msg_info "Updating MyElectricalData Backend"
    cd /opt/myelectricaldata/apps/api
    $STD uv sync --locked --no-editable --no-install-project
    msg_ok "Updated MyElectricalData Backend"

    msg_info "Building MyElectricalData Frontend"
    cd /opt/myelectricaldata/apps/web
    export VITE_API_BASE_URL=/api
    $STD npm ci
    $STD npm run build
    msg_ok "Built MyElectricalData Frontend"

    msg_info "Starting MyElectricalData"
    systemctl start myelectricaldata
    systemctl reload nginx
    msg_ok "Started MyElectricalData"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Set MED_CLIENT_ID and MED_CLIENT_SECRET in /opt/myelectricaldata/.env, then run: systemctl restart myelectricaldata${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}:8100${CL}"
