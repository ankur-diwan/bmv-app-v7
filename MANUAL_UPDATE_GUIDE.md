# Manual Code Engine Update Guide
## Step-by-Step Console Method

This guide shows you how to manually update your Code Engine application using the IBM Cloud Console - the same way we did it successfully before.

---

## 📋 What You'll Do

1. Update code in GitHub (already done ✅)
2. Open Code Engine Console
3. Edit your application
4. Point to new GitHub code
5. Let Code Engine rebuild and deploy

**Total Time:** 10-15 minutes

---

## Step 1: Verify GitHub Code is Ready

✅ **Already Complete!**
- Branch: `bvm-app-v6`
- Repository: `https://github.com/ankur-diwan/banking-model-validation.git`
- Latest commit includes all fixes

---

## Step 2: Open IBM Cloud Code Engine Console

1. **Open your browser**

2. **Go to Code Engine Projects:**
   ```
   https://cloud.ibm.com/codeengine/projects
   ```

3. **Login if needed** with your IBM Cloud credentials

4. **You should see your project** in the list

---

## Step 3: Select Your Project

1. **Find your project** in the list (look for the name you used before)
   - Common names: `banking-validation-ce`, `banking-validation`, or similar

2. **Click on the project name** to open it

3. **You'll see the project dashboard** with:
   - Applications
   - Jobs
   - Image builds
   - etc.

---

## Step 4: Open Your Backend Application

1. **In the left sidebar**, click **"Applications"**

2. **Find your backend application** in the list
   - Look for: `banking-validation-backend` or similar name

3. **Click on the application name** to open its details page

---

## Step 5: Edit and Create New Revision

1. **On the application details page**, look for the button:
   - **"Edit and create new revision"** (top right area)
   - OR **"Configuration"** tab → **"Edit"** button

2. **Click the button** to open the edit form

---

## Step 6: Update to Use GitHub Source Code

### 6.1 Change Code Source

1. **Find the "Code" section** in the edit form

2. **You'll see two options:**
   - ⚪ Container image
   - ⚪ Source code

3. **Select "Source code"** (click the radio button)

### 6.2 Configure GitHub Repository

Once you select "Source code", new fields will appear:

**Code repo URL:**
```
https://github.com/ankur-diwan/banking-model-validation.git
```

**Branch name:**
```
bvm-app-v6
```

**Context directory:**
```
backend
```

**Dockerfile:**
```
Dockerfile
```

### 6.3 Build Strategy

- **Build strategy:** Dockerfile
- **Build timeout:** 600 (default is fine)

---

## Step 7: Verify Other Settings

### Port Configuration
- **Listening port:** `8080` (should already be set)

### Resources
- **CPU:** `1 vCPU` (or whatever you had before)
- **Memory:** `2 GB` (or whatever you had before)
- **Min instances:** `1`
- **Max instances:** `3`

### Environment Variables

**Make sure these are still set:**

| Name | Value |
|------|-------|
| `WATSONX_API_KEY` | `bR7uMe8AicsCQKWBXpWzk5n-du9-nVl9qKNZxK2dVaSl` |
| `WATSONX_PROJECT_ID` | `30171d0c-7f5b-4d0d-8fd4-57adfb93f687` |
| `WATSONX_SPACE_ID` | `6e6f0c20-448c-4709-bb33-16b8e4474c1f` |
| `WATSONX_URL` | `https://ca-tor.ml.cloud.ibm.com` |
| `ENVIRONMENT` | `production` |
| `LOG_LEVEL` | `INFO` |
| `VALIDATION_TEMP_DIR` | `/app/temp/cos_validation` |

**If any are missing, add them back!**

---

## Step 8: Save and Deploy

1. **Scroll to the bottom** of the edit form

2. **Click "Save and create"** button

3. **Wait for the build and deployment**
   - This will take 5-10 minutes
   - Code Engine will:
     - Clone your GitHub repo
     - Build the Docker image
     - Deploy the new version

---

## Step 9: Monitor the Deployment

### 9.1 Watch the Status

On the application details page, you'll see:
- **Status:** Building → Deploying → Ready
- **Latest revision:** Will show the new revision number

### 9.2 View Build Logs (Optional)

1. Click on **"Image builds"** in left sidebar
2. Find the latest build
3. Click on it to see build logs
4. Watch the progress

### 9.3 View Application Logs

1. On application details page
2. Click **"Logging"** tab
3. See real-time logs from your application

---

## Step 10: Verify the Update

### 10.1 Check Application Status

On the application details page:
- ✅ **Status:** Should show "Ready" with green checkmark
- ✅ **Instances:** Should show running instances (e.g., "1/1")
- ✅ **Latest revision:** Should show new revision number

### 10.2 Test the Application

1. **Find the Application URL** on the details page
   - It will look like: `https://banking-validation-backend.xxxxx.ca-tor.codeengine.appdomain.cloud`

2. **Test the health endpoint:**
   - Add `/health` to the URL
   - Example: `https://banking-validation-backend.xxxxx.ca-tor.codeengine.appdomain.cloud/health`
   - Should return JSON: `{"status": "healthy", ...}`

3. **Test the main endpoint:**
   - Open the base URL in browser
   - Should return JSON with service info

### 10.3 Test API Documentation

- Add `/docs` to your backend URL
- Example: `https://banking-validation-backend.xxxxx.ca-tor.codeengine.appdomain.cloud/docs`
- Should show Swagger UI with all API endpoints

---

## Step 11: Update Frontend (If Needed)

If you also need to update the frontend:

### 11.1 Get Backend URL

From Step 10, copy your backend URL (without /health or /docs)

### 11.2 Edit Frontend Application

1. Go back to **"Applications"** in left sidebar
2. Click on your **frontend application**
3. Click **"Edit and create new revision"**

### 11.3 Configure Frontend Source

**Code repo URL:**
```
https://github.com/ankur-diwan/banking-model-validation.git
```

**Branch name:**
```
bvm-app-v6
```

**Context directory:**
```
frontend
```

**Dockerfile:**
```
Dockerfile
```

### 11.4 Add Build Argument

**IMPORTANT:** Frontend needs the backend URL at build time!

In the edit form, look for **"Build arguments"** section:

**Name:** `VITE_API_URL`
**Value:** `<YOUR_BACKEND_URL>` (from Step 10)

Example:
```
VITE_API_URL=https://banking-validation-backend.abc123.ca-tor.codeengine.appdomain.cloud
```

### 11.5 Save and Deploy

Click **"Save and create"** and wait for deployment (5-10 minutes)

---

## 🎉 Success Checklist

After completing all steps:

- [ ] Backend application shows "Ready" status
- [ ] Backend health endpoint returns healthy
- [ ] Backend API docs are accessible
- [ ] Frontend application shows "Ready" status (if updated)
- [ ] Frontend loads in browser (if updated)
- [ ] Can run a test validation successfully

---

## 🔧 Troubleshooting

### Issue: Build Fails

**Check build logs:**
1. Go to "Image builds" in left sidebar
2. Click on failed build
3. Read error messages

**Common causes:**
- Wrong GitHub URL or branch
- Wrong context directory
- Dockerfile not found
- Build timeout (increase to 900 seconds)

**Solution:**
- Edit application again
- Fix the incorrect setting
- Save and create new revision

### Issue: Application Won't Start

**Check application logs:**
1. Go to application details
2. Click "Logging" tab
3. Look for error messages

**Common causes:**
- Missing environment variables
- Wrong environment variable values
- Application crash on startup

**Solution:**
- Edit application
- Verify all environment variables
- Check values are correct
- Save and create new revision

### Issue: Health Check Fails

**Symptoms:**
- Application shows "Ready" but health endpoint returns error

**Check:**
1. Verify port is set to 8080
2. Check application logs for errors
3. Verify environment variables (especially watsonx credentials)

**Solution:**
- Edit application
- Fix port or environment variables
- Save and create new revision

---

## 📝 Quick Reference

### Your GitHub Details
- **Repository:** `https://github.com/ankur-diwan/banking-model-validation.git`
- **Branch:** `bvm-app-v6`
- **Backend Context:** `backend`
- **Frontend Context:** `frontend`

### Your watsonx Details
- **API Key:** `bR7uMe8AicsCQKWBXpWzk5n-du9-nVl9qKNZxK2dVaSl`
- **Project ID:** `30171d0c-7f5b-4d0d-8fd4-57adfb93f687`
- **Space ID:** `6e6f0c20-448c-4709-bb33-16b8e4474c1f`
- **URL:** `https://ca-tor.ml.cloud.ibm.com`

### Code Engine Console
- **Projects:** https://cloud.ibm.com/codeengine/projects
- **Region:** ca-tor (Toronto)

---

## 💡 Tips

1. **Always update backend first**, then frontend
2. **Wait for "Ready" status** before testing
3. **Check logs** if something doesn't work
4. **Keep backend URL handy** for frontend build
5. **Build arguments are case-sensitive** - use exact names
6. **Environment variables persist** across revisions unless you change them

---

## ✅ That's It!

You've successfully updated your Code Engine application using the manual console method!

This is the same process we used before - it works reliably and doesn't require CLI permissions.

**Next time you need to update:**
1. Commit code changes to GitHub
2. Open Code Engine Console
3. Edit application
4. Point to updated GitHub branch
5. Save and create

Simple! 🎉
