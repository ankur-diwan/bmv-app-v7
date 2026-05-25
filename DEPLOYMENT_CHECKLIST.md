# IBM Cloud Code Engine Deployment Checklist
## Banking Model Validation System

Use this checklist to ensure a smooth deployment to IBM Cloud Code Engine.

---

## 📋 Pre-Deployment Phase

### IBM Cloud Account Setup
- [ ] IBM Cloud account created and active
- [ ] Billing enabled (if using paid services)
- [ ] Appropriate permissions/roles assigned
- [ ] Region selected (recommended: us-south or ca-tor)
- [ ] Resource group identified or created

### Local Environment Setup
- [ ] Docker Desktop installed and running
- [ ] IBM Cloud CLI installed (`ibmcloud --version`)
- [ ] Code Engine plugin installed (`ibmcloud plugin install code-engine`)
- [ ] Container Registry plugin installed (`ibmcloud plugin install container-registry`)
- [ ] Git installed (for version control)
- [ ] Logged into IBM Cloud (`ibmcloud login --sso`)

### Credentials Gathered
- [ ] watsonx API key obtained
- [ ] watsonx Project ID noted
- [ ] watsonx Space ID noted (if applicable)
- [ ] watsonx URL confirmed (e.g., https://us-south.ml.cloud.ibm.com)
- [ ] PostgreSQL connection string ready (or plan to create)

---

## 🗄️ Database Setup

### PostgreSQL Provisioning
- [ ] IBM Databases for PostgreSQL service created
- [ ] Database instance provisioned (5-10 minutes wait time)
- [ ] Connection string obtained from service credentials
- [ ] Connection string format verified: `postgresql://user:pass@host:port/db?sslmode=require`
- [ ] Database connectivity tested (optional but recommended)

---

## 🐳 Container Registry Setup

### Registry Configuration
- [ ] Registry region set (`ibmcloud cr region-set <region>`)
- [ ] Logged into Container Registry (`ibmcloud cr login`)
- [ ] Namespace created (`ibmcloud cr namespace-add <namespace>`)
- [ ] Namespace verified (`ibmcloud cr namespaces`)
- [ ] Namespace name noted (e.g., "bankingvalidation")

---

## 🚀 Code Engine Setup

### Project Configuration
- [ ] Code Engine project created (`ibmcloud ce project create`)
- [ ] Project selected (`ibmcloud ce project select`)
- [ ] Project verified (`ibmcloud ce project current`)

---

## 🔧 Application Preparation

### Code Fixes
- [ ] Frontend Dockerfile updated (ARG VITE_API_URL instead of hardcoded ENV)
- [ ] Changes committed to version control
- [ ] Working directory clean and ready for build

### Environment Variables Prepared
Backend requires:
- [ ] `DATABASE_URL` - PostgreSQL connection string
- [ ] `WATSONX_API_KEY` - IBM Cloud API key
- [ ] `WATSONX_PROJECT_ID` - watsonx project ID
- [ ] `WATSONX_URL` - watsonx service endpoint
- [ ] `ENVIRONMENT` - Set to "production"
- [ ] `LOG_LEVEL` - Set to "INFO"
- [ ] `VALIDATION_TEMP_DIR` - Set to "/app/temp/cos_validation"

Optional:
- [ ] `WATSONX_SPACE_ID` - If using watsonx spaces

---

## 🏗️ Backend Deployment

### Build Phase
- [ ] Navigate to backend directory (`cd backend`)
- [ ] Docker image built successfully
- [ ] Image tagged correctly: `icr.io/<namespace>/banking-validation-backend:v1`
- [ ] Image pushed to Container Registry
- [ ] Image verified in registry (`ibmcloud cr images`)

### Deployment Phase
- [ ] Backend application created in Code Engine
- [ ] Port set to 8080
- [ ] Resources allocated (1 CPU, 2G memory)
- [ ] Scaling configured (min: 1, max: 3)
- [ ] Environment variables set correctly
- [ ] Deployment completed without errors
- [ ] Application status shows "Ready"

### Verification Phase
- [ ] Backend URL obtained
- [ ] Health endpoint tested (`curl <backend-url>/health`)
- [ ] Health check returns 200 OK with JSON response
- [ ] API docs accessible (`<backend-url>/docs`)
- [ ] Logs checked for errors (`ibmcloud ce application logs`)

---

## 🎨 Frontend Deployment

### Build Phase
- [ ] Navigate to frontend directory (`cd frontend`)
- [ ] Backend URL from previous step available
- [ ] Docker image built with backend URL as build arg
- [ ] Image tagged correctly: `icr.io/<namespace>/banking-validation-frontend:v1`
- [ ] Image pushed to Container Registry
- [ ] Image verified in registry

### Deployment Phase
- [ ] Frontend application created in Code Engine
- [ ] Port set to 8080
- [ ] Resources allocated (0.5 CPU, 1G memory)
- [ ] Scaling configured (min: 1, max: 2)
- [ ] Deployment completed without errors
- [ ] Application status shows "Ready"

### Verification Phase
- [ ] Frontend URL obtained
- [ ] Frontend accessible in browser
- [ ] Page loads without errors
- [ ] Browser console shows no errors (F12 → Console)
- [ ] No CORS errors
- [ ] API calls going to correct backend URL

---

## ✅ End-to-End Testing

### UI Testing
- [ ] Model configuration form visible
- [ ] All dropdowns populate correctly
- [ ] Product types load (secured, unsecured, revolving)
- [ ] Scorecard types load (application, behavioral, collections)
- [ ] Model types load (GLM, XGBoost, etc.)

### Validation Testing
- [ ] Test validation started with sample data
- [ ] Progress indicators work
- [ ] Validation completes successfully (2-5 minutes)
- [ ] Results page displays correctly
- [ ] Validation metrics shown
- [ ] Document download works
- [ ] Downloaded document opens correctly

### API Testing
- [ ] POST /api/v1/validate endpoint works
- [ ] GET /api/v1/validate/{id} returns status
- [ ] GET /api/v1/validate/{id}/results returns results
- [ ] GET /api/v1/validate/{id}/document downloads file

---

## 🔒 Security Hardening (Production)

### Secrets Management
- [ ] Database credentials moved to Code Engine secrets
- [ ] watsonx API key moved to secrets
- [ ] Environment variables updated to use secrets
- [ ] Plain text credentials removed from deployment commands

### Access Control
- [ ] Custom domain configured (optional)
- [ ] SSL/TLS certificates verified
- [ ] CORS settings reviewed and restricted
- [ ] Rate limiting considered

---

## 📊 Monitoring Setup

### Logging
- [ ] Log forwarding configured (optional)
- [ ] Log retention policy set
- [ ] Error alerts configured

### Monitoring
- [ ] Application metrics reviewed
- [ ] Resource usage monitored
- [ ] Auto-scaling behavior verified
- [ ] Cost monitoring enabled

---

## 📝 Documentation

### Deployment Documentation
- [ ] Backend URL documented
- [ ] Frontend URL documented
- [ ] Deployment date recorded
- [ ] Version numbers noted
- [ ] Configuration documented

### User Documentation
- [ ] User guide updated with new URLs
- [ ] Access instructions provided to users
- [ ] Support contact information shared

---

## 🔄 Post-Deployment Tasks

### Immediate Tasks
- [ ] Notify stakeholders of deployment
- [ ] Share frontend URL with users
- [ ] Monitor initial usage
- [ ] Address any immediate issues

### Short-term Tasks (Week 1)
- [ ] Review application logs daily
- [ ] Monitor resource usage
- [ ] Gather user feedback
- [ ] Document any issues

### Medium-term Tasks (Month 1)
- [ ] Implement persistent document storage (Cloud Object Storage)
- [ ] Set up CI/CD pipeline
- [ ] Configure custom domain
- [ ] Optimize resource allocation based on usage
- [ ] Review and optimize costs

---

## 🆘 Troubleshooting Reference

### Common Issues Checklist

#### Backend Health Check Fails
- [ ] Check application logs
- [ ] Verify DATABASE_URL is correct
- [ ] Verify WATSONX_API_KEY is valid
- [ ] Confirm app has finished starting (wait 60 seconds)
- [ ] Check port configuration (should be 8080)

#### Frontend Shows Blank Page
- [ ] Check browser console for errors
- [ ] Verify frontend was built with correct backend URL
- [ ] Check for CORS errors
- [ ] Verify backend is accessible from browser

#### Validation Fails
- [ ] Check backend logs for errors
- [ ] Verify watsonx credentials
- [ ] Confirm watsonx project/space is accessible
- [ ] Check database connectivity
- [ ] Review resource allocation (may need more memory)

#### Document Download Fails
- [ ] Verify validation completed successfully
- [ ] Check if document was generated (backend logs)
- [ ] Note: Documents are ephemeral in Code Engine
- [ ] Plan to implement Cloud Object Storage for persistence

---

## 📞 Support Resources

### IBM Cloud Support
- [ ] IBM Cloud support ticket system access confirmed
- [ ] Support plan level verified
- [ ] Emergency contact information available

### Documentation Links
- [ ] Code Engine docs bookmarked
- [ ] watsonx.ai docs bookmarked
- [ ] Container Registry docs bookmarked
- [ ] Application deployment guide saved

---

## ✨ Deployment Success Criteria

All of the following must be true:
- [ ] Backend health check returns 200 OK
- [ ] Frontend loads in browser without errors
- [ ] Test validation completes successfully
- [ ] Document can be downloaded
- [ ] No critical errors in logs
- [ ] Resource usage is within expected limits
- [ ] Users can access the application

---

## 📅 Maintenance Schedule

### Daily
- [ ] Check application logs for errors
- [ ] Monitor resource usage
- [ ] Verify application availability

### Weekly
- [ ] Review validation metrics
- [ ] Check for IBM Cloud service updates
- [ ] Review cost reports
- [ ] Update documentation if needed

### Monthly
- [ ] Review and optimize resource allocation
- [ ] Update dependencies if needed
- [ ] Review security settings
- [ ] Backup configuration and documentation
- [ ] Test disaster recovery procedures

---

**Deployment Status:** ⬜ Not Started | 🟡 In Progress | ✅ Complete

**Deployment Date:** _______________

**Deployed By:** _______________

**Backend URL:** _______________

**Frontend URL:** _______________

**Notes:**
_______________________________________________________________________________
_______________________________________________________________________________
_______________________________________________________________________________
