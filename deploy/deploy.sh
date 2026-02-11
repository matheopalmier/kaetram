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


# Install sshpass if not present (Local check, though we checked in planning)
if ! command -v sshpass &> /dev/null; then
    echo "sshpass is required but not installed. Please install it."
    exit 1
fi

echo "--- Starting Deployment to $HOST ---"

# 1. Provision Server (Install Deps)
echo "[1/4] Provisioning Server..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST "mkdir -p $REMOTE_DIR/deploy"
sshpass -e scp -o StrictHostKeyChecking=no deploy/setup_vps.sh $cUSER@$HOST:$REMOTE_DIR/deploy/
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST "bash $REMOTE_DIR/deploy/setup_vps.sh"

# 2. Sync Code
echo "[2/4] Syncing Code..."
# Exclude node_modules, .git, dist, etc.
sshpass -e rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.yarn/cache' \
    --exclude 'dist' \
    --exclude '.env' \
    --exclude 'deploy' \
    ./ $cUSER@$HOST:$REMOTE_DIR/

# Transfer config files
sshpass -e scp -o StrictHostKeyChecking=no deploy/ecosystem.config.cjs $cUSER@$HOST:$REMOTE_DIR/
sshpass -e scp -o StrictHostKeyChecking=no deploy/nginx.conf $cUSER@$HOST:$REMOTE_DIR/deploy/

# 3. Build Remote
echo "[3/4] Building Remotely..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    
    # Create production env file if not exists
    if [ ! -f .env ]; then
        echo "Creating .env..."
        cp .env.defaults .env
        # Update .env for production
        sed -i 's/HOST=.*/HOST="51.178.42.132"/' .env
        sed -i 's/MONGODB_HOST=.*/MONGODB_HOST="127.0.0.1"/' .env
        sed -i 's/MONGODB_DATABASE=.*/MONGODB_DATABASE="kaetram_prod"/' .env
    fi

    # Install dependencies
    echo "Installing Yarn dependencies..."
    yarn install

    # Build everything
    echo "Building project..."
    yarn packages build

EOF

# 4. Start Services
echo "[4/4] Starting Services..."
sshpass -e ssh -o StrictHostKeyChecking=no $cUSER@$HOST << EOF
    cd $REMOTE_DIR
    
    # PM2
    pm2 start ecosystem.config.cjs
    pm2 save
    pm2 startup | tail -n 1 | bash # Ensure startup script is generated

    # Nginx
    sudo cp deploy/nginx.conf /etc/nginx/sites-available/kaetram
    sudo ln -sf /etc/nginx/sites-available/kaetram /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t && sudo systemctl reload nginx
EOF

echo "--- Deployment Complete! ---"
echo "Game Client: http://$HOST"
echo "Game Server: http://$HOST:9001"
