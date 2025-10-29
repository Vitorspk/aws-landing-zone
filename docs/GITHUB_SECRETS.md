# GitHub Secrets Configuration Guide

## Required GitHub Secrets

Para usar os GitHub Actions workflows, você precisa configurar estes secrets no seu repositório:

### 1. AWS_ACCESS_KEY_ID
- **Tipo**: AWS Access Key ID
- **Descrição**: Credencial para autenticação na AWS
- **Exemplo**: `AKIAIOSFODNN7EXAMPLE`

### 2. AWS_SECRET_ACCESS_KEY
- **Tipo**: AWS Secret Access Key
- **Descrição**: Chave secreta correspondente à Access Key
- **Exemplo**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

---

## Como Configurar

### Passo 1: Criar IAM User para GitHub Actions

```bash
# Criar usuário
aws iam create-user --user-name github-actions-terraform

# Criar access key
aws iam create-access-key --user-name github-actions-terraform
```

**⚠️ IMPORTANTE**: Salve o output imediatamente! O Secret Access Key não pode ser recuperado depois.

Output exemplo:
```json
{
    "AccessKey": {
        "UserName": "github-actions-terraform",
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "Status": "Active",
        "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        "CreateDate": "2025-10-26T..."
    }
}
```

### Passo 2: Anexar Permissões ao Usuário

#### Opção 1: Policy Gerenciada (Mais Permissiva - Não Recomendada para Produção)

```bash
aws iam attach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

#### Opção 2: Policy Customizada (Recomendada)

Crie uma policy com permissões mínimas necessárias:

```bash
# Criar arquivo de policy
cat > github-actions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateManagement",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::vschiavo-home-terraform-state",
        "arn:aws:s3:::vschiavo-home-terraform-state/*"
      ]
    },
    {
      "Sid": "DynamoDBStateLock",
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:sa-east-1:*:table/terraform-state-lock"
    },
    {
      "Sid": "EKSManagement",
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2NetworkManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:CreateVpcEndpoint",
        "ec2:DeleteVpcEndpoint",
        "ec2:ModifyVpcEndpoint",
        "ec2:CreateFlowLogs",
        "ec2:DeleteFlowLogs"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicyVersions",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:TagPolicy",
        "iam:UntagPolicy",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScalingManagement",
      "Effect": "Allow",
      "Action": [
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:DeleteLaunchConfiguration",
        "autoscaling:Describe*",
        "autoscaling:CreateOrUpdateTags",
        "autoscaling:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LoadBalancerManagement",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchManagement",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSManagement",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:ListResourceTags",
        "kms:ScheduleKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "STSGetCallerIdentity",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Criar a policy
aws iam create-policy \
  --policy-name GitHubActionsTerraformPolicy \
  --policy-document file://github-actions-policy.json

# Anexar ao usuário
aws iam attach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/GitHubActionsTerraformPolicy
```

### Passo 3: Adicionar Secrets no GitHub

#### Via GitHub Web UI:

1. Acesse seu repositório no GitHub
2. Vá em **Settings** → **Secrets and variables** → **Actions**
3. Clique em **"New repository secret"**
4. Adicione os secrets:

   **Secret 1:**
   - Name: `AWS_ACCESS_KEY_ID`
   - Secret: `<seu-access-key-id>`
   
   **Secret 2:**
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Secret: `<seu-secret-access-key>`

#### Via GitHub CLI (gh):

```bash
# Instalar GitHub CLI
brew install gh  # macOS
# ou
sudo apt install gh  # Linux

# Autenticar
gh auth login

# Adicionar secrets
gh secret set AWS_ACCESS_KEY_ID
# Cole o Access Key ID quando solicitado

gh secret set AWS_SECRET_ACCESS_KEY
# Cole o Secret Access Key quando solicitado
```

---

## Verificar Configuração

### Testar Credenciais Localmente

```bash
# Exportar as credenciais
export AWS_ACCESS_KEY_ID="sua-access-key"
export AWS_SECRET_ACCESS_KEY="sua-secret-key"
export AWS_DEFAULT_REGION="sa-east-1"

# Testar
aws sts get-caller-identity
```

Output esperado:
```json
{
    "UserId": "AIDAIOSFODNN7EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/github-actions-terraform"
}
```

### Testar GitHub Actions

1. Faça um commit e push
2. Vá em **Actions** no GitHub
3. Verifique se o workflow executa sem erros de autenticação

---

## Segurança - Melhores Práticas

### ✅ Recomendações

1. **Use policy com permissões mínimas** (opção 2 acima)
2. **Rotacione as credenciais regularmente** (a cada 90 dias)
3. **Não compartilhe as credenciais**
4. **Use secrets do GitHub** (nunca comite no código)
5. **Habilite MFA no IAM user** (quando possível)
6. **Monitore uso com CloudTrail**

### 🔄 Rotação de Credenciais

```bash
# Criar nova access key
aws iam create-access-key --user-name github-actions-terraform

# Atualizar secrets no GitHub
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY

# Testar a nova key

# Deletar a antiga
aws iam delete-access-key \
  --user-name github-actions-terraform \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

### 🚨 Revogar Acesso em Caso de Comprometimento

```bash
# Listar access keys
aws iam list-access-keys --user-name github-actions-terraform

# Desativar imediatamente
aws iam update-access-key \
  --user-name github-actions-terraform \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive

# Deletar permanentemente
aws iam delete-access-key \
  --user-name github-actions-terraform \
  --access-key-id AKIAIOSFODNN7EXAMPLE
```

---

## Secrets Opcionais (Para Uso Futuro)

Você pode adicionar estes secrets posteriormente:

### Para Slack Notifications
- `SLACK_WEBHOOK_URL`: Para notificações de deploy

### Para Ambientes Específicos
- `AWS_ACCOUNT_ID`: ID da conta AWS (útil para alguns recursos)
- `TF_VAR_project_name`: Variável customizada do Terraform

### Para Kubernetes
- `KUBE_CONFIG_DATA`: Kubeconfig em base64 (para deploy de aplicações)

---

## Troubleshooting

### Erro: "AccessDenied"
**Solução**: Verifique se o IAM user tem as permissões necessárias

```bash
# Verificar policies anexadas
aws iam list-attached-user-policies --user-name github-actions-terraform
```

### Erro: "InvalidAccessKeyId"
**Solução**: Verifique se copiou corretamente o Access Key ID

### Erro: "SignatureDoesNotMatch"
**Solução**: Verifique se copiou corretamente o Secret Access Key

---

## Limpeza

Para remover o IAM user:

```bash
# Deletar access keys
aws iam delete-access-key \
  --user-name github-actions-terraform \
  --access-key-id <ACCESS_KEY_ID>

# Desanexar policies
aws iam detach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/GitHubActionsTerraformPolicy

# Deletar policy
aws iam delete-policy \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/GitHubActionsTerraformPolicy

# Deletar usuário
aws iam delete-user --user-name github-actions-terraform
```

---

## Resumo

**Secrets Obrigatórios:**
- ✅ `AWS_ACCESS_KEY_ID`
- ✅ `AWS_SECRET_ACCESS_KEY`

**Criação:**
1. Criar IAM user
2. Gerar access key
3. Anexar permissões
4. Adicionar secrets no GitHub

**Pronto!** 🎉 Seus GitHub Actions workflows agora podem fazer deploy na AWS!
