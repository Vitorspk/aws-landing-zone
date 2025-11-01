#!/bin/bash

# ==============================================================================
# SSL CERTIFICATE ACTIVATION - AUTOMATED SCRIPT
# ==============================================================================
# This script automates the SSL certificate activation process for NGINX Ingress
# Follow the prompts and provide the required information
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REGION="sa-east-1"
MANIFEST_EXTERNAL="manifests/eks-ingress-nginx-1.13.3-external.yaml"
MANIFEST_INTERNAL="manifests/eks-ingress-nginx-1.13.3-internal.yaml"

echo -e "${BLUE}=================================================="
echo "🔐 SSL Certificate Activation for NGINX Ingress"
echo -e "==================================================${NC}"
echo ""

# ==============================================================================
# STEP 1: Certificate ARN
# ==============================================================================

echo -e "${YELLOW}Step 1: Certificate ARN${NC}"
echo "---------------------------------------------------"
echo ""
echo "Do you already have an ACM certificate?"
echo "  1) Yes, I have the ARN"
echo "  2) No, I need to create one"
echo ""
read -p "Choose option (1 or 2): " CERT_OPTION

if [ "$CERT_OPTION" == "2" ]; then
    echo ""
    echo "Creating new ACM certificate..."
    echo ""
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    
    echo ""
    echo "Requesting certificate for: $DOMAIN and *.$DOMAIN"
    
    CERT_ARN=$(aws acm request-certificate \
      --domain-name "$DOMAIN" \
      --subject-alternative-names "*.$DOMAIN" \
      --validation-method DNS \
      --region $REGION \
      --tags Key=Name,Value="$DOMAIN-wildcard" Key=ManagedBy,Value=Script \
      --query 'CertificateArn' \
      --output text)
    
    echo -e "${GREEN}✅ Certificate requested!${NC}"
    echo "ARN: $CERT_ARN"
    echo ""
    
    echo -e "${YELLOW}IMPORTANT: You need to validate this certificate via DNS${NC}"
    echo "Get validation records:"
    echo ""
    aws acm describe-certificate \
      --certificate-arn "$CERT_ARN" \
      --region $REGION \
      --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.{Name:Name,Value:Value}]' \
      --output table
    
    echo ""
    echo "Add the CNAME records above to your DNS provider"
    echo "Then run this script again with option 1 when certificate is ISSUED"
    exit 0
else
    echo ""
    read -p "Enter your ACM certificate ARN: " CERT_ARN
    
    # Validate certificate exists and is issued
    echo ""
    echo "Validating certificate..."
    
    CERT_STATUS=$(aws acm describe-certificate \
      --certificate-arn "$CERT_ARN" \
      --region $REGION \
      --query 'Certificate.Status' \
      --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$CERT_STATUS" == "NOT_FOUND" ]; then
        echo -e "${RED}❌ Certificate not found. Check the ARN and region.${NC}"
        exit 1
    fi
    
    if [ "$CERT_STATUS" != "ISSUED" ]; then
        echo -e "${RED}❌ Certificate status: $CERT_STATUS${NC}"
        echo "Certificate must be in ISSUED state before use."
        echo "Current validation status:"
        aws acm describe-certificate \
          --certificate-arn "$CERT_ARN" \
          --region $REGION \
          --query 'Certificate.DomainValidationOptions[*].[DomainName,ValidationStatus]' \
          --output table
        exit 1
    fi
    
    echo -e "${GREEN}✅ Certificate is valid and issued${NC}"
    echo ""
fi

# ==============================================================================
# STEP 2: Choose Ingress Controller
# ==============================================================================

echo -e "${YELLOW}Step 2: Choose Ingress Controller${NC}"
echo "---------------------------------------------------"
echo ""
echo "Which Ingress Controller do you want to enable SSL?"
echo "  1) External (Public - Internet-facing)"
echo "  2) Internal (Private - VPC only)"
echo "  3) Both"
echo ""
read -p "Choose option (1, 2, or 3): " INGRESS_OPTION

case $INGRESS_OPTION in
    1)
        MANIFESTS=("$MANIFEST_EXTERNAL")
        NAMESPACES=("ingress-nginx-external")
        ;;
    2)
        MANIFESTS=("$MANIFEST_INTERNAL")
        NAMESPACES=("ingress-nginx-internal")
        ;;
    3)
        MANIFESTS=("$MANIFEST_EXTERNAL" "$MANIFEST_INTERNAL")
        NAMESPACES=("ingress-nginx-external" "ingress-nginx-internal")
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# ==============================================================================
# STEP 3: Update Manifests
# ==============================================================================

echo ""
echo -e "${YELLOW}Step 3: Updating manifests with certificate ARN${NC}"
echo "---------------------------------------------------"
echo ""

for i in "${!MANIFESTS[@]}"; do
    MANIFEST="${MANIFESTS[$i]}"
    NAMESPACE="${NAMESPACES[$i]}"
    
    echo "Updating: $MANIFEST"
    
    # Create backup
    cp "$MANIFEST" "$MANIFEST.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Uncomment SSL lines and update ARN
    sed -i.tmp "s|# service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy:|service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy:|g" "$MANIFEST"
    sed -i.tmp "s|# service.beta.kubernetes.io/aws-load-balancer-ssl-cert:.*|service.beta.kubernetes.io/aws-load-balancer-ssl-cert: $CERT_ARN|g" "$MANIFEST"
    sed -i.tmp "s|# service.beta.kubernetes.io/aws-load-balancer-ssl-ports:|service.beta.kubernetes.io/aws-load-balancer-ssl-ports:|g" "$MANIFEST"
    sed -i.tmp "s|# service.beta.kubernetes.io/aws-load-balancer-backend-protocol:|service.beta.kubernetes.io/aws-load-balancer-backend-protocol:|g" "$MANIFEST"
    sed -i.tmp "s|# service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout:|service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout:|g" "$MANIFEST"
    
    # Remove temp files
    rm -f "$MANIFEST.tmp"
    
    echo -e "${GREEN}✅ Updated $MANIFEST${NC}"
done

echo ""

# ==============================================================================
# STEP 4: Apply Changes
# ==============================================================================

echo -e "${YELLOW}Step 4: Applying changes to Kubernetes${NC}"
echo "---------------------------------------------------"
echo ""
echo -e "${RED}WARNING: This will recreate the LoadBalancer Service!${NC}"
echo "This will cause a brief interruption (2-5 minutes) while the new NLB is provisioned."
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

for i in "${!MANIFESTS[@]}"; do
    MANIFEST="${MANIFESTS[$i]}"
    NAMESPACE="${NAMESPACES[$i]}"
    
    echo ""
    echo "Processing namespace: $NAMESPACE"
    
    # Delete existing service
    echo "1. Deleting current LoadBalancer Service..."
    kubectl delete svc -n "$NAMESPACE" ingress-nginx-controller --ignore-not-found
    
    # Apply updated manifest
    echo "2. Applying updated manifest..."
    kubectl apply -f "$MANIFEST"
    
    echo -e "${GREEN}✅ Applied to $NAMESPACE${NC}"
done

# ==============================================================================
# STEP 5: Monitor LoadBalancer Creation
# ==============================================================================

echo ""
echo -e "${YELLOW}Step 5: Monitoring LoadBalancer creation${NC}"
echo "---------------------------------------------------"
echo ""
echo "Waiting for LoadBalancer to be provisioned (this may take 2-5 minutes)..."
echo ""

for NAMESPACE in "${NAMESPACES[@]}"; do
    echo "Monitoring: $NAMESPACE"
    
    # Wait for external IP
    TIMEOUT=300  # 5 minutes
    ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        LB_HOST=$(kubectl get svc -n "$NAMESPACE" ingress-nginx-controller \
          -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$LB_HOST" ]; then
            echo -e "${GREEN}✅ LoadBalancer ready: $LB_HOST${NC}"
            break
        fi
        
        echo -n "."
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    if [ -z "$LB_HOST" ]; then
        echo -e "${RED}⚠️  LoadBalancer still pending after 5 minutes${NC}"
        echo "Check for errors:"
        kubectl describe svc -n "$NAMESPACE" ingress-nginx-controller | tail -30
    fi
    
    echo ""
done

# ==============================================================================
# STEP 6: Verification
# ==============================================================================

echo -e "${YELLOW}Step 6: Verification${NC}"
echo "---------------------------------------------------"
echo ""

for NAMESPACE in "${NAMESPACES[@]}"; do
    echo "Namespace: $NAMESPACE"
    
    # Check for errors in events
    ERRORS=$(kubectl describe svc -n "$NAMESPACE" ingress-nginx-controller 2>/dev/null | grep -i "error" | wc -l)
    
    if [ $ERRORS -gt 0 ]; then
        echo -e "${RED}❌ Errors detected in Service events:${NC}"
        kubectl describe svc -n "$NAMESPACE" ingress-nginx-controller | grep -A 5 -i "error"
    else
        echo -e "${GREEN}✅ No errors detected${NC}"
    fi
    
    # Show service details
    kubectl get svc -n "$NAMESPACE" ingress-nginx-controller
    echo ""
done

# ==============================================================================
# SUMMARY
# ==============================================================================

echo -e "${BLUE}=================================================="
echo "📊 Summary"
echo -e "==================================================${NC}"
echo ""
echo -e "${GREEN}✅ SSL configuration applied!${NC}"
echo ""
echo "Certificate ARN: $CERT_ARN"
echo ""
echo "Next steps:"
echo "  1. Configure DNS to point to the LoadBalancer hostname(s)"
echo "  2. Wait for DNS propagation (5-60 minutes)"
echo "  3. Test HTTPS access: curl -I https://yourdomain.com"
echo "  4. Verify certificate in browser (should show valid SSL)"
echo ""
echo "For detailed DNS configuration, see: manifests/SSL-CERTIFICATE-SETUP.md"
echo ""
