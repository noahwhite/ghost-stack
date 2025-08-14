#cloud-config
packages:
  - docker.io
runcmd:
  - curl -sL https://deb.nodesource.com/setup_16.x | bash -
  - apt-get install -y nodejs
  - npm install -g ghost-cli
  - mkdir -p /var/www/ghost
  - chown -R $USER:$USER /var/www/ghost
  - cd /var/www/ghost && ghost install --no-prompt --url=https://www.separationofconcerns.dev/soc --db=sqlite3 --start
