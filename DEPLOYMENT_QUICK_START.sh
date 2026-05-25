#!/bin/bash

###############################################################################
# IBM Cloud Code Engine Deployment Script
# Banking Model Validation System
# 
# This script automates the deployment process to IBM Cloud Code Engine
# 
# Prerequisites:
# - IBM Cloud CLI installed
# - Docker installed
# - Logged into IBM Cloud (ibmcloud login)
# - Code Engine and Container Registry plugins installed
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ${1}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$(echo -e ${BLUE}${prompt}${NC} [${default}]: )" input
    eval ${var_name}="${input:-$default}"
}

# Function to prompt for sensitive input (hidden)
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$(echo -e ${BLUE}${prompt}${NC}: )" input
    echo
    eval ${var_name}="${input}"
}

###############################################################################
# MAIN SCRIPT
###############################################################################

print_header "IBM Cloud Code Engine Deployment"
echo "Banking Model Validation System v2.0.0"
echo

# Check prerequisites
print_info "Checking prerequisites..."

if ! command_exists ibmcloud; then
    print_error "IBM Cloud CLI not found. Please install it first."
    exit 1
fi

if ! command_exists docker; then
    print_error "Docker not found. Please install Docker Desktop."
    exit 1
fi

print_success "Prerequisites check passed"

# Check if logged in to IBM Cloud
if ! ibmcloud target >/dev/null 2>&1; then
    print_warning "Not logged in to IBM Cloud"
    print_info "Please login now..."
    ibmcloud login --sso
fi

print_success "Logged in to IBM Cloud"

# Configuration
print_header "Configuration"

# Region
prompt_with_default "Select IBM Cloud region" "us-south" REGION
ibmcloud target -r ${REGION}

# Resource Group
prompt_with_default "Resource group name" "Default" RESOURCE_GROUP
ibmcloud target -g ${RESOURCE_GROUP}

# Container Registry Namespace
prompt_with_default "Container Registry namespace" "bankingvalidation" REGISTRY_NAMESPACE

# Code Engine Project
prompt_with_default "Code Engine project name" "banking-validation-ce" CE_PROJECT

# Application names
BACKEND_APP="banking-validation-backend"
FRONTEND_APP="banking-validation-frontend"

print_success "Configuration complete"

# Credentials
print_header "Credentials"

print_warning "You will need the following credentials:"
echo "  1. PostgreSQL connection string"
echo "  2. watsonx API key"
echo "  3. watsonx Project ID"
echo

read -p "$(echo -e ${BLUE}Do you have all credentials ready?${NC} [y/N]: )" ready
if [[ ! "$ready" =~ ^[Yy]$ ]]; then
    print_warning "Please gather your credentials and run this script again"
    exit 0
fi

prompt_secret "PostgreSQL connection string" POSTGRES_URL
prompt_secret "watsonx API key" WATSONX_API_KEY
prompt_with_default "watsonx Project ID" "" WATSONX_PROJECT_ID
prompt_with_default "watsonx URL" "https://us-south.ml.cloud.ibm.com" WATSONX_URL

print_success "Credentials collected"

# Container Registry Setup
print_header "Container Registry Setup"

print_info "Setting registry region..."
ibmcloud cr region-set ${REGION}

print_info "Logging in to Container Registry..."
ibmcloud cr login

print_info "Checking if namespace exists..."
if ibmcloud cr namespace-list | grep -q "^${REGISTRY_NAMESPACE}$"; then
    print_success "Namespace '${REGISTRY_NAMESPACE}' already exists"
else
    print_info "Creating namespace '${REGISTRY_NAMESPACE}'..."
    ibmcloud cr namespace-add ${REGISTRY_NAMESPACE}
    print_success "Namespace created"
fi

# Code Engine Project Setup
print_header "Code Engine Project Setup"

print_info "Checking if project exists..."
if ibmcloud ce project list | grep -q "${CE_PROJECT}"; then
    print_success "Project '${CE_PROJECT}' already exists"
    ibmcloud ce project select --name ${CE_PROJECT}
else
    print_info "Creating Code Engine project..."
    ibmcloud ce project create --name ${CE_PROJECT}
    ibmcloud ce project select --name ${CE_PROJECT}
    print_success "Project created and selected"
fi

# Backend Deployment
print_header "Backend Deployment"

BACKEND_IMAGE="icr.io/${REGISTRY_NAMESPACE}/${BACKEND_APP}:v1"

print_info "Building backend Docker image..."
cd backend
docker build -t ${BACKEND_IMAGE} .
print_success "Backend image built"

print_info "Pushing backend image to registry..."
docker push ${BACKEND_IMAGE}
print_success "Backend image pushed"

print_info "Deploying backend to Code Engine..."
if ibmcloud ce application list | grep -q "${BACKEND_APP}"; then
    print_warning "Backend app already exists, updating..."
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
        --env DATABASE_URL="${POSTGRES_URL}" \
        --env WATSONX_API_KEY="${WATSONX_API_KEY}" \
        --env WATSONX_PROJECT_ID="${WATSONX_PROJECT_ID}" \
        --env WATSONX_URL="${WATSONX_URL}" \
        --env ENVIRONMENT="production" \
        --env LOG_LEVEL="INFO" \
        --env VALIDATION_TEMP_DIR="/app/temp/cos_validation"
fi

print_success "Backend deployed"

print_info "Waiting for backend to be ready..."
sleep 10

# Get backend URL
BACKEND_URL=$(ibmcloud ce application get --name ${BACKEND_APP} --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -z "$BACKEND_URL" ]; then
    print_error "Failed to get backend URL"
    exit 1
fi

print_success "Backend URL: ${BACKEND_URL}"

# Test backend health
print_info "Testing backend health..."
if curl -f -s "${BACKEND_URL}/health" > /dev/null; then
    print_success "Backend health check passed"
else
    print_error "Backend health check failed"
    print_warning "Check logs: ibmcloud ce application logs --name ${BACKEND_APP}"
    exit 1
fi

cd ..

# Frontend Deployment
print_header "Frontend Deployment"

FRONTEND_IMAGE="icr.io/${REGISTRY_NAMESPACE}/${FRONTEND_APP}:v1"

print_info "Building frontend Docker image with backend URL..."
cd frontend
docker build --build-arg VITE_API_URL=${BACKEND_URL} -t ${FRONTEND_IMAGE} .
print_success "Frontend image built"

print_info "Pushing frontend image to registry..."
docker push ${FRONTEND_IMAGE}
print_success "Frontend image pushed"

print_info "Deploying frontend to Code Engine..."
if ibmcloud ce application list | grep -q "${FRONTEND_APP}"; then
    print_warning "Frontend app already exists, updating..."
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

print_info "Waiting for frontend to be ready..."
sleep 10

# Get frontend URL
FRONTEND_URL=$(ibmcloud ce application get --name ${FRONTEND_APP} --output json | grep -o '"url":"[^"]*' | cut -d'"' -f4)

if [ -z "$FRONTEND_URL" ]; then
    print_error "Failed to get frontend URL"
    exit 1
fi

cd ..

# Deployment Summary
print_header "Deployment Complete! 🎉"

echo -e "${GREEN}Your Banking Model Validation System is now live!${NC}\n"
echo "📊 Deployment Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Region:           ${BLUE}${REGION}${NC}"
echo -e "  Resource Group:   ${BLUE}${RESOURCE_GROUP}${NC}"
echo -e "  CE Project:       ${BLUE}${CE_PROJECT}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Backend URL:      ${GREEN}${BACKEND_URL}${NC}"
echo -e "  Frontend URL:     ${GREEN}${FRONTEND_URL}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "🌐 Access your application:"
echo -e "   ${BLUE}${FRONTEND_URL}${NC}"
echo
echo "📚 API Documentation:"
echo -e "   ${BLUE}${BACKEND_URL}/docs${NC}"
echo
echo "📋 Next Steps:"
echo "  1. Open the frontend URL in your browser"
echo "  2. Test a validation workflow"
echo "  3. Review the deployment guide for production recommendations"
echo "  4. Set up monitoring and alerts"
echo
echo "🔍 Useful Commands:"
echo "  View backend logs:  ibmcloud ce application logs --name ${BACKEND_APP} --follow"
echo "  View frontend logs: ibmcloud ce application logs --name ${FRONTEND_APP} --follow"
echo "  Update backend:     ibmcloud ce application update --name ${BACKEND_APP} --image <new-image>"
echo "  Update frontend:    ibmcloud ce application update --name ${FRONTEND_APP} --image <new-image>"
echo
print_success "Deployment script completed successfully!"

# Made with Bob
