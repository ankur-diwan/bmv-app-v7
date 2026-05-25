# IBM Cloud Console Deployment - Step-by-Step Guide
## Banking Model Validation System

**Deployment Method**: IBM Cloud Web Console  
**Estimated Time**: 30-45 minutes  
**Region**: ca-tor (Toronto)

---

## 📋 Prerequisites Checklist

Before starting, ensure you have:
- [x] IBM Cloud account logged in
- [x] watsonx credentials ready
- [x] Docker Desktop running on your laptop
- [x] This project folder open

---

## Part 1: Prepare Docker Images Locally (15 minutes)

### Step 1.1: Build Backend Image

Open Terminal and run:

```bash
cd "/Users/ad/Downloads/banking-model-validation-code-engine v6 CE/backend"

docker build -t banking-validation-backend:v1 .
```

**Expected Output**: 
```
Successfully built [image-id]
Successfully tagged banking-validation-backend:v1
```

**If build fails**: Check that Docker Desktop is running

---

### Step 1.2: Build Frontend Image (Temporary)

We'll build a temporary frontend first, then rebuild with the actual backend URL later.

```bash
cd "/Users/ad/Downloads/banking-model-validation-code-engine v6 CE/frontend"

docker build --build-arg VITE_API_URL=https://placeholder.com -t banking-validation-frontend:v1 .
```

**Note**: We'll rebuild this after getting the backend URL

---

## Part 2: Create Code Engine Project (5 minutes)

### Step 2.1: Open Code Engine Console

1. Open browser and go to: **https://cloud.ibm.com/codeengine/projects**
2. You should see "Code Engine Projects" page

### Step 2.2: Create New Project

1. Click **"Create project"** button (top right)
2. Fill in the form:
   - **Name**: `banking-validation-ce`
   - **Resource group**: Select `Default`
   - **Location**: Select `Toronto (ca-tor)`
   - **Tags** (optional): Leave empty or add `banking`, `validation`
3. Click **"Create"**
4. Wait 30-60 seconds for project creation
5. You'll be redirected to the project dashboard

**✅ Checkpoint**: You should see "Project: banking-validation-ce" at the top

---

## Part 3: Create Container Registry Namespace (3 minutes)

### Step 3.1: Open Container Registry

1. In a new browser tab, go to: **https://cloud.ibm.com/registry/namespaces**
2. You should see "Container Registry" page

### Step 3.2: Create Namespace

1. Click **"Create"** button
2. Fill in:
   - **Name**: `bankingvalidation` (must be lowercase, no spaces)
   - **Resource group**: Select `Default`
3. Click **"Create"**

**✅ Checkpoint**: You should see `bankingvalidation` in the namespace list

---

## Part 4: Push Images to Container Registry (10 minutes)

### Step 4.1: Login to Container Registry

In Terminal, run:

```bash
ibmcloud cr login
```

**Expected Output**: 
```
Logging 'docker' in to 'ca.icr.io'...
Logged in to 'ca.icr.io'.
OK
```

---

### Step 4.2: Tag and Push Backend Image

```bash
# Tag the image
docker tag banking-validation-backend:v1 ca.icr.io/bankingvalidation/banking-validation-backend:v1

# Push to registry
docker push ca.icr.io/bankingvalidation/banking-validation-backend:v1
```

**Expected Output**:
```
The push refers to repository [ca.icr.io/bankingvalidation/banking-validation-backend]
...
v1: digest: sha256:... size: ...
```

**This may take 3-5 minutes** depending on your internet speed.

---

### Step 4.3: Verify Image in Registry

```bash
ibmcloud cr images --restrict bankingvalidation
```

**Expected Output**: You should see your backend image listed

---

## Part 5: Deploy Backend Application (10 minutes)

### Step 5.1: Create Backend Application

1. Go back to Code Engine project: **https://cloud.ibm.com/codeengine/projects**
2. Click on your project: `banking-validation-ce`
3. In left sidebar, click **"Applications"**
4. Click **"Create"** button

### Step 5.2: Configure Backend Application

**General Settings:**
- **Name**: `banking-validation-backend`
- **Code to run**: Select **"Container image"**
- **Image reference**: `ca.icr.io/bankingvalidation/banking-validation-backend:v1`
- **Registry access**: Select **"IBM Registry (automatic)"**

Click **"Configure image"** to expand more options:

**Listening port:**
- Port: `8080`

**Resources & scaling:**
- CPU: `1 vCPU`
- Memory: `2 GB`
- Min instances: `1`
- Max instances: `3`
- Concurrency: `100`

### Step 5.3: Add Environment Variables

Scroll down to **"Environment variables"** section and click **"Add"** for each:

| Name | Value |
|------|-------|
| `WATSONX_API_KEY` | `bR7uMe8AicsCQKWBXpWzk5n-du9-nVl9qKNZxK2dVaSl` |
| `WATSONX_PROJECT_ID` | `30171d0c-7f5b-4d0d-8fd4-57adfb93f687` |
| `WATSONX_SPACE_ID` | `6e6f0c20-448c-4709-bb33-16b8e4474c1f` |
| `WATSONX_URL` | `https://ca-tor.ml.cloud.ibm.com` |
| `ENVIRONMENT` | `production` |
| `LOG_LEVEL` | `INFO` |
| `VALIDATION_TEMP_DIR` | `/app/temp/cos_validation` |

**Important**: Use "Literal value" type for all variables

### Step 5.4: Create the Application

1. Review all settings
2. Click **"Create"** button at the bottom
3. Wait for deployment (2-3 minutes)

**✅ Checkpoint**: Status should show "Ready" with a green checkmark

---

### Step 5.5: Get Backend URL

1. On the application details page, find **"Application URL"**
2. It will look like: `https://banking-validation-backend.xxxxxx.ca-tor.codeengine.appdomain.cloud`
3. **COPY THIS URL** - you'll need it for the frontend!

### Step 5.6: Test Backend

1. Click on the URL or open in new tab
2. You should see JSON response:
```json
{
  "service": "Banking Model Validation System - Enhanced",
  "version": "2.0.0",
  "status": "operational"
}
```

3. Test health endpoint by adding `/health` to URL:
   - Example: `https://banking-validation-backend.xxxxxx.ca-tor.codeengine.appdomain.cloud/health`
   - Should return: `{"status": "healthy", ...}`

**✅ Checkpoint**: Both endpoints should return JSON responses

---

## Part 6: Rebuild and Deploy Frontend (10 minutes)

### Step 6.1: Rebuild Frontend with Backend URL

**IMPORTANT**: Replace `<BACKEND_URL>` with your actual backend URL from Step 5.5

In Terminal:

```bash
cd "/Users/ad/Downloads/banking-model-validation-code-engine v6 CE/frontend"

# Replace <BACKEND_URL> with your actual URL
docker build --build-arg VITE_API_URL=<BACKEND_URL> -t banking-validation-frontend:v1 .
```

**Example**:
```bash
docker build --build-arg VITE_API_URL=https://banking-validation-backend.abc123.ca-tor.codeengine.appdomain.cloud -t banking-validation-frontend:v1 .
```

---

### Step 6.2: Tag and Push Frontend Image

```bash
# Tag the image
docker tag banking-validation-frontend:v1 ca.icr.io/bankingvalidation/banking-validation-frontend:v1

# Push to registry
docker push ca.icr.io/bankingvalidation/banking-validation-frontend:v1
```

**This may take 2-3 minutes**

---

### Step 6.3: Create Frontend Application

1. Go back to Code Engine project
2. Click **"Applications"** in left sidebar
3. Click **"Create"** button

**General Settings:**
- **Name**: `banking-validation-frontend`
- **Code to run**: Select **"Container image"**
- **Image reference**: `ca.icr.io/bankingvalidation/banking-validation-frontend:v1`
- **Registry access**: Select **"IBM Registry (automatic)"**

**Listening port:**
- Port: `8080`

**Resources & scaling:**
- CPU: `0.5 vCPU`
- Memory: `1 GB`
- Min instances: `1`
- Max instances: `2`
- Concurrency: `100`

**No environment variables needed for frontend**

### Step 6.4: Create the Application

1. Click **"Create"** button
2. Wait for deployment (2-3 minutes)

**✅ Checkpoint**: Status should show "Ready"

---

### Step 6.5: Get Frontend URL

1. Find **"Application URL"** on the application details page
2. It will look like: `https://banking-validation-frontend.xxxxxx.ca-tor.codeengine.appdomain.cloud`
3. **COPY THIS URL** - this is your application!

---

## Part 7: Test Your Application (5 minutes)

### Step 7.1: Open Frontend

1. Click on the frontend URL or open in browser
2. You should see the Banking Model Validation System interface

### Step 7.2: Verify Page Loads

Check that:
- [ ] Page loads without errors
- [ ] No errors in browser console (Press F12 → Console tab)
- [ ] Form fields are visible
- [ ] Dropdowns populate with options

### Step 7.3: Run Test Validation

1. Fill in the form:
   - **Model Name**: `Test_Console_Deployment`
   - **Product Type**: Select `Unsecured Loans`
   - **Scorecard Type**: Select `Application Scorecard`
   - **Model Type**: Select `GLM`
   - **Description**: `Testing console deployment`

2. Click **"Start Validation"**

3. Wait for validation to complete (2-5 minutes)

4. Check that:
   - [ ] Progress indicators work
   - [ ] Validation completes successfully
   - [ ] Results page displays
   - [ ] You can download the validation report

**✅ Checkpoint**: Validation should complete and report should download

---

## 🎉 Deployment Complete!

### Your Application URLs:

**Frontend (Main Application):**
```
https://banking-validation-frontend.xxxxxx.ca-tor.codeengine.appdomain.cloud
```

**Backend (API):**
```
https://banking-validation-backend.xxxxxx.ca-tor.codeengine.appdomain.cloud
```

**API Documentation:**
```
https://banking-validation-backend.xxxxxx.ca-tor.codeengine.appdomain.cloud/docs
```

---

## 📊 Monitoring Your Application

### View Logs

**Backend Logs:**
1. Go to Code Engine project
2. Click "Applications" → "banking-validation-backend"
3. Click "Logging" tab
4. View real-time logs

**Frontend Logs:**
1. Click "Applications" → "banking-validation-frontend"
2. Click "Logging" tab

### Monitor Resources

1. In application details, click "Monitoring" tab
2. View:
   - CPU usage
   - Memory usage
   - Request count
   - Response times

---

## 🔄 Updating Your Application

### Update Backend:

1. Make code changes locally
2. Rebuild image:
   ```bash
   cd backend
   docker build -t ca.icr.io/bankingvalidation/banking-validation-backend:v2 .
   docker push ca.icr.io/bankingvalidation/banking-validation-backend:v2
   ```
3. In Code Engine console:
   - Go to application
   - Click "Edit and create new revision"
   - Update image reference to `:v2`
   - Click "Save and create"

### Update Frontend:

1. Make code changes locally
2. Rebuild with backend URL:
   ```bash
   cd frontend
   docker build --build-arg VITE_API_URL=<BACKEND_URL> -t ca.icr.io/bankingvalidation/banking-validation-frontend:v2 .
   docker push ca.icr.io/bankingvalidation/banking-validation-frontend:v2
   ```
3. Update in Code Engine console (same as backend)

---

## ⚠️ Troubleshooting

### Issue: Backend health check fails

**Solution:**
1. Check logs in Code Engine console
2. Verify environment variables are set correctly
3. Ensure watsonx credentials are valid

### Issue: Frontend shows blank page

**Solution:**
1. Open browser console (F12)
2. Check for CORS or network errors
3. Verify frontend was built with correct backend URL
4. Rebuild frontend if backend URL was wrong

### Issue: Validation fails

**Solution:**
1. Check backend logs
2. Verify watsonx credentials
3. Ensure watsonx project/space is accessible
4. Check if backend has enough memory (increase to 4GB if needed)

### Issue: Image push fails

**Solution:**
1. Ensure you're logged in: `ibmcloud cr login`
2. Check namespace exists: `ibmcloud cr namespace-list`
3. Verify image name format: `ca.icr.io/bankingvalidation/...`

---

## 💰 Cost Estimate

**Monthly costs (ca-tor region):**
- Backend: ~$30-90 (1 vCPU, 2GB, 1-3 instances)
- Frontend: ~$15-30 (0.5 vCPU, 1GB, 1-2 instances)
- Container Registry: ~$0-5 (<5GB storage)
- **Total: ~$45-125/month**

**To reduce costs:**
- Set min instances to 0 for non-production
- Use smaller instance sizes
- Delete unused images from registry

---

## 📞 Support

**If you need help:**
- Code Engine docs: https://cloud.ibm.com/docs/codeengine
- Container Registry docs: https://cloud.ibm.com/docs/Registry
- IBM Cloud Support: https://cloud.ibm.com/unifiedsupport/supportcenter

---

## ✅ Success Checklist

- [ ] Code Engine project created
- [ ] Container Registry namespace created
- [ ] Backend image built and pushed
- [ ] Backend application deployed and healthy
- [ ] Backend URL obtained
- [ ] Frontend image built with backend URL
- [ ] Frontend image pushed
- [ ] Frontend application deployed
- [ ] Frontend accessible in browser
- [ ] Test validation completed successfully
- [ ] Validation report downloaded

**All done? Congratulations! Your application is live! 🎉**
