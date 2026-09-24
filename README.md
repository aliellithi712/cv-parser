# **Resume Agent**

## **Summary**

Resume Agent is a Salesforce and Agentforce-powered recruitment solution that can ingest and analyze resumes, extract candidate information, compare multiple candidates, evaluate their suitability against specific job requirements, and bookmark candidates for future reference.

The agent helps recruiters identify candidates that match the requirements of a given job based on skills, experience, education, achievements, and other relevant resume information.

This repository utilizes a React and Express application to parse resumes, forward them to the current parser, and process the results using the CandidateDataGraphBatch Apex class.
* **GitHub Repository:** [cv-parser-datacloud](https://github.com/aliellithi712/cv-parser-datacloud)

## **Architecture Overview**

The Resume Agent is built using Salesforce, Agentforce, LWC, Apex, and Salesforce custom objects.

### **High-Level Flow**

| Step | Component | Responsibility |
|------|-----------|----------------|
| 1 | **Recruiter** | Interacts with the Resume Agent |
| 2 | **Resume Agent LWC** | Provides the UI and initializes the Agentforce session |
| 3 | **Agentforce Session** | Maintains the conversation context |
| 4 | **Agentforce Agent** | Understands recruiter requests and orchestrates actions |
| 5 | **Apex Actions** | Retrieves and processes Salesforce data |
| 6 | **Salesforce Data** | Stores candidates, jobs, skills, achievements, education, and experience |
| 7 | **Matching & Scoring** | Matches candidates against job requirements and calculates scores |
| 8 | **Job Application** | Provides access to candidate-job matching and scoring results |
| 9 | **Agentforce Response** | Returns the retrieved results to the recruiter |

### **Main Components**

- **LWC** – Provides the recruiter interface, initializes the Agentforce session, and manages resume uploads.

- **Agentforce** – Handles recruiter requests, analyzes candidate information, and coordinates the required actions.

- **Apex** – Manages candidate and job data retrieval, candidate matching, scoring logic, and asynchronous processing through Queueable Apex.

- **Apex Triggers** – Automatically initiate candidate matching and score recalculation when relevant candidate, skill, achievement, education, or work experience records are created or updated.

- **Salesforce Objects** – Store candidates, skills, achievements, education, work experience, jobs, and job applications, including candidate scores and evaluation details.

- **Permission Sets** – Provide the required permissions and access to the Resume Agent components, Salesforce objects, fields, Apex classes, and Agentforce functionality.

### **Data Model and Candidate Card Design**

Candidate information is stored using structured Salesforce objects rather than a single JSON field.

The Candidate Card is built from the following Salesforce objects:

- **Candidate** – Stores basic candidate information, role, contact details, and total experience.
- **Candidate Skill** – Stores skills associated with the candidate.
- **Candidate Achievement** – Stores achievements and certifications associated with the candidate.
- **Education** – Stores the candidate's educational background.
- **Work Experience** – Stores the candidate's professional experience.
- **Job** – Stores available job roles and their requirements.
- **Job Application** – Stores the candidate's job application, score, and evaluation results.
- **Job Scoring Config** – Defines the scoring criteria and weights used to evaluate candidates against a job, including skill, achievement, experience, and education weights.


### **Key Design Decisions and Trade-offs**

- **Role-Based Matching** – The Role__c field on Candidate and Job is used to determine which candidates should be matched to each job.


- **Structured Candidate Data** – Candidate information is stored in structured Salesforce objects and relationships instead of relying on a single JSON field.

- **Prompt Template for Resume Extraction** – Prompt Templates are used to extract structured information from uploaded resumes. The Agentforce agent is not invoked for resume extraction to make the process more deterministic and avoid unnecessary agent reasoning.

- **Apex for Deterministic Processing** – Candidate matching and scoring are handled by Apex to ensure consistent and repeatable results.

- **Configurable Scoring Criteria** – Job Scoring Config allows the scoring criteria and weights to be configured per job, making the scoring process flexible without changing the Apex scoring logic.

- **Job Requirements from Description** – Job requirements are provided as natural-language job descriptions. A Prompt Template converts the description into structured JSON and stores it in a field on the Job record. it introduces a trade-off because the extracted structure may be less deterministic than manually maintained structured fields.


- **Queueable Apex** – Queueable Apex is used to process matching and scoring asynchronously and avoid performing resource-intensive operations directly within triggers.

### **Known Limitations**


- **Model Context and Memorization** – The agent relies on the model to retain relevant context, including candidate names, job names, and record IDs, during a conversation. The model may not always reliably memorize or reuse these values in later turns, which can affect Apex actions that require specific record references.

### **Testing Approach**

- **Regression Testing** – Re-run a defined set of test scenarios after changes to prompts, Agentforce configuration, Apex actions, or scoring logic to ensure existing functionality continues to work.

- **End-to-End Testing** – Test the complete recruitment workflow from resume upload and data extraction through candidate creation, job matching, scoring, and the final Agentforce response.