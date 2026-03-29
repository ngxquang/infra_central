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

yum update -y && yum install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user
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