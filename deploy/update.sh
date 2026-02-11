#!/bin/bash

# Configuration
cUSER="ubuntu"
HOST="51.178.42.132"
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

echo "--- Starting Update to $HOST ---"

# 1. Sync Code
echo "[1/3] Syncing Code..."
sshpass -e rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.yarn/cache' \
    --exclude 'dist' \
    --exclude '.env' \
    --exclude 'deploy' \
    ./ $cUSER@$HOST:$REMOTE_DIR/

# 2. Build Remote
echo "[2/3] Building Remotely..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    
    # Install dependencies (in case package.json changed)
    echo "Installing Yarn dependencies..."
    yarn install

    # Build everything
    echo "Building project..."
    yarn packages build
EOF

# 3. Restart Services
echo "[3/3] Restarting Services..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    pm2 restart kaetram-server
    pm2 save
EOF

echo "--- Update Complete! ---"
