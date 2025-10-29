# 🔍 ANÁLISE COMPLETA DO PROJETO AWS LANDING ZONE

## Data da Análise
**29 de Outubro de 2025**

---

## 📊 PROBLEMAS IDENTIFICADOS

### 1. **PROBLEMA PRINCIPAL: CloudWatch Log Groups sendo criados pelo EKS automaticamente**

**Causa Raiz:**
- O EKS cria automaticamente o CloudWatch Log Group quando o cluster é criado
- O Terraform tenta criar o mesmo log group DEPOIS que o cluster já foi criado
- Resultado: `ResourceAlreadyExistsException`

**Arquivos afetados:**
- `terraform/02-kubernetes/modules/eks-cluster/main.tf` (linha 270)

**Status:** ✅ CORRIGIDO
- Log group movido para ANTES da criação do cluster
- Adicionado `depends_on` no cluster para garantir ordem

---

### 2. **PROBLEMA: Kubernetes Jobs de Admission já existem**

**Causa Raiz:**
- NGINX Ingress cria jobs de admission hook
- Em re-deploys, os jobs já existem e não são removidos
- `kubectl apply` falha com `AlreadyExists`

**Arquivos afetados:**
- `scripts/deploy-ingress-controllers.sh`
- Jobs: `ingress-nginx-admission-create`, `ingress-nginx-admission-patch`

**Status:** ✅ CORRIGIDO
- Adicionado step 3.5 no script para deletar jobs antes do apply
- Usa `kubectl delete job --all` com `--ignore-not-found`

---

### 3. **PROBLEMA: Cleanup steps não executam no workflow**

**Causa Raiz:**
- Cleanup steps foram adicionados mas não commitados ou não estão na branch master
- GitHub Actions usa versão cached do workflow

**Arquivos afetados:**
- `.github/workflows/deploy-full-infrastructure.yml`

**Status:** ✅ CORRIGIDO
- Cleanup de log groups adicionado na Phase 1 (Networking)
- Cleanup de log groups adicionado na Phase 2 (Kubernetes)

---

### 4. **PROBLEMA: Condição do skip_iam_networking incorreta**

**Causa Raiz:**
- Comparação `== false` não funciona com string "false" do workflow_dispatch
- Phases eram sempre puladas

**Status:** ✅ CORRIGIDO
- Mudado de `== false` para `!= 'true'`

---

### 5. **PROBLEMA: Região do bucket S3 não corresponde**

**Causa Raiz:**
- Bucket criado em `sa-east-1` mas código tentava usar `us-east-1`
- Erro: "requested bucket from us-east-1, actual location sa-east-1"

**Status:** ✅ CORRIGIDO
- Região passada via `-backend-config="region=$AWS_DEFAULT_REGION"`
- GitHub Secret deve estar configurado com `sa-east-1`

---

### 6. **PROBLEMA: null_resource com timestamp() sempre recria**

**Causa Raiz:**
- `always_run = timestamp()` no triggers força recriação a cada run
- Ingress controllers são re-deployados desnecessariamente

**Arquivos afetados:**
- `terraform/02-kubernetes/main.tf` (linhas 215, 231, 247, 263)

**Status:** ⚠️ DESIGN ATUAL (pode ser otimizado)
- Podemos remover `timestamp()` se quiser deploy apenas quando cluster mudar

---

## 🎯 CORREÇÕES APLICADAS

### Arquivo 1: `.github/workflows/deploy-full-infrastructure.yml`

```yaml
# ADICIONADO: Cleanup step na Phase 1 (Networking)
- name: Cleanup Existing Resources (if any)
  run: |
    LOG_GROUP="/aws/vpc/shared-vpc/flow-logs"
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region $REGION || true

# ADICIONADO: Cleanup step na Phase 2 (Kubernetes)  
- name: Cleanup Existing EKS Log Groups (if any)
  run: |
    for LOG_GROUP in /aws/eks/eks-{dev,stg,prd,sdx}/cluster; do
      aws logs delete-log-group --log-group-name "$LOG_GROUP" --region $REGION || true
    done

# CORRIGIDO: Condição do skip
if: github.event.inputs.skip_iam_networking != 'true'  # Era: == false
```

---

### Arquivo 2: `terraform/02-kubernetes/modules/eks-cluster/main.tf`

```hcl
# MOVIDO: CloudWatch log group para ANTES do cluster
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days
  # ...
}

resource "aws_eks_cluster" "main" {
  # ...
  depends_on = [
    var.cluster_role_arn,
    aws_cloudwatch_log_group.cluster  # ← ADICIONADO
  ]
}
```

---

### Arquivo 3: `scripts/deploy-ingress-controllers.sh`

```bash
# ADICIONADO: Step 3.5 - Cleanup de jobs
echo "3.5. Cleaning up existing admission jobs..."
kubectl delete job ingress-nginx-admission-create -n ingress-nginx --ignore-not-found=true || true
kubectl delete job ingress-nginx-admission-patch -n ingress-nginx --ignore-not-found=true || true
kubectl delete job ingress-nginx-internal-admission-create -n ingress-nginx-internal --ignore-not-found=true || true
kubectl delete job ingress-nginx-internal-admission-patch -n ingress-nginx-internal --ignore-not-found=true || true
```

---

### Arquivo 4: `terraform/01-networking/main.tf`

```hcl
# ADICIONADO: Lifecycle no flow logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  # ...
  lifecycle {
    ignore_changes = [name]
  }
}
```

---

## 🚀 SOLUÇÃO FINAL RECOMENDADA

Como você tem recursos parcialmente criados, a melhor abordagem é **DESTROY e RECREATE**:

### Script de Limpeza Completa

Vou criar um script que faz tudo automaticamente:

