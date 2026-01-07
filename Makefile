.PHONY: help init plan apply destroy fmt validate clean
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# Cluster directories mapping
# Maps cluster name (e.g., "public") to directory path
define cluster_dir
$(if $(filter public,$1),clusters/examples/public,\
$(if $(filter private,$1),clusters/examples/private,\
$(if $(filter egress-zero,$1),clusters/examples/egress-zero,\
$(error Unknown cluster: $1))))
endef

# Helper function to get cluster directory from target suffix
# Usage: $(call get_cluster_dir,$*)
get_cluster_dir = $(call cluster_dir,$*)

# Backwards compatibility - explicit cluster directories
CLUSTER_PUBLIC := clusters/examples/public
CLUSTER_PRIVATE := clusters/examples/private
CLUSTER_EGRESS_ZERO := clusters/examples/egress-zero

help: ## Show this help message
	@echo "$(BLUE)ROSA HCP Infrastructure - Makefile Targets$(NC)"
	@echo ""
	@echo "$(GREEN)Cluster Management:$(NC)"
	@echo "  Pattern syntax: make <action>.<cluster>"
	@echo "  Examples: make init.public, make plan.private, make apply.egress-zero"
	@echo ""
	@echo "  make init.<cluster>       Initialize Terraform (clusters: public, private, egress-zero)"
	@echo "  make plan.<cluster>       Plan cluster deployment (saves to terraform.tfplan)"
	@echo "  make apply.<cluster>      Apply cluster configuration (uses terraform.tfplan)"
	@echo "  make destroy.<cluster>    Destroy cluster"
	@echo ""
	@echo "  Legacy syntax (still supported):"
	@echo "  make init-public, plan-public, apply-public, destroy-public"
	@echo "  make init-private, plan-private, apply-private, destroy-private"
	@echo "  make init-egress-zero, plan-egress-zero, apply-egress-zero, destroy-egress-zero"
	@echo ""
	@echo "$(GREEN)Code Quality:$(NC)"
	@echo "  make fmt                  Format all Terraform files"
	@echo "  make validate             Validate all Terraform modules"
	@echo "  make validate-modules     Validate all modules"
	@echo "  make validate-examples    Validate all example clusters"
	@echo ""
	@echo "$(GREEN)Utilities:$(NC)"
	@echo "  make clean                Clean Terraform files (.terraform, .terraform.lock.hcl)"
	@echo "  make init-all             Initialize all clusters"
	@echo "  make plan-all             Plan all clusters"
	@echo ""
	@echo "$(GREEN)Cluster Access:$(NC)"
	@echo "  Pattern syntax: make <action>.<cluster>"
	@echo "  Examples: make login.public, make show-endpoints.private, make show-credentials.egress-zero"
	@echo ""
	@echo "  make login.<cluster>            Login to cluster using oc CLI"
	@echo "  make show-endpoints.<cluster>    Show API and console URLs"
	@echo "  make show-credentials.<cluster>  Show admin credentials and endpoints"
	@echo ""
	@echo "$(GREEN)Bastion & Tunnel Management:$(NC)"
	@echo "  Pattern syntax: make <action>.<cluster>"
	@echo "  Examples: make tunnel-start.private, make tunnel-stop.egress-zero"
	@echo ""
	@echo "  make tunnel-start.<cluster>     Start sshuttle VPN tunnel via bastion (routes all VPC traffic)"
	@echo "                                   Requires: sshuttle (brew install sshuttle on macOS)"
	@echo "  make tunnel-stop.<cluster>      Stop sshuttle tunnel"
	@echo "  make tunnel-status.<cluster>    Check if tunnel is running"
	@echo "  make bastion-connect.<cluster>  Connect to bastion via SSM Session Manager"
	@echo ""
	@echo "$(GREEN)Infrastructure & Configuration (New Structure):$(NC)"
	@echo "  The new structure separates infrastructure and configuration:"
	@echo "    clusters/examples/<cluster>/infrastructure/  - VPC, IAM, ROSA cluster"
	@echo "    clusters/examples/<cluster>/configuration/   - GitOps, Loki, etc."
	@echo ""
	@echo "  make apply-infra.<cluster>      Deploy infrastructure (VPC, IAM, cluster)"
	@echo "  make apply-config.<cluster>     Deploy configuration (reads from terraform.tfvars)"
	@echo "  make deploy.<cluster>           Full deployment: infrastructure + login + configuration"
	@echo "  make show-infra.<cluster>       Show infrastructure outputs"
	@echo "  make show-config.<cluster>      Show configuration outputs"
	@echo "  make destroy-config.<cluster>   Destroy configuration only"
	@echo "  make destroy-infra.<cluster>    Destroy infrastructure only"
	@echo ""
	@echo "  Configuration is controlled by terraform.tfvars:"
	@echo "    loki_enabled = true           # Enable Loki logging"
	@echo "    # Future: monitoring_enabled, external_secrets_enabled, etc."
	@echo ""
	@echo "  Example: make deploy.public"
	@echo ""
	@echo "$(GREEN)Existing Cluster Deployment:$(NC)"
	@echo "  For deploying to an existing ROSA cluster (not managed by this Terraform):"
	@echo ""
	@echo "  1. Copy the template:"
	@echo "     cp -r clusters/existing-cluster-template clusters/my-cluster"
	@echo ""
	@echo "  2. Configure terraform.tfvars with your cluster details"
	@echo "     (see clusters/existing-cluster-template/README.md)"
	@echo ""
	@echo "  3. Deploy:"
	@echo "     make deploy-existing CLUSTER=my-cluster"
	@echo ""
	@echo "  make deploy-existing CLUSTER=<name>   Deploy to existing cluster"
	@echo "  make destroy-existing CLUSTER=<name>  Remove configuration from existing cluster"
	@echo ""

# Initialize Terraform for clusters
# Pattern rule: make init.public, make init.private, make init.egress-zero
init.%:
	@echo "$(BLUE)Initializing $* cluster...$(NC)"
	@cd $(call get_cluster_dir,$*) && terraform init -reconfigure

# Explicit targets for backwards compatibility
init-public: init.public ## Initialize Terraform for public cluster
init-private: init.private ## Initialize Terraform for private cluster
init-egress-zero: init.egress-zero ## Initialize Terraform for egress-zero cluster

init-all: init.public init.private init.egress-zero ## Initialize all clusters

# Plan deployments (depend on init to ensure backend is configured)
# Pattern rule: make plan.public, make plan.private, make plan.egress-zero
plan.%: init.%
	@echo "$(BLUE)Planning $* cluster...$(NC)"
	@cd $(call get_cluster_dir,$*) && terraform plan -out=terraform.tfplan

# Explicit targets for backwards compatibility
plan-public: plan.public ## Plan public cluster deployment
plan-private: plan.private ## Plan private cluster deployment
plan-egress-zero: plan.egress-zero ## Plan egress-zero cluster deployment

plan-all: plan.public plan.private plan.egress-zero ## Plan all clusters

# Apply configurations (depend on init and plan)
# Pattern rule: make apply.public, make apply.private, make apply.egress-zero
apply.%: init.% plan.%
	@echo "$(YELLOW)Applying $* cluster configuration...$(NC)"
	@cd $(call get_cluster_dir,$*) && terraform apply terraform.tfplan

# Explicit targets for backwards compatibility
apply-public: apply.public ## Apply public cluster configuration
apply-private: apply.private ## Apply private cluster configuration
apply-egress-zero: apply.egress-zero ## Apply egress-zero cluster configuration

# Destroy clusters
# Pattern rule: make destroy.public, make destroy.private, make destroy.egress-zero
# Terraform automatically handles destroy order: cluster depends on IAM outputs, so cluster is destroyed first
destroy.%:
	@echo "$(YELLOW)WARNING: This will destroy the $* cluster!$(NC)"
	@cd $(call get_cluster_dir,$*) && terraform destroy -auto-approve

# Explicit targets for backwards compatibility
destroy-public: destroy.public ## Destroy public cluster
destroy-private: destroy.private ## Destroy private cluster
destroy-egress-zero: destroy.egress-zero ## Destroy egress-zero cluster

# Code quality
fmt: ## Format all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive

validate: validate-modules validate-examples ## Validate all Terraform code

validate-modules: ## Validate all modules
	@echo "$(BLUE)Validating modules...$(NC)"
	@for dir in modules/*/; do \
		echo "Validating $$dir..."; \
		cd $$dir && terraform init -backend=false >/dev/null 2>&1 && terraform validate && cd - >/dev/null || echo "  ✗ Failed: $$dir"; \
	done

validate-examples: ## Validate all example clusters
	@echo "$(BLUE)Validating example clusters...$(NC)"
	@for dir in $(CLUSTER_PUBLIC) $(CLUSTER_PRIVATE) $(CLUSTER_EGRESS_ZERO); do \
		echo "Validating $$dir..."; \
		cd $$dir && terraform init -backend=false >/dev/null 2>&1 && terraform validate && cd - >/dev/null || echo "  ✗ Failed: $$dir"; \
	done

# Cluster Access - Show Endpoints
# Pattern rule: make show-endpoints.public, make show-endpoints.private, make show-endpoints.egress-zero
show-endpoints.%:
	@echo "$(BLUE)$(shell echo $* | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g') Cluster Endpoints:$(NC)"
	@cd $(call get_cluster_dir,$*) && \
		API_URL=$$(terraform output -raw api_url 2>/dev/null) && \
		if [ -z "$$API_URL" ]; then \
			echo "$(YELLOW)Cluster not deployed or terraform outputs not available$(NC)"; \
			exit 1; \
		fi && \
		VPC_CIDR=$$(terraform output -raw vpc_cidr_block 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.vpc_cidr_block.value // empty') && \
		terraform output -json 2>/dev/null | \
			jq -r '"API URL:     " + .api_url.value, "Console URL:  " + .console_url.value' 2>/dev/null && \
		if [ -n "$$VPC_CIDR" ] && pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
			echo "$(GREEN)✓ sshuttle tunnel active - all VPC traffic routed through bastion$(NC)"; \
		fi

# Explicit targets for backwards compatibility
show-endpoints-public: show-endpoints.public ## Show API and console URLs for public cluster
show-endpoints-private: show-endpoints.private ## Show API and console URLs for private cluster
show-endpoints-egress-zero: show-endpoints.egress-zero ## Show API and console URLs for egress-zero cluster

# Cluster Access - Show Credentials (includes endpoints)
# Pattern rule: make show-credentials.public, make show-credentials.private, make show-credentials.egress-zero
show-credentials.%: show-endpoints.%
	@echo "$(BLUE)$(shell echo $* | tr '[:lower:]' '[:upper:]' | sed 's/-/ /g') Cluster Credentials:$(NC)"
	@cd $(call get_cluster_dir,$*) && \
		if [ -z "$$TF_VAR_admin_password" ]; then \
			echo "$(YELLOW)Warning: TF_VAR_admin_password not set. Checking terraform.tfvars...$(NC)"; \
			if [ -f "terraform.tfvars" ]; then \
				admin_password=$$(grep -E "^admin_password\s*=" terraform.tfvars | sed -E "s/^[^=]*=\s*['\"]?([^'\"]+)['\"]?/\1/" | head -1); \
				if [ -n "$$admin_password" ]; then \
					echo "Admin Username: admin"; \
					echo "Admin Password: $$admin_password"; \
				else \
					echo "$(YELLOW)Admin password not found in terraform.tfvars$(NC)"; \
				fi; \
			else \
				echo "$(YELLOW)terraform.tfvars not found$(NC)"; \
			fi; \
		else \
			echo "Admin Username: admin"; \
			echo "Admin Password: $$TF_VAR_admin_password"; \
		fi

# Explicit targets for backwards compatibility
show-credentials-public: show-credentials.public ## Show admin credentials and endpoints for public cluster
show-credentials-private: show-credentials.private ## Show admin credentials and endpoints for private cluster
show-credentials-egress-zero: show-credentials.egress-zero ## Show admin credentials and endpoints for egress-zero cluster

# Cluster Access - Login
# Pattern rule: make login.public, make login.private, make login.egress-zero
login.%:
	@echo "$(BLUE)Logging into $* cluster...$(NC)"
	@if ! command -v oc >/dev/null 2>&1; then \
		echo "$(YELLOW)Error: oc CLI not found. Please install OpenShift CLI.$(NC)"; \
		exit 1; \
	fi
	@cd $(call get_cluster_dir,$*) && \
		API_URL=$$(terraform output -raw api_url 2>/dev/null) && \
		if [ -z "$$API_URL" ]; then \
			echo "$(YELLOW)Error: Cluster not deployed or api_url output not available$(NC)"; \
			exit 1; \
		fi && \
		VPC_CIDR=$$(terraform output -raw vpc_cidr_block 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.vpc_cidr_block.value // empty') && \
		if [ -n "$$VPC_CIDR" ] && pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
			echo "$(GREEN)sshuttle tunnel active - using direct API URL (traffic routed through bastion)$(NC)"; \
		fi && \
		LOGIN_URL=$$API_URL && \
		if [ -z "$$TF_VAR_admin_password" ]; then \
			if [ -f "terraform.tfvars" ]; then \
				ADMIN_PASSWORD=$$(grep -E "^admin_password\s*=" terraform.tfvars | sed -E "s/^[^=]*=\s*['\"]?([^'\"]+)['\"]?/\1/" | head -1); \
				if [ -z "$$ADMIN_PASSWORD" ]; then \
					echo "$(YELLOW)Error: Admin password not found. Set TF_VAR_admin_password or add to terraform.tfvars$(NC)"; \
					exit 1; \
				fi; \
			else \
				echo "$(YELLOW)Error: Admin password required. Set TF_VAR_admin_password or add to terraform.tfvars$(NC)"; \
				exit 1; \
			fi; \
		else \
			ADMIN_PASSWORD=$$TF_VAR_admin_password; \
		fi && \
		oc login $$LOGIN_URL --username admin --password $$ADMIN_PASSWORD --insecure-skip-tls-verify=false || \
		(echo "$(YELLOW)Login failed. Check credentials and cluster status.$(NC)" && exit 1)

# Explicit targets for backwards compatibility
login-public: login.public ## Login to public cluster using oc CLI
login-private: login.private ## Login to private cluster using oc CLI
login-egress-zero: login.egress-zero ## Login to egress-zero cluster using oc CLI

# Bastion & Tunnel Management
# Pattern rule: make tunnel-start.private, make tunnel-stop.egress-zero, etc.
# Uses sshuttle to create a VPN-like tunnel for full cluster access (including OAuth)
tunnel-start.%:
	@echo "$(BLUE)Starting sshuttle VPN tunnel to $* cluster via bastion...$(NC)"
	@if ! command -v sshuttle >/dev/null 2>&1; then \
		echo "$(YELLOW)Error: sshuttle not found.$(NC)"; \
		echo "$(YELLOW)Installation instructions:$(NC)"; \
		echo "  macOS:  brew install sshuttle"; \
		echo "  Linux:  pip install sshuttle  (or use your package manager)"; \
		echo "  See:    https://github.com/sshuttle/sshuttle"; \
		exit 1; \
	fi
	@if ! command -v aws >/dev/null 2>&1; then \
		echo "$(YELLOW)Error: aws CLI not found. Please install AWS CLI.$(NC)"; \
		exit 1; \
	fi
	@cd $(call get_cluster_dir,$*) && \
		BASTION_ID=$$(terraform output -raw bastion_instance_id 2>/dev/null) && \
		if [ -z "$$BASTION_ID" ] || [ "$$BASTION_ID" = "null" ]; then \
			echo "$(YELLOW)Error: Bastion not deployed. Enable bastion with enable_bastion=true$(NC)"; \
			exit 1; \
		fi && \
		VPC_CIDR=$$(terraform output -raw vpc_cidr_block 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.vpc_cidr_block.value // empty') && \
		if [ -z "$$VPC_CIDR" ]; then \
			echo "$(YELLOW)Error: VPC CIDR not found in terraform outputs$(NC)"; \
			exit 1; \
		fi && \
		REGION=$$(terraform output -raw region 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.region.value // empty' || echo "us-east-1") && \
		if [ -z "$$REGION" ]; then \
			REGION=$$(grep -E "^region\s*=" terraform.tfvars 2>/dev/null | cut -d'"' -f2 | cut -d"'" -f2 | head -1 || echo "us-east-1"); \
		fi && \
		if pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
			echo "$(YELLOW)sshuttle tunnel already running for $$VPC_CIDR$(NC)"; \
			exit 0; \
		fi && \
		echo "$(YELLOW)Note: sshuttle requires sudo privileges. You will be prompted for your local sudo password.$(NC)" && \
		sudo sshuttle --ssh-cmd "ssh -i $(HOME)/.ssh/id_rsa -o ProxyCommand='aws --region $$REGION ssm start-session --target $$BASTION_ID --document-name AWS-StartSSHSession --parameters portNumber=22' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
			--remote ec2-user@$$BASTION_ID \
			--dns $$VPC_CIDR \
			$$VPC_CIDR \
			--daemon \
			--pidfile /tmp/sshuttle-$$*-$$BASTION_ID.pid && \
		echo "$(GREEN)sshuttle tunnel started for VPC $$VPC_CIDR$(NC)" && \
		echo "$(GREEN)All traffic to $$VPC_CIDR is now routed through the bastion$(NC)" && \
		echo "$(GREEN)You can now use oc login with the direct API URL$(NC)" || \
		(echo "$(YELLOW)Failed to start tunnel. Check bastion status and AWS credentials.$(NC)" && echo "$(YELLOW)Note: sshuttle requires sudo privileges.$(NC)" && exit 1)

tunnel-stop.%:
	@echo "$(BLUE)Stopping sshuttle tunnel for $* cluster...$(NC)"
	@cd $(call get_cluster_dir,$*) && \
		BASTION_ID=$$(terraform output -raw bastion_instance_id 2>/dev/null) && \
		if [ -z "$$BASTION_ID" ] || [ "$$BASTION_ID" = "null" ]; then \
			echo "$(YELLOW)Bastion not deployed$(NC)"; \
			exit 0; \
		fi && \
		PIDFILE="/tmp/sshuttle-$$*-$$BASTION_ID.pid" && \
		if [ -f "$$PIDFILE" ]; then \
			PID=$$(cat $$PIDFILE 2>/dev/null) && \
			if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null; then \
				sudo kill $$PID && \
				sudo rm -f $$PIDFILE && \
				echo "$(GREEN)Tunnel stopped$(NC)"; \
			else \
				sudo rm -f $$PIDFILE && \
				echo "$(YELLOW)Tunnel process not found (cleaned up PID file)$(NC)"; \
			fi; \
		else \
			VPC_CIDR=$$(terraform output -raw vpc_cidr_block 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.vpc_cidr_block.value // empty') && \
			if [ -n "$$VPC_CIDR" ] && pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
				sudo pkill -f "sshuttle.*$$VPC_CIDR" && \
				echo "$(GREEN)Tunnel stopped$(NC)"; \
			else \
				echo "$(YELLOW)No tunnel found running$(NC)"; \
			fi; \
		fi

tunnel-status.%:
	@echo "$(BLUE)Checking sshuttle tunnel status for $* cluster...$(NC)"
	@cd $(call get_cluster_dir,$*) && \
		BASTION_ID=$$(terraform output -raw bastion_instance_id 2>/dev/null) && \
		if [ -z "$$BASTION_ID" ] || [ "$$BASTION_ID" = "null" ]; then \
			echo "$(YELLOW)Bastion not deployed$(NC)"; \
			exit 1; \
		fi && \
		VPC_CIDR=$$(terraform output -raw vpc_cidr_block 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.vpc_cidr_block.value // empty') && \
		if [ -z "$$VPC_CIDR" ]; then \
			echo "$(YELLOW)VPC CIDR not found$(NC)"; \
			exit 1; \
		fi && \
		PIDFILE="/tmp/sshuttle-$$*-$$BASTION_ID.pid" && \
		if [ -f "$$PIDFILE" ]; then \
			PID=$$(cat $$PIDFILE 2>/dev/null) && \
			if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null && pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
				echo "$(GREEN)Tunnel is running: VPC $$VPC_CIDR routed through bastion$$BASTION_ID$(NC)"; \
				ps aux | grep -E "sshuttle.*$$VPC_CIDR" | grep -v grep; \
			else \
				echo "$(YELLOW)Tunnel is not running$(NC)"; \
				rm -f $$PIDFILE; \
				exit 1; \
			fi; \
		elif pgrep -f "sshuttle.*$$VPC_CIDR" >/dev/null 2>&1; then \
			echo "$(GREEN)Tunnel is running: VPC $$VPC_CIDR routed through bastion$$BASTION_ID$(NC)"; \
			ps aux | grep -E "sshuttle.*$$VPC_CIDR" | grep -v grep; \
		else \
			echo "$(YELLOW)Tunnel is not running$(NC)"; \
			exit 1; \
		fi

bastion-connect.%:
	@echo "$(BLUE)Connecting to $* cluster bastion via SSM Session Manager...$(NC)"
	@if ! command -v aws >/dev/null 2>&1; then \
		echo "$(YELLOW)Error: aws CLI not found. Please install AWS CLI.$(NC)"; \
		exit 1; \
	fi
	@cd $(call get_cluster_dir,$*) && \
		BASTION_ID=$$(terraform output -raw bastion_instance_id 2>/dev/null) && \
		if [ -z "$$BASTION_ID" ] || [ "$$BASTION_ID" = "null" ]; then \
			echo "$(YELLOW)Error: Bastion not deployed. Enable bastion with enable_bastion=true$(NC)"; \
			exit 1; \
		fi && \
		REGION=$$(terraform output -raw region 2>/dev/null || terraform output -json 2>/dev/null | jq -r '.region.value // empty' || echo "us-east-1") && \
		if [ -z "$$REGION" ]; then \
			REGION=$$(grep -E "^region\s*=" terraform.tfvars 2>/dev/null | cut -d'"' -f2 | cut -d"'" -f2 | head -1 || echo "us-east-1"); \
		fi && \
		echo "$(GREEN)Connecting to bastion $$BASTION_ID in region $$REGION...$(NC)" && \
		aws ssm start-session --target $$BASTION_ID --region $$REGION || \
		(echo "$(YELLOW)Failed to connect. Check AWS credentials and bastion status.$(NC)" && exit 1)

# Explicit targets for backwards compatibility
tunnel-start-private: tunnel-start.private ## Start SSH tunnel for private cluster
tunnel-start-egress-zero: tunnel-start.egress-zero ## Start SSH tunnel for egress-zero cluster
tunnel-stop-private: tunnel-stop.private ## Stop SSH tunnel for private cluster
tunnel-stop-egress-zero: tunnel-stop.egress-zero ## Stop SSH tunnel for egress-zero cluster
tunnel-status-private: tunnel-status.private ## Check tunnel status for private cluster
tunnel-status-egress-zero: tunnel-status.egress-zero ## Check tunnel status for egress-zero cluster
bastion-connect-private: bastion-connect.private ## Connect to private cluster bastion
bastion-connect-egress-zero: bastion-connect.egress-zero ## Connect to egress-zero cluster bastion

# =============================================================================
# Infrastructure and Configuration Targets (New Structure)
# =============================================================================
# The new structure has:
#   clusters/examples/<cluster>/infrastructure/  - VPC, IAM, ROSA cluster
#   clusters/examples/<cluster>/configuration/   - GitOps, Loki

# Infrastructure targets
init-infra.%:
	@echo "$(BLUE)Initializing $* infrastructure...$(NC)"
	@cd $(call get_cluster_dir,$*)/infrastructure && terraform init -reconfigure

plan-infra.%: init-infra.%
	@echo "$(BLUE)Planning $* infrastructure...$(NC)"
	@cd $(call get_cluster_dir,$*)/infrastructure && terraform plan -out=terraform.tfplan

apply-infra.%: plan-infra.%
	@echo "$(YELLOW)Applying $* infrastructure...$(NC)"
	@cd $(call get_cluster_dir,$*)/infrastructure && terraform apply terraform.tfplan

destroy-infra.%:
	@echo "$(YELLOW)WARNING: This will destroy the $* infrastructure!$(NC)"
	@cd $(call get_cluster_dir,$*)/infrastructure && terraform destroy -auto-approve

# Configuration targets (requires oc login first)
# Configuration is controlled by terraform.tfvars in the configuration folder
# Example terraform.tfvars:
#   loki_enabled = true
#   gitops_repo_url = "https://github.com/your-org/your-repo.git"
init-config.%:
	@echo "$(BLUE)Initializing $* configuration...$(NC)"
	@cd $(call get_cluster_dir,$*)/configuration && terraform init -reconfigure

plan-config.%: init-config.%
	@echo "$(BLUE)Planning $* configuration...$(NC)"
	@if [ -z "$$TF_VAR_k8s_token" ]; then \
		TF_VAR_k8s_token=$$(oc whoami -t 2>/dev/null); \
		if [ -z "$$TF_VAR_k8s_token" ]; then \
			echo "$(YELLOW)Error: Not logged in. Run 'make login.$*' first$(NC)"; \
			exit 1; \
		fi; \
		export TF_VAR_k8s_token; \
	fi && \
	cd $(call get_cluster_dir,$*)/configuration && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform plan -out=terraform.tfplan

apply-config.%: init-config.%
	@echo "$(YELLOW)Applying $* configuration...$(NC)"
	@if [ -z "$$TF_VAR_k8s_token" ]; then \
		TF_VAR_k8s_token=$$(oc whoami -t 2>/dev/null); \
		if [ -z "$$TF_VAR_k8s_token" ]; then \
			echo "$(YELLOW)Error: Not logged in. Run 'make login.$*' first$(NC)"; \
			exit 1; \
		fi; \
		export TF_VAR_k8s_token; \
	fi && \
	cd $(call get_cluster_dir,$*)/configuration && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform apply -auto-approve
	@echo "$(GREEN)Configuration deployed!$(NC)"
	@echo "$(GREEN)Check status: make show-config.$*$(NC)"

destroy-config.%:
	@echo "$(YELLOW)WARNING: This will destroy the $* configuration!$(NC)"
	@if [ -z "$$TF_VAR_k8s_token" ]; then \
		TF_VAR_k8s_token=$$(oc whoami -t 2>/dev/null); \
		if [ -z "$$TF_VAR_k8s_token" ]; then \
			echo "$(YELLOW)Error: Not logged in. Run 'make login.$*' first$(NC)"; \
			exit 1; \
		fi; \
		export TF_VAR_k8s_token; \
	fi && \
	cd $(call get_cluster_dir,$*)/configuration && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform destroy -auto-approve

# Combined: Deploy full cluster (infrastructure + configuration)
deploy.%: apply-infra.%
	@echo "$(BLUE)Logging into cluster...$(NC)"
	@$(MAKE) login.$*
	@echo "$(BLUE)Deploying configuration...$(NC)"
	@$(MAKE) apply-config.$*

# Show infrastructure outputs
show-infra.%:
	@echo "$(BLUE)$* Infrastructure Outputs:$(NC)"
	@cd $(call get_cluster_dir,$*)/infrastructure && terraform output

# Show configuration outputs
show-config.%:
	@echo "$(BLUE)$* Configuration Outputs:$(NC)"
	@cd $(call get_cluster_dir,$*)/configuration && terraform output 2>/dev/null || echo "Configuration not deployed yet"

# =============================================================================
# EXISTING CLUSTER DEPLOYMENT
# =============================================================================
# For deploying GitOps and Loki to existing ROSA clusters not managed by Terraform
#
# Usage:
#   make deploy-existing CLUSTER=my-cluster
#   make destroy-existing CLUSTER=my-cluster
#
# Prerequisites:
#   1. Copy template: cp -r clusters/existing-cluster-template clusters/my-cluster
#   2. Edit clusters/my-cluster/configuration/terraform.tfvars
#   3. Login to cluster: oc login ...
#   4. Export tokens: export TF_VAR_token=$(rosa token)

# Validate CLUSTER variable is set
.PHONY: _check-cluster
_check-cluster:
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make deploy-existing CLUSTER=my-cluster)
endif
	@if [ ! -d "clusters/$(CLUSTER)/configuration" ]; then \
		echo "$(YELLOW)Error: clusters/$(CLUSTER)/configuration not found$(NC)"; \
		echo "Copy the template first: cp -r clusters/existing-cluster-template clusters/$(CLUSTER)"; \
		exit 1; \
	fi

# Deploy to existing cluster
deploy-existing: _check-cluster ## Deploy to existing ROSA cluster (requires CLUSTER=name)
	@echo "$(BLUE)Deploying configuration to existing cluster: $(CLUSTER)$(NC)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Logged into cluster: oc whoami"
	@echo "  2. OCM token: export TF_VAR_token=\$$(rosa token)"
	@echo ""
	@if [ -z "$$TF_VAR_token" ]; then \
		echo "$(YELLOW)Warning: TF_VAR_token not set. Run: export TF_VAR_token=\$$(rosa token)$(NC)"; \
		exit 1; \
	fi
	@cd clusters/$(CLUSTER)/configuration && \
		terraform init && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform apply -auto-approve
	@echo ""
	@echo "$(GREEN)Deployment complete!$(NC)"
	@echo "Check status: oc get applications -n openshift-gitops"

# Plan for existing cluster (dry run)
plan-existing: _check-cluster ## Plan deployment to existing cluster (requires CLUSTER=name)
	@echo "$(BLUE)Planning configuration for existing cluster: $(CLUSTER)$(NC)"
	@if [ -z "$$TF_VAR_token" ]; then \
		echo "$(YELLOW)Warning: TF_VAR_token not set. Run: export TF_VAR_token=\$$(rosa token)$(NC)"; \
		exit 1; \
	fi
	@cd clusters/$(CLUSTER)/configuration && \
		terraform init && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform plan

# Destroy configuration on existing cluster
destroy-existing: _check-cluster ## Remove configuration from existing cluster (requires CLUSTER=name)
	@echo "$(YELLOW)Destroying configuration on existing cluster: $(CLUSTER)$(NC)"
	@echo "This will remove GitOps, Loki, and related resources."
	@echo "Your ROSA cluster will NOT be affected."
	@echo ""
	@if [ -z "$$TF_VAR_token" ]; then \
		echo "$(YELLOW)Warning: TF_VAR_token not set. Run: export TF_VAR_token=\$$(rosa token)$(NC)"; \
		exit 1; \
	fi
	@cd clusters/$(CLUSTER)/configuration && \
		TF_VAR_k8s_token=$$(oc whoami -t) terraform destroy -auto-approve
	@echo "$(GREEN)Configuration removed$(NC)"

# Show outputs for existing cluster
show-existing: _check-cluster ## Show outputs for existing cluster (requires CLUSTER=name)
	@echo "$(BLUE)Outputs for existing cluster: $(CLUSTER)$(NC)"
	@cd clusters/$(CLUSTER)/configuration && terraform output 2>/dev/null || echo "Configuration not deployed yet"

# Create new cluster directory from template
new-cluster: ## Create new cluster config from template (requires CLUSTER=name)
ifndef CLUSTER
	$(error CLUSTER is not set. Usage: make new-cluster CLUSTER=my-cluster)
endif
	@if [ -d "clusters/$(CLUSTER)" ]; then \
		echo "$(YELLOW)Error: clusters/$(CLUSTER) already exists$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Creating new cluster configuration: $(CLUSTER)$(NC)"
	@cp -r clusters/existing-cluster-template clusters/$(CLUSTER)
	@cp clusters/$(CLUSTER)/configuration/terraform.tfvars.example clusters/$(CLUSTER)/configuration/terraform.tfvars
	@echo ""
	@echo "$(GREEN)Created: clusters/$(CLUSTER)$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit clusters/$(CLUSTER)/configuration/terraform.tfvars"
	@echo "  2. Login to your cluster: oc login ..."
	@echo "  3. Export tokens: export TF_VAR_token=\$$(rosa token)"
	@echo "  4. Deploy: make deploy-existing CLUSTER=$(CLUSTER)"
	@echo ""
	@echo "See clusters/$(CLUSTER)/README.md for detailed instructions."

# =============================================================================

# Cleanup
clean: ## Clean Terraform files (.terraform directories and lock files)
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"
