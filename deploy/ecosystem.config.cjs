module.exports = {
    apps: [
        {
            name: 'kaetram-server',
            script: 'yarn',
            args: 'workspace @kaetram/server start',
            cwd: '/home/ubuntu/kaetram',
            interpreter: 'none',
            env: {
                NODE_ENV: 'production'
            }
        },
        {
            name: 'kaetram-hub',
            script: 'yarn',
            args: 'workspace @kaetram/hub start',
            cwd: '/home/ubuntu/kaetram',
            interpreter: 'none',
            env: {
                NODE_ENV: 'production'
            }
        }
    ]
};
