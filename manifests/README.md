# 📦 Kubernetes Manifests

Este diretório contém os manifestos Kubernetes para NGINX Ingress Controllers e exemplos de aplicações.

---

## 📂 **ESTRUTURA**

```
manifests/
├── eks-ingress-nginx-1.13.3-external.yaml    # NGINX Ingress Controller (público)
├── eks-ingress-nginx-1.13.3-internal.yaml    # NGINX Ingress Controller (privado)
├── SSL-CERTIFICATE-SETUP.md                   # 🔐 Guia de configuração SSL/TLS
└── examples/
    ├── nginx-deployment.yaml                  # Exemplo de deployment com Ingress
    └── test-internet-connectivity.yaml        # Pod de teste de conectividade
```

---

## 🚀 **QUICK START**

### **Deployar NGINX Ingress Controllers:**

```bash
# Via GitHub Actions (Recomendado)
Actions → deploy-ingress-nginx
  clusters: all
  ingress_type: both
  action: apply
  validate: true

# OU via kubectl (Manual)
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-external.yaml
kubectl apply -f manifests/eks-ingress-nginx-1.13.3-internal.yaml
```

---

## 🔐 **CONFIGURAR SSL/TLS**

Para habilitar HTTPS com certificado SSL válido:

1. **Leia o guia completo**: [SSL-CERTIFICATE-SETUP.md](SSL-CERTIFICATE-SETUP.md)
2. **Execute o script automatizado**:
   ```bash
   chmod +x ../scripts/activate-ssl-certificate.sh
   ../scripts/activate-ssl-certificate.sh
   ```

**OU siga manualmente**:

1. Criar/obter certificado ACM
2. Descomente as linhas SSL nos manifests
3. Atualize o ARN do certificado
4. Reaplicar os manifests
5. Configurar DNS

---

## 📝 **INGRESS CONTROLLERS**

### **External Ingress (Público)**

- **Arquivo**: `eks-ingress-nginx-1.13.3-external.yaml`
- **Namespace**: `ingress-nginx-external`
- **IngressClass**: `nginx`
- **LoadBalancer**: Internet-facing NLB
- **Uso**: Aplicações públicas acessíveis pela internet

**Verificar status:**
```bash
kubectl get pods -n ingress-nginx-external
kubectl get svc -n ingress-nginx-external ingress-nginx-controller
```

---

### **Internal Ingress (Privado)**

- **Arquivo**: `eks-ingress-nginx-1.13.3-internal.yaml`
- **Namespace**: `ingress-nginx-internal`
- **IngressClass**: `nginx-internal`
- **LoadBalancer**: Internal NLB (VPC only)
- **Uso**: Aplicações internas/privadas

**Verificar status:**
```bash
kubectl get pods -n ingress-nginx-internal
kubectl get svc -n ingress-nginx-internal ingress-nginx-controller
```

---

## 🧪 **EXEMPLOS**

### **1. nginx-deployment.yaml**

Deployment completo com:
- ✅ Namespace dedicado
- ✅ Deployment com 3 réplicas
- ✅ Service ClusterIP
- ✅ Ingress configurado para NGINX Ingress Controller
- ✅ Healthchecks (liveness + readiness)
- ✅ Resource limits

**Deploy:**
```bash
kubectl apply -f manifests/examples/nginx-deployment.yaml
```

**Verificar:**
```bash
kubectl get all -n nginx-example
kubectl get ingress -n nginx-example
```

**Testar:**
```bash
# Obter LoadBalancer hostname
LB=$(kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Testar HTTP
curl http://$LB
```

---

### **2. test-internet-connectivity.yaml**

Pods de teste para validar conectividade internet:
- ✅ Teste de DNS resolution
- ✅ Teste de HTTP/HTTPS
- ✅ Teste de AWS APIs
- ✅ Ping para DNS públicos
- ✅ Mostra IP público (via NAT Gateway)

**Deploy:**
```bash
kubectl apply -f manifests/examples/test-internet-connectivity.yaml
```

**Ver resultados:**
```bash
kubectl logs test-internet-connectivity
kubectl logs test-internet-ping
```

---

## 🎯 **CRIAR SEU PRÓPRIO INGRESS**

### **Template básico (HTTP):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: default
spec:
  ingressClassName: nginx  # Para público (external)
  # ingressClassName: nginx-internal  # Para privado (internal)
  rules:
  - host: app.meudominio.com  # Opcional: deixe vazio para aceitar qualquer host
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
```

---

### **Template avançado (com SSL/TLS e annotations):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: default
  annotations:
    # NGINX Ingress annotations
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-body-size: "32m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Rate limiting (opcional)
    nginx.ingress.kubernetes.io/limit-rps: "100"
    
    # CORS (opcional)
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
spec:
  ingressClassName: nginx
  rules:
  - host: app.meudominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: meu-api-servico
            port:
              number: 8080
  # TLS configuration (optional - for end-to-end encryption)
  tls:
  - hosts:
    - app.meudominio.com
    secretName: meu-tls-secret
```

---

## 🛠️ **UTILITÁRIOS**

### **Verificar IngressClasses disponíveis:**

```bash
kubectl get ingressclass

# Deve mostrar:
# NAME             CONTROLLER                     AGE
# nginx            k8s.io/ingress-nginx           1h
# nginx-internal   k8s.io/ingress-nginx-internal  1h
```

---

### **Listar todos os Ingresses:**

```bash
# Todos os namespaces
kubectl get ingress -A

# Namespace específico
kubectl get ingress -n nginx-example
```

---

### **Debugar Ingress:**

```bash
# Ver detalhes
kubectl describe ingress <nome> -n <namespace>

# Ver logs do controller
kubectl logs -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external --tail=100

# Ver configuração NGINX gerada
kubectl exec -n ingress-nginx-external deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf
```

---

## 📚 **DOCUMENTAÇÃO ADICIONAL**

- **SSL Setup Guide**: [SSL-CERTIFICATE-SETUP.md](SSL-CERTIFICATE-SETUP.md) - Guia completo de SSL/TLS
- **NGINX Ingress Docs**: https://kubernetes.github.io/ingress-nginx/
- **AWS NLB Annotations**: https://kubernetes.io/docs/concepts/services-networking/service/#aws-nlb-support

---

## 🔧 **TROUBLESHOOTING**

### **Ingress não roteia tráfego:**

```bash
# 1. Verificar IngressClass
kubectl get ingress <nome> -n <namespace> -o yaml | grep ingressClassName

# 2. Verificar backend service existe
kubectl get svc -n <namespace>

# 3. Verificar endpoints
kubectl get endpoints -n <namespace> <service-name>

# 4. Ver logs do controller
kubectl logs -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external
```

---

### **LoadBalancer não provisiona:**

```bash
# Ver eventos
kubectl describe svc -n ingress-nginx-external ingress-nginx-controller | tail -50

# Verificar annotations
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -o yaml | grep -A 10 annotations
```

---

### **Erro de certificado SSL:**

Veja: [SSL-CERTIFICATE-SETUP.md - Troubleshooting](SSL-CERTIFICATE-SETUP.md#6-troubleshooting)

---

## ⚠️ **NOTAS IMPORTANTES**

1. **SSL/TLS está COMENTADO por padrão** nos manifests
2. **Siga o guia SSL-CERTIFICATE-SETUP.md** antes de descomentar
3. **Certificado ACM deve estar em ISSUED** antes de usar
4. **ARN do certificado deve ser da MESMA região** do cluster
5. **LoadBalancer leva 2-5 minutos** para provisionar
6. **DNS propagation pode levar até 1 hora** (depende do TTL)

---

**Última atualização**: 01/11/2025
