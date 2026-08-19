module.exports = {
  apps: [
    {
      name: 'kata-api',
      cwd: '/opt/kata/api',
      script: 'dist/src/main.js',
      node_args: '--enable-source-maps',
      time: true,
      autorestart: true,
      max_restarts: 10,
      env: { NODE_ENV: 'production' },
    },
  ],
};
