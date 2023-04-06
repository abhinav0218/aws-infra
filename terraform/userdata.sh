#!/bin/bash
 cd /home/ec2-user/script
 touch ./.env

 echo "DB_HOST=$(echo ${DB_HOST} | cut -d ':' -f 1)" >> .env
 echo "DB_USER=${DB_USER}" >> .env
 echo "DB_PASSWORD=${DB_PASSWORD}" >> .env
 echo "S3_BUCKET_NAME=${S3_BUCKET_NAME}" >> .env

 sudo su
 mkdir ./upload
 sudo chown ec2-user:ec2-user /home/ec2-user/script/*
 sudo systemctl stop webapp.service
 sudo systemctl daemon-reload
 sudo systemctl enable webapp.service
 sudo systemctl start webapp.service
 source ./.env
