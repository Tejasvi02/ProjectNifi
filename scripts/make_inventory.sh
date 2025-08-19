# scripts/make_inventory.sh
#!/usr/bin/env bash
set -euo pipefail
IP="$(terraform -chdir=terraform output -raw instance_public_ip)"
cat > inventory.ini <<EOF
[ec2]
${IP} ansible_user=ubuntu
EOF
echo "Inventory for ${IP} written to inventory.ini"
