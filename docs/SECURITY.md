# Security Best Practices

This document outlines security best practices for deploying and managing the AWS Landing Zone infrastructure.

## 🔐 Credential Management

### Never Commit Sensitive Data

**NEVER commit these files to version control:**

- `*.tfvars` - Terraform variable files with real values
- `*.env` - Environment variable files
- `*.pem` - SSH private keys
- `*.key` - Private keys
- `.aws/` - AWS credentials directory
- `*-policy.json` - Custom IAM policies (except in docs/)
- `.terraform/` - Terraform working directory
- `*.tfstate` - Terraform state files (use remote backend)

### Use GitHub Secrets

For CI/CD pipelines, always use GitHub Secrets:

1. **Required Secrets:**
   - `AWS_ACCESS_KEY_ID` - AWS access key with appropriate permissions
   - `AWS_SECRET_ACCESS_KEY` - AWS secret access key
   - `AWS_DEFAULT_REGION` - Default AWS region (optional)

2. **How to add secrets:**
   ```
   Repository → Settings → Secrets and variables → Actions → New repository secret
   ```

3. **Reference secrets in workflows:**
   ```yaml
   - name: Configure AWS credentials
     uses: aws-actions/configure-aws-credentials@v4
     with:
       aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
       aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
       aws-region: ${{ env.AWS_REGION }}
   ```

### IAM User Security

**Recommended IAM User Setup:**

1. **Create a dedicated deployment user:**
   ```bash
   aws iam create-user --user-name terraform-deployer
   ```

2. **Grant minimum required permissions:**
   ```bash
   # Attach managed policies
   aws iam attach-user-policy \
     --user-name terraform-deployer \
     --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
   
   # Or create custom policy with least privilege
   ```

3. **Create access keys:**
   ```bash
   aws iam create-access-key --user-name terraform-deployer
   ```

4. **Store keys in GitHub Secrets** (never commit to repo!)

5. **Enable MFA for IAM user** (recommended)

6. **Rotate keys regularly** (every 90 days recommended)

## 🛡️ Terraform Security

### Remote State Storage

**Always use remote state storage:**

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "aws-landing-zone/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    region         = "your-region"
  }
}
```

**Benefits:**
- State is not in version control
- Encrypted at rest in S3
- Supports state locking via DynamoDB
- Team collaboration
- Versioning enabled for rollback

### Variable Files

**Use terraform.tfvars.example as template:**

1. Copy example file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit with your values:
   ```hcl
   region = "sa-east-1"
   deploy_clusters = "dev,stg"
   ```

3. **NEVER commit terraform.tfvars!**

### Sensitive Variables

For sensitive values, use Terraform's `sensitive` attribute:

```hcl
variable "database_password" {
  type      = string
  sensitive = true
}
```

## 🔍 Pre-Deployment Checklist

Before running `terraform apply`, verify:

- [ ] `.gitignore` includes `*.tfvars`, `*.env`, `.terraform/`, `.aws/`
- [ ] No `.tfstate` files in repository
- [ ] Access keys stored securely (GitHub Secrets or AWS Secrets Manager)
- [ ] Remote backend configured for state storage
- [ ] IAM permissions follow least privilege principle
- [ ] All sensitive variables marked as `sensitive = true`
- [ ] `terraform.tfvars` not committed to Git
- [ ] MFA enabled on IAM user/role

## 🚨 Incident Response

### If Credentials Are Accidentally Committed:

1. **Immediately rotate the compromised credentials:**
   ```bash
   # Deactivate old access key
   aws iam update-access-key \
     --access-key-id AKIAIOSFODNN7EXAMPLE \
     --status Inactive \
     --user-name terraform-deployer
   
   # Delete old access key
   aws iam delete-access-key \
     --access-key-id AKIAIOSFODNN7EXAMPLE \
     --user-name terraform-deployer
   
   # Create new access key
   aws iam create-access-key --user-name terraform-deployer
   ```

2. **Remove from Git history:**
   ```bash
   # Use git-filter-repo or BFG Repo-Cleaner
   git filter-repo --path path/to/secret/file --invert-paths
   ```

3. **Update GitHub Secrets with new credentials**

4. **Review CloudTrail logs for unauthorized usage:**
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=Username,AttributeValue=terraform-deployer \
     --max-results 50
   ```

5. **Check for any unauthorized resources:**
   ```bash
   aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime]'
   ```

## 🔒 Network Security

### EKS Cluster Network Access

- Worker nodes run in private subnets.
- The API endpoint's public access is **enabled by default** (`public_access_cidrs = ["0.0.0.0/0"]`) so `deploy-ingress-nginx.yml` can reach the cluster from GitHub-hosted runners. This is configurable via the `eks-cluster` module's `public_access_cidrs` variable — restrict it to a specific CIDR if you have a stable IP or VPN, but note that doing so will break the current CI-based ingress deployment unless you also add a self-hosted runner inside the VPC.
- No direct internet access (via NAT Gateway)
- VPC Endpoints for AWS services

### Security Groups

Review security groups before deployment:

```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query 'SecurityGroups[*].[GroupId,GroupName]'

# Audit specific security group
aws ec2 describe-security-groups \
  --group-ids <SG_ID>
```

### Network ACLs

Review NACLs for additional security:

```bash
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

## 📋 Compliance

### AWS CloudTrail

Enable CloudTrail for audit logging:

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "aws-landing-zone-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  enable_logging                = true
  include_global_service_events = true
  is_multi_region_trail         = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

### AWS Config

Enable AWS Config for compliance monitoring:

```bash
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=<CONFIG_ROLE_ARN> \
  --recording-group allSupported=true,includeGlobalResourceTypes=true
```

### Regular Security Reviews

Perform security reviews:

1. **Monthly:** Review IAM permissions and access keys
2. **Quarterly:** Rotate access keys and certificates
3. **Annually:** Full security audit and penetration testing

## 🔗 Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Terraform Security Guidelines](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)

## 📞 Reporting Security Issues

If you discover a security vulnerability, please:

1. **DO NOT** open a public issue
2. Email the maintainer directly
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be fixed before public disclosure

---

**Remember:** Security is everyone's responsibility. When in doubt, ask before committing!
