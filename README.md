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

