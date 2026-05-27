/**
 * DocumentUpload Component
 * Handles document upload with drag-and-drop, validation, and management
 * Supports PDF, DOCX, and CSV files for model validation
 */

import React, { useState, useCallback } from 'react';
import {
  Box,
  Paper,
  Typography,
  Button,
  IconButton,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
  Chip,
  Alert,
  LinearProgress,
  Grid,
  Card,
  CardContent,
} from '@mui/material';
import {
  CloudUpload,
  Delete,
  Description,
  CheckCircle,
  Error as ErrorIcon,
  InsertDriveFile,
} from '@mui/icons-material';
import apiClient from '../services/api';

const API_BASE_URL = import.meta.env.VITE_API_URL || '';

// File type configurations
const ACCEPTED_FILE_TYPES = {
  'application/pdf': ['.pdf'],
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
  'text/csv': ['.csv'],
};

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

const DocumentUpload = ({ onDocumentsUploaded, onError }) => {
  const [files, setFiles] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({});
  const [dragActive, setDragActive] = useState(false);
  const [errors, setErrors] = useState([]);

  // Validate file
  const validateFile = (file) => {
    const errors = [];

    // Check file type
    const fileExtension = '.' + file.name.split('.').pop().toLowerCase();
    const acceptedExtensions = Object.values(ACCEPTED_FILE_TYPES).flat();
    
    if (!acceptedExtensions.includes(fileExtension)) {
      errors.push(`Invalid file type: ${file.name}. Only PDF, DOCX, and CSV files are allowed.`);
    }

    // Check file size
    if (file.size > MAX_FILE_SIZE) {
      errors.push(`File too large: ${file.name}. Maximum size is 10MB.`);
    }

    // Check if file already exists
    if (files.some(f => f.name === file.name)) {
      errors.push(`Duplicate file: ${file.name} is already uploaded.`);
    }

    return errors;
  };

  // Handle file selection
  const handleFileSelect = useCallback((selectedFiles) => {
    const newErrors = [];
    const validFiles = [];

    Array.from(selectedFiles).forEach(file => {
      const fileErrors = validateFile(file);
      if (fileErrors.length > 0) {
        newErrors.push(...fileErrors);
      } else {
        validFiles.push({
          file,
          name: file.name,
          size: file.size,
          type: file.type,
          status: 'pending',
          id: Date.now() + Math.random(),
        });
      }
    });

    if (newErrors.length > 0) {
      setErrors(newErrors);
      setTimeout(() => setErrors([]), 5000);
    }

    if (validFiles.length > 0) {
      setFiles(prev => [...prev, ...validFiles]);
    }
  }, [files]);

  // Handle drag events
  const handleDrag = useCallback((e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  }, []);

  // Handle drop
  const handleDrop = useCallback((e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      handleFileSelect(e.dataTransfer.files);
    }
  }, [handleFileSelect]);

  // Handle file input change
  const handleFileInputChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      handleFileSelect(e.target.files);
    }
  };

  // Upload files to backend
  const uploadFiles = async () => {
    if (files.length === 0) {
      setErrors(['No files to upload']);
      return;
    }

    setUploading(true);
    setErrors([]);

    try {
      const formData = new FormData();
      files.forEach(fileObj => {
        formData.append('files', fileObj.file);
      });

      const response = await apiClient.post(
        '/api/upload-documents',
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          onUploadProgress: (progressEvent) => {
            const percentCompleted = Math.round(
              (progressEvent.loaded * 100) / progressEvent.total
            );
            setUploadProgress({ overall: percentCompleted });
          },
        }
      );

      // DEBUG: Log upload response
      console.log('[DOCUPLOAD DEBUG] Upload response received:', response.data);
      console.log('[DOCUPLOAD DEBUG] Documents:', response.data.documents);
      console.log('[DOCUPLOAD DEBUG] Datasets:', response.data.datasets);

      // Update file statuses
      setFiles(prev =>
        prev.map(f => ({
          ...f,
          status: 'uploaded',
          uploadedData: response.data.documents?.find(d => d.filename === f.name),
        }))
      );

      if (onDocumentsUploaded) {
        // Backend returns 'documents' array, not 'files'
        onDocumentsUploaded(response.data.documents || [], response.data.datasets || null);
      }
    } catch (error) {
      const errorMessage = error.response?.data?.detail || 'Failed to upload files';
      setErrors([errorMessage]);
      
      if (onError) {
        onError(error);
      }

      // Mark files as failed
      setFiles(prev =>
        prev.map(f => ({
          ...f,
          status: 'failed',
        }))
      );
    } finally {
      setUploading(false);
      setUploadProgress({});
    }
  };

  // Remove file
  const removeFile = (fileId) => {
    setFiles(prev => prev.filter(f => f.id !== fileId));
  };

  // Clear all files
  const clearAll = () => {
    setFiles([]);
    setErrors([]);
    setUploadProgress({});
  };

  // Get file icon
  const getFileIcon = (filename) => {
    const ext = filename.split('.').pop().toLowerCase();
    if (ext === 'pdf') return <Description color="error" />;
    if (ext === 'docx') return <Description color="primary" />;
    if (ext === 'csv') return <InsertDriveFile color="success" />;
    return <InsertDriveFile />;
  };

  // Format file size
  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  };

  return (
    <Box>
      {/* Error Messages */}
      {errors.length > 0 && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErrors([])}>
          {errors.map((error, index) => (
            <div key={index}>{error}</div>
          ))}
        </Alert>
      )}

      {/* Drag and Drop Zone */}
      <Paper
        elevation={dragActive ? 8 : 2}
        sx={{
          p: 4,
          textAlign: 'center',
          border: dragActive ? '2px dashed #1976d2' : '2px dashed #ccc',
          backgroundColor: dragActive ? '#e3f2fd' : '#fafafa',
          cursor: 'pointer',
          transition: 'all 0.3s ease',
          mb: 3,
        }}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
        onClick={() => document.getElementById('file-input').click()}
      >
        <input
          id="file-input"
          type="file"
          multiple
          accept=".pdf,.docx,.csv"
          onChange={handleFileInputChange}
          style={{ display: 'none' }}
        />
        
        <CloudUpload sx={{ fontSize: 64, color: dragActive ? '#1976d2' : '#999', mb: 2 }} />
        
        <Typography variant="h6" gutterBottom>
          {dragActive ? 'Drop files here' : 'Drag & drop files here'}
        </Typography>
        
        <Typography variant="body2" color="text.secondary" paragraph>
          or click to browse
        </Typography>
        
        <Typography variant="caption" color="text.secondary">
          Supported formats: PDF, DOCX, CSV (Max 10MB per file)
        </Typography>
      </Paper>

      {/* File List */}
      {files.length > 0 && (
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
              <Typography variant="h6">
                Uploaded Files ({files.length})
              </Typography>
              <Button
                size="small"
                color="error"
                onClick={clearAll}
                disabled={uploading}
              >
                Clear All
              </Button>
            </Box>

            <List>
              {files.map((fileObj) => (
                <ListItem
                  key={fileObj.id}
                  sx={{
                    border: '1px solid #e0e0e0',
                    borderRadius: 1,
                    mb: 1,
                    backgroundColor: '#fff',
                  }}
                >
                  <Box sx={{ mr: 2 }}>
                    {getFileIcon(fileObj.name)}
                  </Box>
                  
                  <ListItemText
                    primary={fileObj.name}
                    secondary={
                      <Box>
                        <Typography variant="caption" display="block">
                          {formatFileSize(fileObj.size)}
                        </Typography>
                        {fileObj.uploadedData && (
                          <Typography variant="caption" color="text.secondary">
                            Uploaded: {new Date(fileObj.uploadedData.upload_time).toLocaleString()}
                          </Typography>
                        )}
                      </Box>
                    }
                  />
                  
                  <ListItemSecondaryAction>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                      {fileObj.status === 'uploaded' && (
                        <Chip
                          icon={<CheckCircle />}
                          label="Uploaded"
                          color="success"
                          size="small"
                        />
                      )}
                      {fileObj.status === 'failed' && (
                        <Chip
                          icon={<ErrorIcon />}
                          label="Failed"
                          color="error"
                          size="small"
                        />
                      )}
                      {fileObj.status === 'pending' && (
                        <Chip
                          label="Pending"
                          size="small"
                        />
                      )}
                      <IconButton
                        edge="end"
                        onClick={() => removeFile(fileObj.id)}
                        disabled={uploading}
                        size="small"
                      >
                        <Delete />
                      </IconButton>
                    </Box>
                  </ListItemSecondaryAction>
                </ListItem>
              ))}
            </List>

            {/* Upload Progress */}
            {uploading && uploadProgress.overall !== undefined && (
              <Box sx={{ mt: 2 }}>
                <Typography variant="body2" color="text.secondary" gutterBottom>
                  Uploading... {uploadProgress.overall}%
                </Typography>
                <LinearProgress variant="determinate" value={uploadProgress.overall} />
              </Box>
            )}

            {/* Upload Button */}
            <Box sx={{ mt: 2, display: 'flex', justifyContent: 'flex-end' }}>
              <Button
                variant="contained"
                startIcon={<CloudUpload />}
                onClick={uploadFiles}
                disabled={uploading || files.every(f => f.status === 'uploaded')}
              >
                {uploading ? 'Uploading...' : 'Upload Files'}
              </Button>
            </Box>
          </CardContent>
        </Card>
      )}

      {/* Upload Summary */}
      {files.length > 0 && (
        <Grid container spacing={2}>
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="subtitle2" color="text.secondary">
                  Total Files
                </Typography>
                <Typography variant="h4">{files.length}</Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="subtitle2" color="text.secondary">
                  Uploaded
                </Typography>
                <Typography variant="h4" color="success.main">
                  {files.filter(f => f.status === 'uploaded').length}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
          <Grid item xs={12} md={4}>
            <Card>
              <CardContent>
                <Typography variant="subtitle2" color="text.secondary">
                  Total Size
                </Typography>
                <Typography variant="h4">
                  {formatFileSize(files.reduce((sum, f) => sum + f.size, 0))}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        </Grid>
      )}
    </Box>
  );
};

export default DocumentUpload;

// Made with ❤️ by Bob

// Made with Bob
