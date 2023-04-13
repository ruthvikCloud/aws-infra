## CSYE6225- Network Structures and Cloud Computing



<br>Infrastructure as Code: This assignment will focus on setting up networking resources such as Virtual Private Cloud (VPC), Internet Gateway, Route Table, and Routes. We use Terraform for infrastructure setup and tear down. <br><br>

## Terraform
Terraform is an open-source infrastructure as code software tool that enables you to safely and predictably create, change, and improve infrastructure <br><br>

## Setting up Infrastructure using Terraform 
 
<br> The terraform init command initializes a working directory containing Terraform configuration files:
```
terraform init
```

The terraform plan command creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure:
```
terraform plan
```

The terraform apply command executes the actions proposed in a Terraform plan to create, update, or destroy infrastructure:
```
terraform apply
```

The terraform destroy command is a convenient way to destroy all remote objects managed by a particular Terraform configuration:
```
terraform destroy
```

The command to import the SSL certificate:
```
aws acm import-certificate \
--certificate fileb://<file_path_of_crt_file> \
--certificate-chain fileb://<file_path_of_chain_file \
--private-key fileb://file_path_of_private_key \
--region us-east-1 \
--profile <profile>
```


<br>
Developer - Ruthvik Garlapati <br>
NUID - 002727922 </br>
Email - garlapati.r@northeastern.edu