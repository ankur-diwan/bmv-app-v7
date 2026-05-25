# IBM Cloud Code Engine Deployment Guide
## Banking Model Validation System

**Last Updated:** May 25, 2026  
**Application Version:** 2.0.0

---

## 📋 Table of Contents

1. [Application Review Summary](#application-review-summary)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Pre-Deployment Checklist](#pre-deployment-checklist)
5. [Step-by-Step Deployment](#step-by-step-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Troubleshooting](#troubleshooting)
8. [Production Recommendations](#production-recommendations)

---

## 🔍 Application Review Summary

### Current State Analysis

✅ **Backend (FastAPI)**
- **Status:** Code Engine Ready
- **Port:** 8080 (configured in Dockerfile)
- **Health Endpoint:** `/health`
- **Dependencies:** All production-ready packages
- **Key Features:**
  - IBM watsonx.ai integration
  - watsonx.governance support
  - PostgreSQL database connectivity
  - Document generation (Word/PDF)
  - Real-time WebSocket updates
  - MLOps agent integration

✅ **Frontend (React + Vite)**
- **Status:** Code Engine Ready with MODIFICATION NEEDED
- **Port:** 8080 (nginx)
- **Build:** Multi-stage Docker build
- **Issue Found:** Hardcoded backend URL in Dockerfile (line 11)
- **Fix Required:** Use build argument instead

⚠️ **Critical Issue Identified:**
```dockerfile
# Current (Line 11 in frontend/Dockerfile):
ENV VITE_API_URL=https://banking-validation-backend.243hkitbzigu.us-east.codeengine.appdomain.cloud

# Should be:
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}
```

### Application Components

```
┌─────────────────────────────────────────────────────────┐
│                    User Browser                          │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────┐
│         Frontend (Code Engine App)                       │
│         - React SPA served by nginx                      │
│         - Port 8080                                      │
│         - Static files with API URL baked in            │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS API Calls
                     ▼
┌─────────────────────────────────────────────────────────┐
│         Backend (Code Engine App)                        │
│         - FastAPI REST API                               │
│         - Port 8080                                      │
│         - WebSocket support                              │
└────┬──────────────┬──────────────┬──────────────────────┘
     │              │              │
     ▼              ▼              ▼
┌─────────┐  ┌──────────┐  ┌─────────────┐
│PostgreSQL│  │watsonx.ai│  │watsonx.gov  │
│(IBM DB)  │  │          │  │             │
└─────────┘  └──────────┘  └─────────────┘
```

---

## 📦 Prerequisites

### 1. IBM Cloud Account & Services

- [ ] IBM Cloud account with billing enabled
- [ ] Access to the following services:
  - **Code Engine** (for app hosting)
  - **Container Registry** (for Docker images)
  - **Databases for PostgreSQL** (managed database)
  - **watsonx.ai** (AI/ML platform)
  - **watsonx.governance** (optional, for model governance)

### 2. Local Development Tools

```bash
# Required installations
- Docker Desktop (v20.10+)
- IBM Cloud CLI (latest)
- Git

# Verify installations
docker --version
ibmcloud --version
git --version
```

### 3. IBM Cloud CLI Plugins

```bash
# Install required plugins
ibmcloud plugin install code-engine
ibmcloud plugin install container-registry

# Verify plugins
ibmcloud plugin list
```

### 4. Credentials & Configuration

Gather the following information:

**watsonx Credentials:**
- `WATSONX_API_KEY` - Your IBM Cloud API key
- `WATSONX_PROJECT_ID` - watsonx.ai project ID
- `WATSONX_SPACE_ID` - watsonx.ai space ID (optional)
- `WATSONX_URL` - Service endpoint (e.g., `https://us-south.ml.cloud.ibm.com`)

**Database:**
- PostgreSQL connection string (will be created during deployment)

---

## 🏗️ Architecture Overview

### Deployment Strategy

**Two-Application Approach:**
1. **Backend Application** - Deployed first, provides API endpoint
2. **Frontend Application** - Deployed second, configured with backend URL

**Why This Order?**
- Frontend needs backend URL at build time
- Backend URL is only known after deployment
- Frontend build embeds API URL into static files

### Resource Allocation

| Component | CPU | Memory | Min Scale | Max Scale |
|-----------|-----|--------|-----------|-----------|
| Backend   | 1   | 2G     | 1         | 3         |
| Frontend  | 0.5 | 1G     | 1         | 2         |

---

## ✅ Pre-Deployment Checklist

### Phase 1: IBM Cloud Setup

```bash
# 1. Login to IBM Cloud
ibmcloud login --sso

# 2. Select region (choose closest to your users)
ibmcloud target -r us-south  # or ca-tor, eu-de, etc.

# 3. Select or create resource group
ibmcloud target -g Default
# OR create new:
# ibmcloud resource group-create banking-validation-rg
# ibmcloud target -g banking-validation-rg

# 4. Verify target
ibmcloud target
```

### Phase 2: Container Registry Setup

```bash
# 1. Set registry region
ibmcloud cr region-set us-south

# 2. Login to registry
ibmcloud cr login

# 3. Create namespace (choose unique name)
ibmcloud cr namespace-add bankingvalidation

# 4. Verify namespace
ibmcloud cr namespaces
```

### Phase 3: Code Engine Project

```bash
# 1. Create Code Engine project
ibmcloud ce project create --name banking-validation-ce

# 2. Select the project
ibmcloud ce project select --name banking-validation-ce

# 3. Verify selection
ibmcloud ce project current
```

### Phase 4: PostgreSQL Database

**Option A: Using IBM Cloud Console (Recommended for first-time)**

1. Go to IBM Cloud Console → Catalog
2. Search for "Databases for PostgreSQL"
3. Click "Create"
4. Configure:
   - **Name:** `banking-validation-postgres`
   - **Resource Group:** Same as Code Engine
   - **Region:** Same as Code Engine
   - **Plan:** Standard (or Lite for testing)
5. Create and wait for provisioning (5-10 minutes)
6. Get connection string:
   - Go to service instance → Overview → Endpoints
   - Copy the PostgreSQL connection string
   - Format: `postgresql://username:password@host:port/database?sslmode=require`

**Option B: Using CLI**

```bash
# Create PostgreSQL instance
ibmcloud resource service-instance-create banking-validation-postgres \
  databases-for-postgresql standard us-south \
  -p '{"members_memory_allocation_mb": "4096", "members_disk_allocation_mb": "20480"}'

# Get connection details
ibmcloud resource service-key-create banking-validation-postgres-key \
  --instance-name banking-validation-postgres
```

---

## 🚀 Step-by-Step Deployment

### Step 1: Fix Frontend Dockerfile

**CRITICAL:** Update frontend Dockerfile to use build argument

```bash
cd frontend
```

Edit `Dockerfile` and replace lines 10-11:

**FROM:**
```dockerfile
# Set backend API URL at build time for Code Engine deployment
ENV VITE_API_URL=https://banking-validation-backend.243hkitbzigu.us-east.codeengine.appdomain.cloud
```

**TO:**
```dockerfile
# Accept backend API URL as build argument
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}
```

### Step 2: Build and Push Backend Image

```bash
# Navigate to backend directory
cd backend

# Set variables (replace with your values)
export REGISTRY_NAMESPACE="bankingvalidation"
export REGION="us-south"

# Build backend image
docker build -t icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v1 .

# Push to IBM Container Registry
docker push icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v1

# Verify image
ibmcloud cr images | grep banking-validation-backend
```

### Step 3: Deploy Backend to Code Engine

```bash
# Set your credentials (replace with actual values)
export POSTGRES_URL="postgresql://user:pass@host:port/db?sslmode=require"
export WATSONX_API_KEY="your_api_key"
export WATSONX_PROJECT_ID="your_project_id"
export WATSONX_URL="https://us-south.ml.cloud.ibm.com"

# Deploy backend application
ibmcloud ce application create \
  --name banking-validation-backend \
  --image icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v1 \
  --port 8080 \
  --cpu 1 \
  --memory 2G \
  --min-scale 1 \
  --max-scale 3 \
  --env DATABASE_URL="${POSTGRES_URL}" \
  --env WATSONX_API_KEY="${WATSONX_API_KEY}" \
  --env WATSONX_PROJECT_ID="${WATSONX_PROJECT_ID}" \
  --env WATSONX_URL="${WATSONX_URL}" \
  --env ENVIRONMENT="production" \
  --env LOG_LEVEL="INFO" \
  --env VALIDATION_TEMP_DIR="/app/temp/cos_validation"

# Wait for deployment (30-60 seconds)
ibmcloud ce application get --name banking-validation-backend
```

### Step 4: Get Backend URL

```bash
# Get the backend URL
export BACKEND_URL=$(ibmcloud ce application get --name banking-validation-backend --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

echo "Backend URL: ${BACKEND_URL}"

# Test backend health
curl ${BACKEND_URL}/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-05-25T12:00:00Z",
  "version": "2.0.0"
}
```

### Step 5: Build and Push Frontend Image

```bash
# Navigate to frontend directory
cd ../frontend

# Build frontend with backend URL
docker build \
  --build-arg VITE_API_URL=${BACKEND_URL} \
  -t icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v1 .

# Push to registry
docker push icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v1

# Verify image
ibmcloud cr images | grep banking-validation-frontend
```

### Step 6: Deploy Frontend to Code Engine

```bash
# Deploy frontend application
ibmcloud ce application create \
  --name banking-validation-frontend \
  --image icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v1 \
  --port 8080 \
  --cpu 0.5 \
  --memory 1G \
  --min-scale 1 \
  --max-scale 2

# Get frontend URL
export FRONTEND_URL=$(ibmcloud ce application get --name banking-validation-frontend --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

echo "Frontend URL: ${FRONTEND_URL}"
echo "Application deployed successfully!"
echo "Access your application at: ${FRONTEND_URL}"
```

---

## ✓ Post-Deployment Verification

### 1. Backend Health Check

```bash
# Test health endpoint
curl ${BACKEND_URL}/health

# Test API documentation
curl ${BACKEND_URL}/docs
# Open in browser: ${BACKEND_URL}/docs
```

### 2. Frontend Access

```bash
# Open frontend in browser
echo "Open this URL in your browser: ${FRONTEND_URL}"
```

**Browser Checks:**
- [ ] Page loads without errors
- [ ] No console errors (F12 → Console)
- [ ] Model configuration form is visible
- [ ] Dropdowns populate with options

### 3. End-to-End Test

**Via UI:**
1. Open frontend URL in browser
2. Fill in model configuration:
   - Model Name: `Test_Deployment_v1`
   - Product Type: `unsecured`
   - Scorecard Type: `application`
   - Model Type: `GLM`
   - Description: `Code Engine deployment test`
3. Click "Start Validation"
4. Wait for completion (2-5 minutes)
5. Download validation report

**Via API:**
```bash
# Start validation
curl -X POST ${BACKEND_URL}/api/v1/validate \
  -H "Content-Type: application/json" \
  -d '{
    "model_config": {
      "model_name": "Test_Deployment",
      "product_type": "unsecured",
      "scorecard_type": "application",
      "model_type": "GLM",
      "description": "API test"
    },
    "generate_document": true
  }'

# Note the validation_id from response, then check status:
curl ${BACKEND_URL}/api/v1/validate/{validation_id}
```

### 4. View Logs

```bash
# Backend logs
ibmcloud ce application logs --name banking-validation-backend --follow

# Frontend logs
ibmcloud ce application logs --name banking-validation-frontend --follow
```

---

## 🔧 Troubleshooting

### Issue 1: Backend Health Check Fails

**Symptoms:**
```bash
curl ${BACKEND_URL}/health
# Returns 502 or timeout
```

**Solutions:**

1. **Check application status:**
```bash
ibmcloud ce application get --name banking-validation-backend
```

2. **View logs:**
```bash
ibmcloud ce application logs --name banking-validation-backend --tail 100
```

3. **Common causes:**
   - Invalid `DATABASE_URL` - Check PostgreSQL connection string
   - Invalid `WATSONX_API_KEY` - Verify API key is correct
   - App still starting - Wait 60 seconds and retry
   - Port mismatch - Ensure `--port 8080` matches Dockerfile

4. **Fix and redeploy:**
```bash
ibmcloud ce application update \
  --name banking-validation-backend \
  --env DATABASE_URL="corrected_url"
```

### Issue 2: Frontend Shows Blank Page

**Symptoms:**
- Browser shows blank page
- Console shows CORS errors or network failures

**Solutions:**

1. **Check browser console (F12):**
   - Look for API URL errors
   - Check if API calls are going to correct backend URL

2. **Verify frontend was built with correct backend URL:**
```bash
# Check what URL was used during build
ibmcloud ce application get --name banking-validation-frontend
```

3. **Rebuild frontend with correct URL:**
```bash
# Get current backend URL
export BACKEND_URL=$(ibmcloud ce application get --name banking-validation-backend --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

# Rebuild frontend
cd frontend
docker build --build-arg VITE_API_URL=${BACKEND_URL} -t icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2 .
docker push icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2

# Update Code Engine app
ibmcloud ce application update \
  --name banking-validation-frontend \
  --image icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2
```

### Issue 3: Validation Fails

**Symptoms:**
- Validation starts but fails during execution
- Error messages in results

**Solutions:**

1. **Check backend logs:**
```bash
ibmcloud ce application logs --name banking-validation-backend --follow
```

2. **Common causes:**
   - watsonx credentials incorrect
   - watsonx project/space not accessible
   - Database connection issues
   - Insufficient memory/CPU

3. **Increase resources if needed:**
```bash
ibmcloud ce application update \
  --name banking-validation-backend \
  --cpu 2 \
  --memory 4G
```

### Issue 4: Document Download Fails

**Symptoms:**
- Validation completes but document download fails
- 404 error on document endpoint

**Important Note:**
Code Engine uses ephemeral storage. Documents are stored in `/app/output/documents` which is temporary.

**Solutions:**

1. **Short-term:** Download immediately after validation completes
2. **Long-term:** Implement IBM Cloud Object Storage for persistent document storage

### Issue 5: Image Push Fails

**Symptoms:**
```bash
docker push icr.io/...
# Error: unauthorized or denied
```

**Solutions:**

1. **Re-login to registry:**
```bash
ibmcloud cr region-set us-south
ibmcloud cr login
```

2. **Verify namespace exists:**
```bash
ibmcloud cr namespaces
```

3. **Check image name format:**
```bash
# Correct format:
icr.io/<namespace>/<image-name>:<tag>
```

---

## 🏆 Production Recommendations

### 1. Security Enhancements

**Use Code Engine Secrets for Sensitive Data:**

```bash
# Create secrets
ibmcloud ce secret create --name db-credentials \
  --from-literal DATABASE_URL="${POSTGRES_URL}"

ibmcloud ce secret create --name watsonx-credentials \
  --from-literal WATSONX_API_KEY="${WATSONX_API_KEY}" \
  --from-literal WATSONX_PROJECT_ID="${WATSONX_PROJECT_ID}"

# Update backend to use secrets
ibmcloud ce application update \
  --name banking-validation-backend \
  --env-from-secret db-credentials \
  --env-from-secret watsonx-credentials
```

### 2. Persistent Document Storage

**Integrate IBM Cloud Object Storage:**

1. Create COS instance
2. Create bucket for validation documents
3. Update backend code to store documents in COS
4. Update document download endpoint to retrieve from COS

### 3. Custom Domain

```bash
# Add custom domain
ibmcloud ce application update \
  --name banking-validation-frontend \
  --domain validation.yourdomain.com
```

### 4. Monitoring & Logging

**Enable Application Monitoring:**
- Set up IBM Cloud Monitoring
- Configure log forwarding to Log Analysis
- Set up alerts for errors and performance issues

### 5. Auto-scaling Configuration

```bash
# Adjust scaling based on load
ibmcloud ce application update \
  --name banking-validation-backend \
  --min-scale 2 \
  --max-scale 5 \
  --scale-down-delay 300
```

### 6. Database Connection Pooling

Update backend code to use connection pooling for better performance with PostgreSQL.

### 7. CI/CD Pipeline

**Set up automated deployment:**
1. Use IBM Cloud Toolchain
2. Configure GitHub/GitLab integration
3. Automate build and deployment on code push

---

## 📊 Cost Optimization

### Estimated Monthly Costs (US South Region)

| Service | Configuration | Est. Cost |
|---------|--------------|-----------|
| Code Engine - Backend | 1 CPU, 2G RAM, 1-3 instances | $30-90 |
| Code Engine - Frontend | 0.5 CPU, 1G RAM, 1-2 instances | $15-30 |
| PostgreSQL | Standard plan | $60-120 |
| Container Registry | <5GB storage | $0-5 |
| watsonx.ai | Pay-per-use | Variable |
| **Total** | | **$105-245/month** |

**Cost Reduction Tips:**
- Use `--min-scale 0` for non-production environments
- Schedule scale-down during off-hours
- Use Lite tier PostgreSQL for development
- Monitor and optimize watsonx.ai usage

---

## 🔄 Update Procedures

### Update Backend

```bash
# Build new version
cd backend
docker build -t icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v2 .
docker push icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v2

# Update application
ibmcloud ce application update \
  --name banking-validation-backend \
  --image icr.io/${REGISTRY_NAMESPACE}/banking-validation-backend:v2
```

### Update Frontend

```bash
# Get current backend URL
export BACKEND_URL=$(ibmcloud ce application get --name banking-validation-backend --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

# Build new version
cd frontend
docker build --build-arg VITE_API_URL=${BACKEND_URL} -t icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2 .
docker push icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2

# Update application
ibmcloud ce application update \
  --name banking-validation-frontend \
  --image icr.io/${REGISTRY_NAMESPACE}/banking-validation-frontend:v2
```

---

## 📞 Support & Resources

### IBM Cloud Resources
- [Code Engine Documentation](https://cloud.ibm.com/docs/codeengine)
- [watsonx.ai Documentation](https://cloud.ibm.com/docs/watsonx)
- [Container Registry Documentation](https://cloud.ibm.com/docs/Registry)

### Application Support
- Check application logs for errors
- Review this deployment guide
- Consult IBM Cloud support for infrastructure issues

---

## ✅ Deployment Checklist Summary

- [ ] IBM Cloud account configured
- [ ] CLI and plugins installed
- [ ] Container Registry namespace created
- [ ] Code Engine project created
- [ ] PostgreSQL database provisioned
- [ ] watsonx credentials obtained
- [ ] Frontend Dockerfile fixed (build arg)
- [ ] Backend image built and pushed
- [ ] Backend deployed and health check passed
- [ ] Backend URL obtained
- [ ] Frontend image built with backend URL
- [ ] Frontend deployed
- [ ] End-to-end test completed
- [ ] Production security configured (secrets)
- [ ] Monitoring enabled
- [ ] Documentation updated with URLs

---

**Deployment Complete! 🎉**

Your Banking Model Validation System is now running on IBM Cloud Code Engine.

**Next Steps:**
1. Share frontend URL with users
2. Configure custom domain (optional)
3. Set up monitoring and alerts
4. Implement persistent document storage
5. Configure CI/CD pipeline
