# 🔐 SSL/TLS Certificate Setup Guide

Este guia fornece um passo a passo completo para configurar certificados SSL/TLS no AWS Certificate Manager (ACM) e habilitá-los nos NGINX Ingress Controllers.

---

## 📋 **PRÉ-REQUISITOS**

- ✅ Domínio registrado (ex: `seudominio.com`)
- ✅ Acesso ao DNS do domínio (Route 53, Cloudflare, etc.)
- ✅ AWS CLI configurado com permissões para ACM
- ✅ NGINX Ingress Controllers já instalados e funcionando

---

## 📚 **ÍNDICE**

1. [Criar Certificado no ACM](#1-criar-certificado-no-acm)
2. [Validar Certificado via DNS](#2-validar-certificado-via-dns)
3. [Habilitar SSL no Ingress Controller](#3-habilitar-ssl-no-ingress-controller)
4. [Configurar DNS para o LoadBalancer](#4-configurar-dns-para-o-loadbalancer)
5. [Testar HTTPS](#5-testar-https)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. CRIAR CERTIFICADO NO ACM

### **Opção A: Via AWS CLI (Recomendado)**

```bash
# Definir variáveis
DOMAIN="seudominio.com"
REGION="sa-east-1"

# Solicitar certificado com wildcard
aws acm request-certificate \
  --domain-name "$DOMAIN" \
  --subject-alternative-names "*.$DOMAIN" \
  --validation-method DNS \
  --region $REGION \
  --tags Key=Name,Value="$DOMAIN-wildcard" \
         Key=Environment,Value=production \
         Key=ManagedBy,Value=Terraform

# Salvar o ARN retornado
```

**Exemplo de output:**
```json
{
    "CertificateArn": "arn:aws:acm:sa-east-1:123456789012:certificate/abcd1234-5678-90ab-cdef-1234567890ab"
}
```

**💾 IMPORTANTE: Salve este ARN! Você vai precisar dele.**

---

### **Opção B: Via AWS Console**

1. Acesse: **AWS Console** → **Certificate Manager** → **Request certificate**
2. Escolha: **Request a public certificate**
3. **Domain names**:
   - Primary: `seudominio.com`
   - Add: `*.seudominio.com` (wildcard para subdomínios)
4. **Validation method**: DNS validation (recomendado)
5. **Key algorithm**: RSA 2048 (padrão)
6. **Tags** (opcional):
   ```
   Name: seudominio.com-wildcard
   Environment: production
   ManagedBy: Manual
   ```
7. Clique em **Request**
8. **Copie o ARN** do certificado criado

---

## 2. VALIDAR CERTIFICADO VIA DNS

### **Passo 1: Obter registros de validação DNS**

```bash
# Listar certificados pendentes
aws acm list-certificates \
  --region sa-east-1 \
  --certificate-statuses PENDING_VALIDATION

# Obter detalhes do certificado (use o ARN obtido no passo 1)
CERT_ARN="arn:aws:acm:sa-east-1:123456789012:certificate/abcd1234-..."

aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region sa-east-1 \
  --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.Name,ResourceRecord.Value]' \
  --output table
```

**Exemplo de output:**
```
---------------------------------------------------------
|              DescribeCertificate                      |
+-------------------+-----------------------------------+
|  seudominio.com   | _abc123.seudominio.com           |
|                   | _xyz789.acm-validations.aws.     |
+-------------------+-----------------------------------+
```

---

### **Passo 2: Adicionar registros CNAME no DNS**

#### **Se usar Route 53:**

```bash
# Criar registro de validação automaticamente
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region sa-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
  --output json > /tmp/validation-record.json

# Obter Hosted Zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='seudominio.com.'].Id" \
  --output text | cut -d'/' -f3)

# Criar registro CNAME
RECORD_NAME=$(jq -r '.Name' /tmp/validation-record.json)
RECORD_VALUE=$(jq -r '.Value' /tmp/validation-record.json)

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"$RECORD_NAME\",
        \"Type\": \"CNAME\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$RECORD_VALUE\"}]
      }
    }]
  }"
```

#### **Se usar outro provedor DNS (Cloudflare, GoDaddy, etc):**

1. Acesse o painel do seu provedor DNS
2. Adicione um registro **CNAME** com:
   - **Name**: `_abc123.seudominio.com` (obtido no passo anterior)
   - **Value**: `_xyz789.acm-validations.aws.` (obtido no passo anterior)
   - **TTL**: 300 (5 minutos)
3. Salve o registro

---

### **Passo 3: Aguardar validação (5-30 minutos)**

```bash
# Monitorar status do certificado
watch -n 30 "aws acm describe-certificate \
  --certificate-arn '$CERT_ARN' \
  --region sa-east-1 \
  --query 'Certificate.Status' \
  --output text"

# Aguarde até mostrar: ISSUED
```

**Ou via Console:**
- AWS Console → Certificate Manager → Seu certificado
- Status deve mudar de `Pending validation` → `Issued`

---

## 3. HABILITAR SSL NO INGRESS CONTROLLER

### **Passo 1: Atualizar o ARN do certificado nos manifests**

#### **Para External Ingress:**

Edite: `manifests/eks-ingress-nginx-1.13.3-external.yaml`

Localize a seção do Service (linha ~363) e **descomente** as linhas de SSL:

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "false"
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # DESCOMENTE E ATUALIZE O ARN:
    service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS13-1-2-2021-06"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:sa-east-1:123456789012:certificate/SEU-CERTIFICADO-ARN-AQUI
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: https
    service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
```

**⚠️ IMPORTANTE**: Substitua `SEU-CERTIFICADO-ARN-AQUI` pelo ARN obtido no Passo 1!

---

#### **Para Internal Ingress:**

Edite: `manifests/eks-ingress-nginx-1.13.3-internal.yaml`

Faça o mesmo processo (linha ~372), descomentando e atualizando o ARN.

---

### **Passo 2: Aplicar as alterações**

```bash
# 1. Deletar o Service atual
kubectl delete svc -n ingress-nginx-external ingress-nginx-controller

# 2. Reaplicar o manifest com SSL habilitado
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml

# 3. Aguardar LoadBalancer ser recriado com SSL (2-5 minutos)
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -w

# Aguarde até ver o EXTERNAL-IP aparecer
```

---

### **Passo 3: Verificar configuração do LoadBalancer**

```bash
# Ver detalhes do Service
kubectl describe svc -n ingress-nginx-external ingress-nginx-controller

# Procurar por:
# - Annotations com aws-load-balancer-ssl-cert
# - LoadBalancer Ingress com hostname
# - Events sem erros
```

**✅ Se NÃO houver erros de certificado nos Events, está correto!**

---

## 4. CONFIGURAR DNS PARA O LOADBALANCER

### **Passo 1: Obter hostname do LoadBalancer**

```bash
LB_HOST=$(kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "LoadBalancer hostname: $LB_HOST"
```

---

### **Passo 2: Criar registro DNS apontando para o LoadBalancer**

#### **Se usar Route 53:**

```bash
# Definir variáveis
DOMAIN="seudominio.com"
HOSTED_ZONE_ID="Z1234567890ABC"  # Seu Hosted Zone ID

# Criar registro A (Alias) para o domínio principal
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"$DOMAIN\",
        \"Type\": \"A\",
        \"AliasTarget\": {
          \"HostedZoneId\": \"Z2P70J7HTTTPLU\",
          \"DNSName\": \"$LB_HOST\",
          \"EvaluateTargetHealth\": true
        }
      }
    }]
  }"

# Criar registro A (Alias) para wildcard (*.seudominio.com)
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"CREATE\",
      \"ResourceRecordSet\": {
        \"Name\": \"*.$DOMAIN\",
        \"Type\": \"A\",
        \"AliasTarget\": {
          \"HostedZoneId\": \"Z2P70J7HTTTPLU\",
          \"DNSName\": \"$LB_HOST\",
          \"EvaluateTargetHealth\": true
        }
      }
    }]
  }"
```

**Nota**: `Z2P70J7HTTTPLU` é o Hosted Zone ID padrão para NLBs em **sa-east-1**. 
Para outras regiões, consulte: https://docs.aws.amazon.com/general/latest/gr/elb.html

---

#### **Se usar outro provedor DNS:**

Adicione os seguintes registros:

**Registro 1: Domínio principal**
- **Type**: CNAME (ou A se suportar ALIAS)
- **Name**: `@` ou `seudominio.com`
- **Value**: `a918bfd71159243318c86ea99f0a83ab-eca4afc84c4a9c26.elb.sa-east-1.amazonaws.com`
- **TTL**: 300 (5 minutos)

**Registro 2: Wildcard (opcional)**
- **Type**: CNAME
- **Name**: `*` ou `*.seudominio.com`
- **Value**: `a918bfd71159243318c86ea99f0a83ab-eca4afc84c4a9c26.elb.sa-east-1.amazonaws.com`
- **TTL**: 300

---

### **Passo 3: Verificar propagação DNS**

```bash
# Testar resolução DNS
nslookup seudominio.com

# Deve retornar os IPs do LoadBalancer
# Name:    seudominio.com
# Address: 52.67.89.178
# Address: 52.67.180.4

# Aguardar propagação (pode levar 5-60 minutos dependendo do TTL)
```

---

## 5. TESTAR HTTPS

### **Passo 1: Criar um Ingress com seu domínio**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: default
  annotations:
    # Force HTTPS redirect (opcional)
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # Backend protocol
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx  # Para external (público)
  # ingressClassName: nginx-internal  # Para internal (privado)
  rules:
  - host: app.seudominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
  # Opcional: Configurar TLS (para HTTPS dentro do cluster)
  # tls:
  # - hosts:
  #   - app.seudominio.com
  #   secretName: meu-tls-secret
```

---

### **Passo 2: Aplicar o Ingress**

```bash
kubectl apply -f meu-ingress.yaml
```

---

### **Passo 3: Verificar configuração**

```bash
# Ver detalhes do Ingress
kubectl describe ingress minha-app -n default

# Verificar ADDRESS foi populado
kubectl get ingress minha-app -n default
```

---

### **Passo 4: Testar HTTPS**

```bash
# Testar HTTP (deve redirecionar para HTTPS se force-ssl-redirect estiver habilitado)
curl -I http://app.seudominio.com

# Testar HTTPS
curl -I https://app.seudominio.com

# Teste completo com verbose
curl -v https://app.seudominio.com

# Deve retornar:
# - Status 200 OK
# - Certificado SSL válido
# - Conteúdo da sua aplicação
```

---

## 6. TROUBLESHOOTING

### **Problema 1: Certificado ainda mostra "Pending Validation"**

**Causa**: Registros DNS de validação não foram criados ou estão incorretos.

**Solução**:
```bash
# Verificar status
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region sa-east-1 \
  --query 'Certificate.DomainValidationOptions'

# Confirmar que os registros CNAME foram criados no DNS
nslookup _abc123.seudominio.com

# Se não retornar resultado, recrie os registros DNS
```

---

### **Problema 2: LoadBalancer com erro "UnsupportedCertificate"**

**Erro**:
```
Error creating load balancer listener: UnsupportedCertificate: 
The certificate must have a fully-qualified domain name
```

**Causa**: Certificado não está em estado "Issued" ou ARN está errado.

**Solução**:
```bash
# Verificar status do certificado
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region sa-east-1 \
  --query 'Certificate.Status' \
  --output text

# Deve retornar: ISSUED

# Se retornar PENDING_VALIDATION, volte ao Passo 2
# Se retornar EXPIRED, renove o certificado
# Se retornar FAILED, crie um novo certificado
```

---

### **Problema 3: HTTPS retorna erro de certificado no browser**

**Causa**: Certificado não cobre o domínio acessado.

**Solução**:
```bash
# Verificar domínios cobertos pelo certificado
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region sa-east-1 \
  --query 'Certificate.[DomainName,SubjectAlternativeNames]'

# Certifique-se que o domínio que você está acessando está na lista
# Exemplo: se acessar app.seudominio.com, precisa ter *.seudominio.com
```

---

### **Problema 4: LoadBalancer não provisiona após habilitar SSL**

**Eventos mostram erro de certificado**

**Solução**:
```bash
# 1. Verificar se o certificado está na mesma região do cluster
aws acm list-certificates --region sa-east-1

# 2. Verificar se o ARN está correto no manifest
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -o yaml | grep ssl-cert

# 3. Se o ARN estiver errado, corrigir e reaplicar
kubectl delete svc -n ingress-nginx-external ingress-nginx-controller
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml
```

---

### **Problema 5: DNS não resolve para o LoadBalancer**

**Causa**: Registros DNS não foram criados ou TTL ainda não expirou.

**Solução**:
```bash
# Testar resolução
dig seudominio.com
nslookup seudominio.com

# Verificar se aponta para o LoadBalancer
# Se não, verificar registros no DNS provider

# Aguardar propagação (depende do TTL anterior)
# TTL 300 = 5 minutos
# TTL 3600 = 1 hora
```

---

## 📚 **REFERÊNCIAS E BOAS PRÁTICAS**

### **ACM Certificate Best Practices:**

1. **Use wildcards**: `*.seudominio.com` cobre todos os subdomínios
2. **Validação DNS**: Mais rápida que validação por email
3. **Renovação automática**: ACM renova automaticamente antes de expirar
4. **Multi-region**: Crie certificados em cada região onde usar
5. **Tags**: Sempre adicione tags para organização

---

### **Políticas SSL Recomendadas:**

| Política | Segurança | Compatibilidade | Recomendação |
|----------|-----------|-----------------|--------------|
| `ELBSecurityPolicy-TLS13-1-2-2021-06` | Alta | Moderna | ✅ **Produção** |
| `ELBSecurityPolicy-2016-08` | Média | Alta | Dev/Test |
| `ELBSecurityPolicy-FS-1-2-Res-2020-10` | Alta | Média | Compliance |

**Configurado**: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2 e 1.3 apenas)

---

### **Custo do Certificado:**

- ✅ **ACM Certificates**: **GRÁTIS** (sem custo)
- ✅ **Renovação automática**: **GRÁTIS**
- ⚠️ **LoadBalancer**: Continua custando (~$18-25/mês por NLB)
- ⚠️ **Data Transfer**: Cobrado por GB transferido

---

## 🔐 **EXEMPLO COMPLETO: Do Zero ao HTTPS**

```bash
#!/bin/bash

# ==============================================================================
# COMPLETE SSL SETUP - EXAMPLE
# ==============================================================================

DOMAIN="meuapp.com"
REGION="sa-east-1"

echo "Step 1: Request certificate..."
CERT_ARN=$(aws acm request-certificate \
  --domain-name "$DOMAIN" \
  --subject-alternative-names "*.$DOMAIN" \
  --validation-method DNS \
  --region $REGION \
  --query 'CertificateArn' \
  --output text)

echo "Certificate ARN: $CERT_ARN"

echo ""
echo "Step 2: Get validation records..."
aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region $REGION \
  --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.{Name:Name,Value:Value}]' \
  --output table

echo ""
echo "Step 3: Add the CNAME records above to your DNS provider"
echo "Press ENTER when done..."
read

echo ""
echo "Step 4: Wait for validation..."
while true; do
  STATUS=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region $REGION \
    --query 'Certificate.Status' \
    --output text)
  
  echo "Status: $STATUS"
  
  if [ "$STATUS" == "ISSUED" ]; then
    echo "✅ Certificate validated!"
    break
  fi
  
  sleep 30
done

echo ""
echo "Step 5: Update manifests with certificate ARN..."
echo "Edit manifests/eks-ingress-nginx-1.13.3-external.yaml"
echo "Replace certificate ARN with: $CERT_ARN"
echo ""
echo "Step 6: Apply updated manifest..."
echo "  kubectl delete svc -n ingress-nginx-external ingress-nginx-controller"
echo "  kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml"
echo ""
echo "Step 7: Configure DNS to point to LoadBalancer"
echo "  (Will show LoadBalancer hostname after Service is recreated)"
```

---

## 📋 **CHECKLIST DE ATIVAÇÃO**

Use este checklist ao habilitar SSL:

- [ ] Domínio registrado e acessível
- [ ] Acesso ao DNS do domínio
- [ ] Certificado ACM solicitado
- [ ] Registros DNS de validação criados
- [ ] Certificado em estado "Issued"
- [ ] ARN do certificado copiado
- [ ] Manifests atualizados com o ARN correto
- [ ] Annotations SSL descomentadas
- [ ] Service deletado e recriado
- [ ] LoadBalancer provisionado sem erros
- [ ] DNS configurado para apontar ao LoadBalancer
- [ ] DNS propagado (resolvendo corretamente)
- [ ] HTTPS testado e funcionando
- [ ] Redirect HTTP → HTTPS configurado (opcional)
- [ ] Certificado validado no browser (sem warnings)

---

## 🎯 **COMANDOS RÁPIDOS DE REFERÊNCIA**

```bash
# Listar certificados
aws acm list-certificates --region sa-east-1

# Ver detalhes de um certificado
aws acm describe-certificate --certificate-arn "ARN" --region sa-east-1

# Verificar status do LoadBalancer
kubectl get svc -n ingress-nginx-external ingress-nginx-controller

# Ver eventos do Service
kubectl describe svc -n ingress-nginx-external ingress-nginx-controller | tail -50

# Testar HTTPS
curl -I https://seudominio.com

# Verificar certificado
echo | openssl s_client -connect seudominio.com:443 -servername seudominio.com 2>/dev/null | openssl x509 -noout -text | grep -A 5 "Subject:"
```

---

## 💡 **DICAS IMPORTANTES**

1. **Sempre use DNS validation** (mais rápido que email)
2. **Wildcard certificates** são mais flexíveis (`*.seudominio.com`)
3. **Teste em staging primeiro** antes de produção
4. **Monitore expiração** (ACM renova automaticamente, mas verifique)
5. **Use HTTPS redirect** para forçar tráfego seguro
6. **Não commite ARNs** de certificado no Git (use secrets)
7. **Documente qual certificado** é usado em cada ambiente

---

## 🔄 **ROLLBACK (Se necessário)**

Se precisar remover SSL e voltar para HTTP apenas:

```bash
# 1. Editar manifest e comentar as linhas de SSL novamente
# 2. Deletar Service
kubectl delete svc -n ingress-nginx-external ingress-nginx-controller

# 3. Reaplicar sem SSL
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml

# 4. Aguardar LoadBalancer reprovisionar
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -w
```

---

## 📞 **SUPORTE**

- **AWS ACM Docs**: https://docs.aws.amazon.com/acm/
- **NGINX Ingress Docs**: https://kubernetes.github.io/ingress-nginx/
- **AWS NLB Annotations**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/

---

**🎉 Guia completo! Salve este arquivo para referência futura.**

**Última atualização**: 01/11/2025
