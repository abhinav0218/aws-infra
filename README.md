# aws-infra

We have 3 main files here

The provider.tf contains the provider and region details

The main.tf contains all the variables, their types and their default values and modules to be created.

The network.tf contains all the resources which are to be created.


To run the terraform configuration files, we have to run the following commands
1. *terraform init*  -  this command initializes the backend processes and makes the ground ready for creation.
2. *terraform apply* - this command creates all the resources listed in the config files. Before creation a confirmation is asked.
3. *Terraform destroy* - this command destroys all the created and active resources

Assignment 9

In this assignment we are adding Continuous deployment of Web application using github actions for building a new AMI of latest version 

Requested a new SSL certificate for demo through AWS certificate manager. For demo account I have used namecheap to generate a SSL certificate.For generating the certificate I have followed these steps:

Requested SSL certificate through namecheap for 1 year.

Added CNAME in the AWS demo account using host and target details.

Generated CSR using these commands:

sudo openssl genrsa -out private.key 2048 --> Generates a new private key

sudo openssl req -new -newkey rsa:2048 -nodes -keyout private.key -out csr.pem --> generates a CSR

After activating SSL certificate I have imported to AWS Demo account using this command:


aws acm import-certificate --certificate fileb://demo_abhinavpalem_me/demo_abhinavpalem_me.crt \ 
      --certificate-chain fileb://demo_abhinavpalem_me/demo_abhinavpalem_me.ca-bundle \
      --private-key fileb://private.key --profile demo


Certficate file = demo_abhinavpalem_me.crt
Certficate chain = demo_abhinavpalem_me.ca-bundle
private key = private.key

I have added encryption to RDS instance and EBS volumes of EC2 instances using kms policy.

