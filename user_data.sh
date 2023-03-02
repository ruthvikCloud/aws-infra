#! /bin/bash


cd webapp-main
touch .env
sudo cat >> /home/ec2-user/webapp-main/.env <<'EOF'
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASS=${db_pwd}
DB_DATABASE=${db}
DB_DIALECT=${db_engine}
DB_PORT=${db_port}
AWS_BUCKET_NAME=${s3_bucket}
AWS_BUCKET_REGION=${s3_region}
SERVER_PORT="3000"
EOF
npm i --save
npm i dotenv --save
sudo systemctl daemon-reload
sudo systemctl enable webapp.service
sudo systemctl start webapp.service
sudo systemctl status webapp.service