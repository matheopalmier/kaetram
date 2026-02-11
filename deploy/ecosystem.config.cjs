module.exports = {
    apps: [
        {
            name: 'kaetram-server',
            script: './dist/main.js',
            cwd: '/home/ubuntu/kaetram/packages/server',
            instances: 1,
            autorestart: true,
            watch: false,
            max_memory_restart: '1G',
            env: {
                NODE_ENV: 'production',
                PORT: 9001
            }
        }
    ]
};
