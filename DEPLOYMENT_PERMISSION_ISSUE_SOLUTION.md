# IBM Cloud Permission Issue - Solution Guide

## 🚨 Current Situation

Your IBM Cloud account (`Ankur.Diwan@ibm.com`) has **restricted permissions** that prevent:
1. ❌ Creating Container Registry namespaces
2. ❌ Creating Code Engine projects

## ✅ Solutions

### Option 1: Request Permissions from Administrator (Recommended)

Contact your IBM Cloud account administrator and request the following IAM permissions:

#### Required IAM Roles:

**For Container Registry:**
- Role: `Manager` or `Writer`
- Service: `Container Registry`
- Resource Group: `Default`

**For Code Engine:**
- Role: `Manager` or `Writer`
- Service: `Code Engine`
- Resource Group: `Default`

**Email Template for Administrator:**
```
Subject: IBM Cloud Permissions Request - Code Engine & Container Registry

Hi [Admin Name],

I need permissions to deploy an application to IBM Cloud Code Engine. 
Could you please grant me the following IAM roles:

1. Container Registry - Manager role (for resource group: Default)
2. Code Engine - Manager role (for resource group: Default)

Account: CE-Productivity-Projects (7289e58a049a4814bfbcac984cac6840)
User: Ankur.Diwan@ibm.com
Region: ca-tor

This is needed to deploy the Banking Model Validation application.

Thank you!
```

---

### Option 2: Use IBM Cloud Console (Web UI)

You can deploy using the IBM Cloud Console which may have different permission requirements:

#### Step 1: Create Container Registry Namespace
1. Go to: https://cloud.ibm.com/registry/namespaces
2. Click "Create"
3. Name: `bankingvalidation`
4. Resource Group: `Default`
5. Click "Create"

#### Step 2: Create Code Engine Project
1. Go to: https://cloud.ibm.com/codeengine/projects
2. Click "Create project"
3. Name: `banking-validation-ce`
4. Resource Group: `Default`
5. Location: `Toronto (ca-tor)`
6. Click "Create"

#### Step 3: Build and Push Images Locally

Since you can't create namespaces via CLI, try using Docker directly:

```bash
# Login to IBM Cloud Container Registry
docker login ca.icr.io

# Build backend
cd backend
docker build -t ca.icr.io/bankingvalidation/banking-validation-backend:v1 .
docker push ca.icr.io/bankingvalidation/banking-validation-backend:v1

# Build frontend (need backend URL first)
cd ../frontend
docker build --build-arg VITE_API_URL=<BACKEND_URL> -t ca.icr.io/bankingvalidation/banking-validation-frontend:v1 .
docker push ca.icr.io/bankingvalidation/banking-validation-frontend:v1
```

#### Step 4: Deploy via Console

**Backend:**
1. Go to your Code Engine project
2. Click "Applications" → "Create"
3. Name: `banking-validation-backend`
4. Image: `ca.icr.io/bankingvalidation/banking-validation-backend:v1`
5. Port: `8080`
6. Resources: 1 CPU, 2GB memory
7. Environment variables:
   - `WATSONX_API_KEY`: `bR7uMe8AicsCQKWBXpWzk5n-du9-nVl9qKNZxK2dVaSl`
   - `WATSONX_PROJECT_ID`: `30171d0c-7f5b-4d0d-8fd4-57adfb93f687`
   - `WATSONX_URL`: `https://ca-tor.ml.cloud.ibm.com`
   - `ENVIRONMENT`: `production`
   - `LOG_LEVEL`: `INFO`
8. Click "Create"

**Frontend:**
1. Get backend URL from previous step
2. Rebuild frontend with backend URL
3. Push new image
4. Create frontend application in Code Engine
5. Name: `banking-validation-frontend`
6. Image: `ca.icr.io/bankingvalidation/banking-validation-frontend:v1`
7. Port: `8080`
8. Resources: 0.5 CPU, 1GB memory

---

### Option 3: Use Existing Resources

Check if there are existing resources you can use:

```bash
# Check for existing namespaces in other regions
ibmcloud cr region-set us-south
ibmcloud cr namespace-list

# Check for existing Code Engine projects
ibmcloud ce project list
```

If you find existing resources, you can use them instead of creating new ones.

---

### Option 4: Alternative Deployment - Use Docker Compose Locally

If IBM Cloud permissions cannot be resolved quickly, you can run the application locally:

```bash
# Set environment variables
export WATSONX_API_KEY="bR7uMe8AicsCQKWBXpWzk5n-du9-nVl9qKNZxK2dVaSl"
export WATSONX_PROJECT_ID="30171d0c-7f5b-4d0d-8fd4-57adfb93f687"
export WATSONX_URL="https://ca-tor.ml.cloud.ibm.com"

# Start application
docker-compose up -d

# Access at:
# Frontend: http://localhost:3000
# Backend: http://localhost:8000
```

---

## 🔍 Checking Your Current Permissions

Run these commands to see what you have access to:

```bash
# Check IAM policies
ibmcloud iam user-policies Ankur.Diwan@ibm.com

# Check resource groups
ibmcloud resource groups

# Check Code Engine access
ibmcloud ce project list

# Check Container Registry access
ibmcloud cr namespace-list
```

---

## 📞 Next Steps

1. **Immediate**: Contact your IBM Cloud administrator for permissions
2. **Alternative**: Try Option 2 (Console deployment) while waiting
3. **Temporary**: Use Option 4 (local Docker) for development/testing

---

## ✅ Once Permissions Are Granted

After you receive the necessary permissions, run:

```bash
./SIMPLIFIED_DEPLOYMENT.sh
```

Or follow the manual deployment guide in `IBM_CLOUD_CODE_ENGINE_DEPLOYMENT_GUIDE.md`.

---

## 📧 Support

If you need help:
- IBM Cloud Support: https://cloud.ibm.com/unifiedsupport/supportcenter
- Account Administrator: Contact your organization's IBM Cloud admin
- Documentation: https://cloud.ibm.com/docs/codeengine
