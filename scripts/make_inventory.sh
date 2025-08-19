#!/usr/bin/env bash
set -euo pipefail
IP="$(terraform -chdir=terraform output -raw instance_public_ip)"
cat > inventory.ini <<EOF
[ec2]
${IP} ansible_user=ubuntu ansible_ssh_private_key_file=${EC2_SSH_KEY}
EOF
echo "Inventory for ${IP} written to inventory.ini"
