# aks_lab

This repository contains Infrastructure as Code (IaC) for Azure that bootstraps an AKS (Azure Kubernetes Service) cluster along with related resources. It also demonstrates deployment of ArgoCD and applications for learning, demos, and showcase purposes.

## Features

- ⎈ Automated AKS cluster provisioning on Azure
- 🐙 Deploys ArgoCD for GitOps-based application deployment
- 🚀 Bootstraps relevant networking, identity, and cluster configuration resources
- 📚 Suitable for hands-on Azure and Kubernetes learning 📚
- 📊 Demonstrates practical Terraform and AKS usage


## Overview of Workflows in `aks_lab`

### 1. Terraform Dev Check Workflow

- **Purpose:** This workflow runs on pull requests targeting the `main` branch to validate Terraform code in the `./terraform/` directory.
- **Actions:**  
  - Checks out the repository code.
  - Authenticates with Azure using credentials from secrets.
  - Sets up Terraform CLI.
  - Runs formatting checks (`terraform fmt`), linting (`tflint`), and policy checks (`Checkov`).
  - Runs `terraform init` with backend config.
  - Plans Terraform changes.
  - Logs out from Azure to clean up environment.
- **Additional:**  
  - Includes steps to calculate and comment Infracost cost estimates on PRs. (FinOps 💰)
  - Updates Infracost cloud with PR status upon closure.

### 2. Terraform Main Deployment Workflow

- **Purpose:** Deploys and applies Terraform code to provision infrastructure when changes are pushed to the `main` branch.
- **Trigger:** Runs on push events changing files inside the `terraform/` directory on the `main` branch.
- **Actions:**  
  - Checks out code.
  - Logs in to Azure.
  - Sets up Terraform.
  - Runs `terraform init`, `terraform plan`, and `terraform apply` (auto-approved) commands.
  - Logs out from Azure after completion.
- **Additional:**  
  - Runs Infracost cost analysis on the default branch and updates Infracost Cloud with the cost breakdown. (FinOps 💰)

### 3. Log Cleanup Workflow

- **Purpose:** Cleans up old GitHub Actions workflow run logs to keep the repository clean.
- **Trigger:** Runs on schedule every 5 minutes and can be manually triggered (`workflow_dispatch`).
- **Actions:**  
  - Checks out the repo code.
  - Deletes workflow run logs older than configured days (0 days here means all logs).
  - Uses a Personal Access Token (`secrets.CLEAN_WF`) with appropriate permissions to delete logs.
  - Runs with `continue-on-error: true` to avoid workflow failure if cleanup errors occur.

## Dependency Management with Renovate

This repository uses [Renovate](https://renovatebot.com/) to automate dependency updates.

- Renovate is configured using the `renovate.json` file with the recommended preset.
- It automatically scans for outdated dependencies and creates Pull Requests to update them.
- This helps keep dependencies up-to-date, secure, and reduces manual maintenance overhead.
- You can find further details and customize Renovate via its configuration documentation: https://docs.renovatebot.com/

By integrating Renovate, this repo maintains a clean and secure dependency graph over time.



# Notes
```
AKS_ID=$(az aks show --resource-group aks --name demo --query id -o tsv)
az role assignment create --assignee <user-object-id> --role "Azure Kubernetes Service Cluster Admin Role" --scope $AKS_ID
az role assignment create --assignee <user-object-id> --role "Azure Kubernetes Service RBAC Cluster Admin" --scope $AKS_ID
az aks get-credentials -g aks -n demo --overwrite-existing
kubectl get po
<devicelogin>

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo list
argocd repo add https://prometheus-community.github.io/helm-charts --type helm --name prometheus-community
argocd app create kube-prometheus-stack \
  --repo https://prometheus-community.github.io/helm-charts \
  --helm-chart kube-prometheus-stack \
  --revision 79.5.0 \
  --dest-server https://kubernetes.default.svc

```
