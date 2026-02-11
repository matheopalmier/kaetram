#!/bin/bash

# Load secrets
if [ -f ./deploy/.env.deploy ]; then
    source ./deploy/.env.deploy
fi

# Configuration
cUSER="ubuntu"
HOST="51.178.42.132"
REMOTE_DIR="/home/ubuntu/kaetram"

# Install sshpass if not present
if ! command -v sshpass &> /dev/null; then
    echo "sshpass is required but not installed. Please install it."
    exit 1
fi

echo "Updating $cUSER@$HOST..."

# 1. Sync Code (Rsync)
echo "Syncing code..."
sshpass -e rsync -avz --delete --exclude 'node_modules' --exclude '.git' --exclude 'dist' --exclude '.env' -e "ssh -o StrictHostKeyChecking=no" ./ $cUSER@$HOST:$REMOTE_DIR

# 2. Remote Rebuild & Restart
echo "Rebuilding and restarting..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    source ~/.bashrc
    
    # Install dependencies (in case of changes)
    yarn install
    
    # Rebuild
    yarn run build
    
    # Update Nginx
    sudo cp deploy/nginx.conf /etc/nginx/sites-available/kaetram
    sudo nginx -t && sudo systemctl restart nginx

    # Restart PM2
    pm2 delete all || true
    pm2 start deploy/ecosystem.config.cjs
    pm2 save
EOF

echo "Update complete!"
