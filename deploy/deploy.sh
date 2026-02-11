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

echo "Deploying to $cUSER@$HOST..."

# 1. Provision VPS (Run setup script)
echo "Provisioning VPS..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST "mkdir -p $REMOTE_DIR/deploy"
sshpass -e scp -o StrictHostKeyChecking=no deploy/setup_vps.sh $cUSER@$HOST:$REMOTE_DIR/deploy/
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST "chmod +x $REMOTE_DIR/deploy/setup_vps.sh && $REMOTE_DIR/deploy/setup_vps.sh"

# 2. Sync Code (Rsync)
echo "Syncing code..."
# Exclude node_modules, .git, etc.
sshpass -e rsync -avz --delete --exclude 'node_modules' --exclude '.git' --exclude 'dist' --exclude '.env' ./ $cUSER@$HOST:$REMOTE_DIR

# 3. Remote Build (Install & Build)
echo "Building on remote..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    
    # Load env vars
    source ~/.bashrc

    # Install dependencies
    yarn install

    # Build packages
    yarn run build
EOF

# 4. Start Services (PM2 & Nginx)
echo "Starting services..."
sshpass -e scp -o StrictHostKeyChecking=no deploy/nginx.conf $cUSER@$HOST:$REMOTE_DIR/deploy/
sshpass -e scp -o StrictHostKeyChecking=no deploy/ecosystem.config.cjs $cUSER@$HOST:$REMOTE_DIR/deploy/

sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    
    # Configure Nginx
    sudo cp deploy/nginx.conf /etc/nginx/sites-available/kaetram
    sudo ln -sf /etc/nginx/sites-available/kaetram /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl restart nginx

    # Start PM2
    pm2 start deploy/ecosystem.config.cjs
    pm2 save
EOF

echo "Deployment complete!"
