#!/bin/bash
# Create a systemd override to auto-login root on ttyS0
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d

cat <<EOF >/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF

# Reload and restart the getty service
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart serial-getty@ttyS0.service


exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
# Network Performance
sysctl -w net.core.somaxconn=1024
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_max_syn_backlog=4096
sysctl -w net.ipv4.tcp_max_tw_buckets=2000000
sysctl -w net.ipv4.tcp_keepalive_time=60
sysctl -w net.ipv4.tcp_keepalive_intvl=10
sysctl -w net.ipv4.tcp_keepalive_probes=5
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sysctl -w net.ipv4.tcp_fastopen=3
sysctl -w net.ipv4.tcp_syn_retries=2
sysctl -w net.ipv4.tcp_retries2=5
sysctl -w net.ipv4.tcp_window_scaling=1
sysctl -w net.ipv4.tcp_sack=1
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0

# BBR Congestion Control
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr

# Swappiness and Cache Pressure
sysctl -w vm.swappiness=10
sysctl -w vm.vfs_cache_pressure=50

# File Descriptors
sysctl -w fs.file-max=1000000

# Network Buffers
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"


#####################################
# Script use for clone repo on gitea
#####################################

# yum install -y git awscli

# GITEA_USER=$(aws ssm get-parameter \
#   --region "${region}" \
#   --name "${ssm_gitea_username_path}" \
#   --with-decryption \
#   --query "Parameter.Value" \
#   --output text)

# GITEA_TOKEN=$(aws ssm get-parameter \
#   --region "${region}" \
#   --name "${ssm_gitea_token_path}" \
#   --with-decryption \
#   --query "Parameter.Value" \
#   --output text)

# if [ -z "$GITEA_USER" ] || [ -z "$GITEA_TOKEN" ]; then
#   echo "ERROR: Failed to retrieve Gitea credentials from SSM Parameter Store"
#   exit 1
# fi

# REPO_URL="${gitea_repo_url}"
# REPO_URL_WITH_CREDS=$(echo "$REPO_URL" | sed "s|://|://$GITEA_USER:$GITEA_TOKEN@|")
# git clone "$REPO_URL_WITH_CREDS" /opt/setup

# unset GITEA_USER GITEA_TOKEN REPO_URL_WITH_CREDS

# if [ -f /opt/setup/setup.sh ]; then
#   chmod +x /opt/setup/setup.sh
#   bash /opt/setup/setup.sh
# else
#   echo "ERROR: /opt/setup/setup.sh not found in cloned repo"
#   exit 1
# fi

#####################################################
# Standard script to install Docker and Code-server
######################################################
yum update -y && yum install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user

# Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
curl -fsSL "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
PASSWORD=$(openssl rand -base64 30)
export HOME=/home/ec2-user
mkdir -p /home/ec2-user/.config/code-server
if [ ! -d /home/ec2-user/.config/code-server ]; then
    echo "Failed to create directory /home/ec2-user/.config/code-server"
    exit 1
fi
chown ec2-user:ec2-user /home/ec2-user/.config/code-server
cat > /home/ec2-user/.config/code-server/config.yaml <<EOL
bind-addr: 0.0.0.0:8443
auth: password
password: $PASSWORD
cert: false
EOL
if [ ! -f /home/ec2-user/.config/code-server/config.yaml ]; then
    echo "Failed to create config.yaml"
    exit 1
fi
chown ec2-user:ec2-user /home/ec2-user/.config/code-server/config.yaml
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@ec2-user

%{ if workspace_ebs_name != "" ~}
###############################
# Self-attach & mount workspace EBS
###############################
IMDS_TOKEN=$(curl -sf -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" \
  http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl -sf \
  -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

echo "Looking for workspace EBS '${workspace_ebs_name}' (status=available)..."
VOLUME_ID=""
for i in $(seq 1 60); do
  VOLUME_ID=$(aws ec2 describe-volumes \
    --region "${region}" \
    --filters "Name=tag:Name,Values=${workspace_ebs_name}" \
              "Name=status,Values=available" \
    --query 'Volumes[0].VolumeId' \
    --output text 2>/dev/null)
  [ "$VOLUME_ID" != "None" ] && [ -n "$VOLUME_ID" ] && break
  echo "  attempt $i/60 — not available yet, waiting 10s..."
  sleep 10
done

if [ -z "$VOLUME_ID" ] || [ "$VOLUME_ID" = "None" ]; then
  echo "ERROR: workspace EBS not available after 10 minutes — skipping mount"
else
  aws ec2 attach-volume \
    --region "${region}" \
    --volume-id "$VOLUME_ID" \
    --instance-id "$INSTANCE_ID" \
    --device /dev/xvdf

  echo "Volume $VOLUME_ID attach requested, waiting for device to appear..."
  WORKSPACE_DEVICE=""
  for i in $(seq 1 150); do
    if [ -b "/dev/xvdf" ]; then
      WORKSPACE_DEVICE="/dev/xvdf"
      break
    fi
    # Nitro instances (t3/t3a/m5/etc.) expose EBS as NVMe; find the data disk
    NVME_DEV=$(lsblk -dnpo NAME,TYPE | awk '$2=="disk" && $1!="/dev/nvme0n1" {print $1; exit}')
    if [ -n "$NVME_DEV" ]; then
      WORKSPACE_DEVICE="$NVME_DEV"
      break
    fi
    sleep 2
  done

  if [ -b "$WORKSPACE_DEVICE" ]; then
    # Format only if no filesystem exists yet (preserves data on replacement)
    if ! blkid "$WORKSPACE_DEVICE" | grep -q TYPE; then
      mkfs.ext4 -F "$WORKSPACE_DEVICE"
    fi
    # Use UUID in fstab — stable across reboots regardless of NVMe index
    UUID=$(blkid "$WORKSPACE_DEVICE" -s UUID -o value)
    mkdir -p /workspace
    grep -q "$UUID" /etc/fstab || \
      echo "UUID=$UUID /workspace ext4 defaults,nofail 0 2" >> /etc/fstab
    mount /workspace
    chown ec2-user:ec2-user /workspace
    echo "Workspace EBS mounted at /workspace (device: $WORKSPACE_DEVICE, UUID: $UUID)"
  else
    echo "ERROR: device did not appear within timeout after attach"
  fi
fi
%{ endif ~}