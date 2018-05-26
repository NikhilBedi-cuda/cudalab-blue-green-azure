#!/bin/bash
echo "
##############################################################################################################
#  _                         
# |_) _  __ __ _  _     _| _ 
# |_)(_| |  | (_|(_ |_|(_|(_|
#
# Deployment of CUDALAB EU configuration in Microsoft Azure using Terraform and Ansible
#
##############################################################################################################
"

# Stop running when command returns error
set -e

#SECRET="/ssh/secrets.tfvars"
#STATE="terraform.tfstate"
PLAN="terraform.plan"
ANSIBLEINVENTORYDIR="ansible-blue/inventory"
ANSIBLEWAFINVENTORYDIR="ansible-blue-waf/inventory"
ANSIBLEWEBINVENTORY="$ANSIBLEINVENTORYDIR/web"
ANSIBLESQLINVENTORY="$ANSIBLEINVENTORYDIR/sql"
ANSIBLEWAFINVENTORY="$ANSIBLEWAFINVENTORYDIR/waf"

TODAY=`date +"%Y-%m-%d"`

echo "$@" > /tmp/key2
echo "$8" > /tmp/key3

while getopts "a:b:c:d:p:s:" option; do
    case "${option}" in
        a) ANSIBLEOPTS="$OPTARG" ;;
        b) BACKEND_ARM_ACCESS_KEY="$OPTARG" ;;
        c) CCSECRET="$OPTARG" ;;
        d) DB_PASSWORD="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        s) SSH_KEY_DATA="$OPTARG" ;;
    esac
done

echo ""
echo "==> Verifying SSH key location and permissions"
echo ""
chmod 700 `dirname $DOWNLOADSECUREFILE1_SECUREFILEPATH`
chmod 600 $DOWNLOADSECUREFILE1_SECUREFILEPATH

echo ""
echo "==> Terraform init"
echo ""
echo "BACKEND_STORAGE_ACCOUNT_NAME: [$BACKEND_STORAGE_ACCOUNT_NAME]"
#terraform init -backend-config=terraform-blue/backend-blue.tfvars -backend_config="access_key=$BACKEND_ARM_ACCESS_KEY" terraform-blue/
terraform init \
  -backend-config="storage_account_name=$BACKEND_STORAGE_ACCOUNT_NAME" \
  -backend-config="container_name=$BACKEND_CONTAINER_NAME" \
  -backend-config="key=$BACKEND_KEY" \
  -backend-config="access_key=$BACKEND_ARM_ACCESS_KEY" \
  terraform-blue/

echo ""
echo "==> Terraform plan"
echo ""
terraform plan --out "$PLAN" -var "CCSECRET=$CCSECRET" -var "PASSWORD=$PASSWORD" -var "SSH_KEY_DATA=$SSH_KEY_DATA" terraform-blue/

echo ""
echo "==> Terraform apply"
echo ""
terraform apply "$PLAN"

echo ""
echo "==> Terraform graph"
echo ""
terraform graph terraform-blue/ | dot -Tsvg > blue-graph.svg

echo ""
echo "==> Creating inventory directories for Ansible"
echo ""
mkdir -p $ANSIBLEINVENTORYDIR
mkdir -p $ANSIBLEWAFINVENTORYDIR

echo ""
echo "==> Terraform output to Ansible web inventory"
echo ""
terraform output -state="$STATE" web_ansible_inventory > "$ANSIBLEWEBINVENTORY"

echo ""
echo "==> Terraform output to Ansible sql inventory"
echo ""
terraform output -state="$STATE" sql_ansible_inventory > "$ANSIBLESQLINVENTORY"

echo ""
echo "==> Terraform output to Ansible waf inventory"
echo ""
terraform output -state="$STATE" waf_ansible_inventory > "$ANSIBLEWAFINVENTORY"

echo ""
echo "==> Ansible configuration web server"
echo ""
#ansible-playbook ansible-blue/deploy.yml $ANSIBLEOPTS -i "$ANSIBLEWEBINVENTORY"

echo ""
echo "==> Ansible configuration sql server"
echo ""
#ansible-playbook ansible-blue/deploy.yml $ANSIBLEOPTS -i "$ANSIBLESQLINVENTORY" --extra-vars "db_password=$DB_PASSWORD"

echo ""
echo "==> Ansible bootstrap waf server"
echo ""
ansible-playbook ansible-blue-waf/bootstrap.yml $ANSIBLEOPTS -i "$ANSIBLEWAFINVENTORY"

echo ""
echo "==> Ansible configuration waf server"
echo ""
ansible-playbook ansible-blue-waf/deploy.yml $ANSIBLEOPTS -i "$ANSIBLEWAFINVENTORY" --extra-vars "waf_password=$PASSWORD"
