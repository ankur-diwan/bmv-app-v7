# 📄 Document Processing Logic - How Model Documentation is Used

## Overview
The system processes model documentation (DOCX, PDF) to enhance SR 11-7 compliance validation. Here's the complete flow:

---

## 🔄 Complete Document Processing Flow

### 1️⃣ **Document Upload** (`/api/upload-documents`)

**Location**: `backend/main_simple.py` (lines 1092-1151)

```python
@app.post("/api/upload-documents")
async def upload_documents(files: List[UploadFile] = File(...)):
```

**What Happens:**
1. User uploads files (CSV datasets + DOCX/PDF documentation)
2. Files are saved to `/tmp/` directory
3. System identifies file types:
   - **CSV files**: Categorized as `train`, `test`, or `oot` based on filename
   - **DOCX/PDF files**: Analyzed for SR 11-7 content

**Example Upload:**
```bash
curl -X POST http://localhost:8000/api/upload-documents \
  -F "files=@test_samples/successful_train.csv" \
  -F "files=@test_samples/successful_test.csv" \
  -F "files=@test_samples/successful_oot.csv" \
  -F "files=@test_samples/successful_model_documentation.docx"
```

**Response:**
```json
{
  "status": "success",
  "files_uploaded": 4,
  "documents": [
    {
      "filename": "successful_train.csv",
      "path": "/tmp/successful_train.csv",
      "type": "csv",
      "analysis": null
    },
    {
      "filename": "successful_model_documentation.docx",
      "path": "/tmp/successful_model_documentation.docx",
      "type": "document",
      "analysis": {
        "model_info": {...},
        "sr_11_7_sections": {...},
        "key_metrics": {...}
      }
    }
  ],
  "datasets": {
    "train": "/tmp/successful_train.csv",
    "test": "/tmp/successful_test.csv",
    "oot": "/tmp/successful_oot.csv"
  }
}
```

---

### 2️⃣ **Document Analysis** (`DocumentAnalyzer`)

**Location**: `backend/validation/document_analyzer.py` (lines 95-146)

**Key Method**: `analyze_document(file_path, file_type)`

#### What It Extracts:

##### A. **Text Extraction**
```python
# For DOCX files (lines 175-188)
def _extract_docx_text(self, file_path: str) -> str:
    doc = Document(file_path)
    text = ""
    for paragraph in doc.paragraphs:
        text += paragraph.text + "\n"
    return text
```

##### B. **Model Information** (lines 217-235)
Searches for patterns like:
- `model name: Application Scorecard v1`
- `model type: Logistic Regression`
- `scorecard type: Application`
- `product type: Unsecured Personal Loans`
- `version: 1.0`
- `developer: Model Risk Team`

**Example Extraction:**
```python
{
  "model_name": "Application Scorecard v1",
  "model_type": "Logistic Regression",
  "scorecard_type": "Application",
  "has_model_card": True,
  "has_validation_report": True,
  "has_performance_metrics": True
}
```

##### C. **SR 11-7 Section Detection** (lines 237-275)

Searches for 9 key sections:

| Section | Keywords Searched |
|---------|------------------|
| **Model Purpose** | "model purpose", "objective", "use case", "business purpose" |
| **Conceptual Soundness** | "conceptual soundness", "theoretical foundation", "methodology" |
| **Data Quality** | "data quality", "data source", "data validation" |
| **Performance** | "model performance", "accuracy", "discrimination", "ks statistic" |
| **Stability** | "stability", "psi", "csi", "drift" |
| **Assumptions** | "assumptions", "model assumptions", "sensitivity analysis" |
| **Implementation** | "implementation", "deployment", "production" |
| **Limitations** | "limitations", "model limitations", "constraints" |
| **Recommendations** | "recommendations", "conclusion", "findings" |

**Example Output:**
```python
{
  "sections": {
    "model_purpose": {
      "present": True,
      "keywords_found": ["model purpose", "objective", "use case"],
      "content_length": 450,
      "preview": "The model purpose is to predict..."
    },
    "conceptual_soundness": {
      "present": True,
      "keywords_found": ["methodology", "approach"],
      "content_length": 320,
      "preview": "The methodology follows..."
    },
    ...
  },
  "coverage": {
    "sections_present": 7,
    "total_sections": 9,
    "percentage": 77.8
  }
}
```

##### D. **Key Metrics Extraction** (lines 297-322)

Searches for performance metrics:
```python
metric_patterns = {
    "gini": r"gini[:\s]+([0-9.]+)",
    "ks": r"ks[:\s]+([0-9.]+)",
    "auc": r"auc[:\s]+([0-9.]+)",
    "accuracy": r"accuracy[:\s]+([0-9.]+)",
    "psi": r"psi[:\s]+([0-9.]+)",
    "csi": r"csi[:\s]+([0-9.]+)"
}
```

**Example:**
If document contains: "The model achieved a Gini coefficient of 0.65 and KS statistic of 0.45"

**Extracted:**
```python
{
  "gini": 0.65,
  "ks": 0.45
}
```

---

### 3️⃣ **SR 11-7 Compliance Scoring** (`ComplianceChecker`)

**Location**: `backend/validation/compliance_checker.py`

**How Documentation Affects Scoring:**

The compliance checker uses the document analysis to score 9 categories:

```python
def check_sr_11_7_compliance(self, model_config, validation_results, document_analysis):
    """
    Score each of 9 SR 11-7 categories based on:
    1. Document analysis (if available)
    2. Validation test results
    3. Model configuration
    """
```

#### Example: Category 1 - Model Purpose

**Without Documentation:**
```python
{
  "category": "Clear articulation of model purpose and use cases",
  "score": 5.0,
  "max_score": 15.0,
  "status": "failed",
  "checks": [
    {"check": "Model use cases defined", "passed": True, "message": "..."},
    {"check": "Model purpose and type documented", "passed": False, "message": "..."},
    {"check": "Business alignment validated", "passed": False, "message": "..."}
  ]
}
```

**With Documentation (containing "model purpose" section):**
```python
{
  "category": "Clear articulation of model purpose and use cases",
  "score": 12.0,
  "max_score": 15.0,
  "status": "passed",
  "checks": [
    {"check": "Model use cases defined", "passed": True, "message": "..."},
    {"check": "Model purpose and type documented", "passed": True, "message": "Found in documentation"},
    {"check": "Business alignment validated", "passed": True, "message": "Documented in section 1.2"}
  ]
}
```

---

### 4️⃣ **RAG System Enhancement** (Optional - Advanced)

**Location**: `backend/rag/document_rag.py`

**Purpose**: Use AI to understand documentation and answer questions

#### Key Features:

##### A. **Document Ingestion** (lines 73-144)
```python
async def ingest_document(document_id, document_path, document_type):
    # 1. Extract content
    content = await _extract_docx_content(document_path)

    # 2. Parse into chunks
    chunks = await _parse_content(content, document_id)

    # 3. Generate embeddings (using watsonx.ai)
    for chunk in chunks:
        embedding = await _generate_embedding(chunk.content)
        chunk.embedding = embedding

    # 4. Store in vector database
    self.chunks[chunk.chunk_id] = chunk
```

##### B. **Content Type Detection** (lines 212-231)
Identifies different content types:
- **Text**: Regular paragraphs
- **Equations**: LaTeX formulas (`$$`, `\begin{equation}`)
- **Tables**: Markdown/HTML tables
- **Code**: Code blocks (```)
- **Diagrams**: References to figures/charts

##### C. **Retrieval** (lines 250-292)
```python
async def retrieve_relevant_chunks(query, top_k=5):
    # 1. Generate query embedding
    query_embedding = await _generate_embedding(query)

    # 2. Calculate similarity with all chunks
    for chunk in chunks:
        similarity = cosine_similarity(query_embedding, chunk.embedding)

    # 3. Return top-k most similar chunks
    return top_chunks
```

##### D. **Answer Generation** (lines 310-348)
```python
async def generate_answer(question, context_chunks):
    # 1. Prepare context from chunks
    context = _prepare_context(context_chunks)

    # 2. Create RAG prompt
    prompt = f"""
    Context: {context}
    Question: {question}
    Answer based on context:
    """

    # 3. Generate using watsonx.ai
    answer = await watsonx.generate(prompt)

    return answer
```

---

## 🎯 Practical Example: Complete Flow

### Scenario: Validating an Application Scorecard

#### Step 1: Prepare Files
```
test_samples/
├── successful_train.csv          (2000 rows)
├── successful_test.csv           (1000 rows)
├── successful_oot.csv            (600 rows)
└── successful_model_documentation.docx
```

#### Step 2: Upload Documents
```bash
curl -X POST http://localhost:8000/api/upload-documents \
  -F "files=@test_samples/successful_train.csv" \
  -F "files=@test_samples/successful_test.csv" \
  -F "files=@test_samples/successful_oot.csv" \
  -F "files=@test_samples/successful_model_documentation.docx"
```

**Backend Processing:**
1. Saves files to `/tmp/`
2. Identifies CSV datasets: `train`, `test`, `oot`
3. Analyzes DOCX file:
   - Extracts text from all paragraphs
   - Searches for SR 11-7 keywords
   - Extracts model information
   - Finds performance metrics

#### Step 3: Start Validation
```bash
curl -X POST http://localhost:8000/api/validate \
  -H "Content-Type: application/json" \
  -d '{
    "model_config": {
      "model_name": "Application Scorecard v1",
      "model_type": "logistic_regression",
      "scorecard_type": "application",
      "product_type": "unsecured_personal_loans"
    },
    "uploaded_files": {
      "datasets": {
        "train": "/tmp/successful_train.csv",
        "test": "/tmp/successful_test.csv",
        "oot": "/tmp/successful_oot.csv"
      }
    }
  }'
```

**Backend Processing:**
1. Loads CSV files from paths
2. Runs statistical tests (KS, Gini, PSI, CSI)
3. Validates performance metrics
4. Checks SR 11-7 compliance using:
   - Document analysis results
   - Validation test results
   - Model configuration

#### Step 4: View Results

**SR 11-7 Compliance Section:**
```json
{
  "sr_11_7_compliance": {
    "overall_score": 82.5,
    "max_score": 100,
    "percentage": 82.5,
    "status": "passed",
    "categories": [
      {
        "category": "Clear articulation of model purpose",
        "score": 12.0,
        "max_score": 15.0,
        "status": "passed",
        "reason_summary": "Passed: All 3 checks completed successfully",
        "checks": [
          {
            "check": "Model use cases defined",
            "passed": true,
            "message": "Model use cases documented in section 1.1"
          },
          {
            "check": "Model purpose and type documented",
            "passed": true,
            "message": "Found in documentation: Application Scorecard for credit risk"
          },
          {
            "check": "Business alignment validated",
            "passed": true,
            "message": "Business objectives documented in section 1.3"
          }
        ]
      },
      ...
    ]
  }
}
```

---

## 📊 Impact of Documentation on Scoring

### Without Documentation:
- **Score**: ~45-55% (based only on test results)
- **Status**: Many "failed" or "partial" categories
- **Reason**: Missing evidence of documentation, assumptions, limitations

### With Complete Documentation:
- **Score**: ~75-90% (test results + documented evidence)
- **Status**: Most categories "passed"
- **Reason**: Evidence found in documentation for all SR 11-7 requirements

---

## 🔍 What the System Looks For in Documentation

### ✅ Good Documentation Should Include:

1. **Model Purpose** (Section 1)
   - Clear statement of model objective
   - Intended use cases
   - Business alignment

2. **Conceptual Soundness** (Section 2)
   - Methodology description
   - Theoretical foundation
   - Algorithm explanation

3. **Data Quality** (Section 3)
   - Data sources
   - Data validation procedures
   - Sample size justification

4. **Performance** (Section 4)
   - Metrics: KS, Gini, AUC, Accuracy
   - Benchmark comparisons
   - Performance thresholds

5. **Stability** (Section 5)
   - PSI/CSI analysis
   - Drift monitoring plan
   - Retraining triggers

6. **Assumptions** (Section 6)
   - Key model assumptions
   - Assumption testing
   - Sensitivity analysis

7. **Implementation** (Section 7)
   - Deployment plan
   - System integration
   - Operational procedures

8. **Limitations** (Section 8)
   - Known limitations
   - Edge cases
   - Constraints

9. **Recommendations** (Section 9)
   - Validation findings
   - Recommendations
   - Next steps

---

## 💡 Tips for Best Results

1. **Use Clear Section Headers**: "Model Purpose", "Data Quality", etc.
2. **Include Keywords**: Use SR 11-7 terminology
3. **Document Metrics**: Include actual numbers (Gini: 0.65)
4. **Be Comprehensive**: Cover all 9 categories
5. **Use Tables**: For metrics, thresholds, test results
6. **Include Dates**: Model version, validation date, data periods

---

## 🚀 Try It Yourself!

1. Open the sample documentation:
   ```bash
   open test_samples/successful_model_documentation.docx
   ```

2. Upload it with your datasets:
   ```bash
   curl -X POST http://localhost:8000/api/upload-documents \
     -F "files=@test_samples/successful_model_documentation.docx"
   ```

3. Run validation and see improved SR 11-7 scores!

---

**Built with ❤️ using IBM watsonx and FastAPI**