#!/bin/bash

###############################################################################
# Simplified IBM Cloud Code Engine Deployment
# Banking Model Validation System - NO DATABASE REQUIRED
# 
# This version deploys without PostgreSQL for faster setup
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${1}${NC}"; }
print_success() { echo -e "${GREEN}✓ ${1}${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ ${1}${NC}"; }
print_error() { echo -e "${RED}✗ ${1}${NC}"; }
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ${1}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

###############################################################################
# MAIN SCRIPT
###############################################################################

print_header "Simplified Code Engine Deployment"
echo "Banking Model Validation System v2.0.0"
echo "NO DATABASE REQUIRED - Stateless Deployment"
echo

# Check if logged in
print_info "Checking IBM Cloud login status..."
if ! ibmcloud target >/dev/null 2>&1; then
    print_warning "Not logged in to IBM Cloud"
    print_info "Logging in now..."
    ibmcloud login --sso
    
    if [ $? -ne 0 ]; then
        print_error "Login failed. Please try again."
        exit 1
    fi
fi

print_success "Logged in to IBM Cloud"

# Get current target info
CURRENT_REGION=$(ibmcloud target --output json 2>/dev/null | grep -o '"region":"[^"]*' | cut -d'"' -f4)
CURRENT_RG=$(ibmcloud target --output json 2>/dev/null | grep -o '"resource_group":"[^"]*' | cut -d'"' -f4)

print_info "Current region: ${CURRENT_REGION:-not set}"
print_info "Current resource group: ${CURRENT_RG:-not set}"

# Ask if user wants to change
read -p "$(echo -e ${BLUE}Use current settings?${NC} [Y/n]: )" use_current
if [[ "$use_current" =~ ^[Nn]$ ]]; then
    read -p "$(echo -e ${BLUE}Enter region${NC} [us-south]: )" REGION
    REGION=${REGION:-us-south}
    ibmcloud target -r ${REGION}
    
    read -p "$(echo -e ${BLUE}Enter resource group${NC} [Default]: )" RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-Default}
    ibmcloud target -g ${RESOURCE_GROUP}
fi

# Configuration
REGISTRY_NAMESPACE="bankingvalidation"
CE_PROJECT="banking-validation-ce"
BACKEND_APP="banking-validation-backend"
FRONTEND_APP="banking-validation-frontend"

print_header "Credentials Required"
echo "You need:"
echo "  1. watsonx API key"
echo "  2. watsonx Project ID"
echo

read -s -p "$(echo -e ${BLUE}watsonx API key${NC}: )" WATSONX_API_KEY
echo
read -p "$(echo -e ${BLUE}watsonx Project ID${NC}: )" WATSONX_PROJECT_ID
read -p "$(echo -e ${BLUE}watsonx URL${NC} [https://us-south.ml.cloud.ibm.com]: )" WATSONX_URL
WATSONX_URL=${WATSONX_URL:-https://us-south.ml.cloud.ibm.com}

if [ -z "$WATSONX_API_KEY" ] || [ -z "$WATSONX_PROJECT_ID" ]; then
    print_error "watsonx credentials are required"
    exit 1
fi

print_success "Credentials collected"

# Container Registry Setup
print_header "Container Registry Setup"

print_info "Setting registry region..."
ibmcloud cr region-set ${CURRENT_REGION:-us-south}

print_info "Logging in to Container Registry..."
ibmcloud cr login

print_info "Checking namespace..."
if ibmcloud cr namespace-list | grep -q "^${REGISTRY_NAMESPACE}$"; then
    print_success "Namespace exists"
else
    print_info "Creating namespace..."
    ibmcloud cr namespace-add ${REGISTRY_NAMESPACE}
    print_success "Namespace created"
fi

# Code Engine Project
print_header "Code Engine Project Setup"

print_info "Checking project..."
if ibmcloud ce project list 2>/dev/null | grep -q "${CE_PROJECT}"; then
    print_success "Project exists"
    ibmcloud ce project select --name ${CE_PROJECT}
else
    print_info "Creating project..."
    ibmcloud ce project create --name ${CE_PROJECT}
    ibmcloud ce project select --name ${CE_PROJECT}
    print_success "Project created"
fi

# Backend Deployment
print_header "Backend Deployment"

BACKEND_IMAGE="icr.io/${REGISTRY_NAMESPACE}/${BACKEND_APP}:v1"

print_info "Building backend image..."
cd backend
docker build -t ${BACKEND_IMAGE} .
print_success "Backend image built"

print_info "Pushing to registry..."
docker push ${BACKEND_IMAGE}
print_success "Backend image pushed"

print_info "Deploying backend (NO DATABASE)..."
if ibmcloud ce application list 2>/dev/null | grep -q "${BACKEND_APP}"; then
    print_warning "Updating existing backend..."
    ibmcloud ce application update \
        --name ${BACKEND_APP} \
        --image ${BACKEND_IMAGE}
else
    ibmcloud ce application create \
        --name ${BACKEND_APP} \
        --image ${BACKEND_IMAGE} \
        --port 8080 \
        --cpu 1 \
        --memory 2G \
        --min-scale 1 \
        --max-scale 3 \
        --env WATSONX_API_KEY="${WATSONX_API_KEY}" \
        --env WATSONX_PROJECT_ID="${WATSONX_PROJECT_ID}" \
        --env WATSONX_URL="${WATSONX_URL}" \
        --env ENVIRONMENT="production" \
        --env LOG_LEVEL="INFO" \
        --env VALIDATION_TEMP_DIR="/app/temp/cos_validation"
fi

print_success "Backend deployed"

print_info "Waiting for backend..."
sleep 15

# Get backend URL
BACKEND_URL=$(ibmcloud ce application get --name ${BACKEND_APP} --output json 2>/dev/null | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -z "$BACKEND_URL" ]; then
    print_error "Failed to get backend URL"
    print_info "Checking application status..."
    ibmcloud ce application get --name ${BACKEND_APP}
    exit 1
fi

print_success "Backend URL: ${BACKEND_URL}"

# Test backend
print_info "Testing backend health..."
for i in {1..5}; do
    if curl -f -s "${BACKEND_URL}/health" > /dev/null 2>&1; then
        print_success "Backend health check passed"
        break
    else
        if [ $i -eq 5 ]; then
            print_error "Backend health check failed after 5 attempts"
            print_info "Check logs: ibmcloud ce application logs --name ${BACKEND_APP}"
            exit 1
        fi
        print_warning "Attempt $i failed, retrying in 10s..."
        sleep 10
    fi
done

cd ..

# Frontend Deployment
print_header "Frontend Deployment"

FRONTEND_IMAGE="icr.io/${REGISTRY_NAMESPACE}/${FRONTEND_APP}:v1"

print_info "Building frontend with backend URL..."
cd frontend
docker build --build-arg VITE_API_URL=${BACKEND_URL} -t ${FRONTEND_IMAGE} .
print_success "Frontend image built"

print_info "Pushing to registry..."
docker push ${FRONTEND_IMAGE}
print_success "Frontend image pushed"

print_info "Deploying frontend..."
if ibmcloud ce application list 2>/dev/null | grep -q "${FRONTEND_APP}"; then
    print_warning "Updating existing frontend..."
    ibmcloud ce application update \
        --name ${FRONTEND_APP} \
        --image ${FRONTEND_IMAGE}
else
    ibmcloud ce application create \
        --name ${FRONTEND_APP} \
        --image ${FRONTEND_IMAGE} \
        --port 8080 \
        --cpu 0.5 \
        --memory 1G \
        --min-scale 1 \
        --max-scale 2
fi

print_success "Frontend deployed"

print_info "Waiting for frontend..."
sleep 10

# Get frontend URL
FRONTEND_URL=$(ibmcloud ce application get --name ${FRONTEND_APP} --output json 2>/dev/null | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -z "$FRONTEND_URL" ]; then
    print_error "Failed to get frontend URL"
    exit 1
fi

cd ..

# Success!
print_header "🎉 Deployment Complete!"

echo -e "${GREEN}Your application is now live!${NC}\n"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Frontend:  ${GREEN}${FRONTEND_URL}${NC}"
echo -e "  Backend:   ${GREEN}${BACKEND_URL}${NC}"
echo -e "  API Docs:  ${GREEN}${BACKEND_URL}/docs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "🌐 Open your application:"
echo -e "   ${BLUE}${FRONTEND_URL}${NC}"
echo
echo "📋 Useful Commands:"
echo "  Backend logs:  ibmcloud ce application logs --name ${BACKEND_APP} --follow"
echo "  Frontend logs: ibmcloud ce application logs --name ${FRONTEND_APP} --follow"
echo
print_success "Deployment completed successfully!"

# Made with Bob
