import { LightningElement, api, track } from 'lwc';
import startAgentSession from '@salesforce/apex/AgentController.startAgentSession';
import sendMessageToAgent from '@salesforce/apex/AgentController.invokeAgentforce';
import saveCandidateFromJSON from '@salesforce/apex/AgentController.saveCandidateFromJSON';
import parseResumeDirect from '@salesforce/apex/ResumeParserController.parseResumeDirect';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AgentChat extends LightningElement {
    @api recordId;
    @api agentId;
    @api agentApiName = 'resume_agent';
    @api promptTemplateName;

    @track attachedFiles = [];
    @track sessionId = null;
    @track userMessage = '';
    @track isThinking = false;
    @track isInitializing = true;
    @track isModalOpen = false;
    @track messages = [];

    acceptedFormats = ['.pdf', '.doc', '.docx', '.txt'];

    async connectedCallback() {
        await this.initSession();
    }

    async initSession() {
        const targetAgent = this.agentApiName || this.agentId;
        if (!targetAgent) {
            this.showToast('Configuration Error', 'No Agent API Name provided in App Builder.', 'error');
            this.isInitializing = false;
            return;
        }

        this.isThinking = true;
        try {
            const sessionData = await startAgentSession({ agentApiName: targetAgent });
            if (sessionData?.sessionId) {
                this.sessionId = sessionData.sessionId;
            }

            const greeting = sessionData?.initialMessage || 'Hello! How can I assist you today?';
            this.messages = [
                {
                    id: 'init-1',
                    sender: 'agent',
                    senderClass: 'message-row agent',
                    text: greeting,
                    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                }
            ];
        } catch (error) {
            this.showToast('Initialization Error', error?.body?.message || error?.message, 'error');
        } finally {
            this.isThinking = false;
            this.isInitializing = false;
            this.scrollToBottom();
        }
    }

    openUploadModal() {
        this.isModalOpen = true;
    }

    closeUploadModal() {
        this.isModalOpen = false;
    }

    get isAttachmentEmpty() {
    return !this.attachedFiles || this.attachedFiles.length === 0;
}

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            const newFiles = uploadedFiles.map(file => ({
                documentId: file.documentId,
                name: file.name
            }));

            this.attachedFiles = [...(this.attachedFiles || []), ...newFiles];

            this.showToast('Files Attached', `${uploadedFiles.length} file(s) attached successfully.`, 'success');
            this.closeUploadModal();
        }
    }

    removeAttachment(event) {
        const docIdToRemove = event.target.dataset.id;
        this.attachedFiles = this.attachedFiles.filter(f => f.documentId !== docIdToRemove);
    }

    handleInputChange(event) {
        this.userMessage = event.target.value;
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSend();
        }
    }

    async handleSend() {
    if (!this.userMessage.trim() && this.attachedFiles.length === 0) {
        console.warn('No message or attachments to send.');
        return;
    } 

    const messageText = this.userMessage;
    let documentIds = [];
    if (this.attachedFiles.length > 0) {
        documentIds = Array.from(new Set(this.attachedFiles.map(file => file.documentId)));
    }

    const primaryDocId = documentIds.length > 0 ? documentIds[0] : null;

    this.userMessage = '';
    this.messages = [
        ...this.messages,
        {
            id: Date.now().toString(),
            sender: 'user',
            senderClass: 'message-row user',
            text: messageText,
            attachments: [...this.attachedFiles],
            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        }
    ];

    this.isThinking = true;
    this.scrollToBottom();

    try {
        if (primaryDocId) {
            // Call Apex Prompt Parser when attachment exists
            const result = await parseResumeDirect({ contentDocumentId: primaryDocId });
            const response = typeof result === 'string' ? JSON.parse(result) : result;

            if (!response?.isSuccess || !response?.agentResponse) {
                throw new Error(response?.errorMessage || 'Failed to parse resume.');
            }

            const rawAgentJson = typeof response.agentResponse === 'string' 
                ? JSON.parse(response.agentResponse) 
                : response.agentResponse;

            const candidateData = rawAgentJson.candidate || rawAgentJson;
            console.log('Parsed Candidate Data:', candidateData);
            
            // if { "notAResume": true } is returned, show a warning toast and skip saving
            if (candidateData.notAResume) {
                this.showToast('Parsing Warning', 'The uploaded document does not appear to be a valid resume.', 'warning');
                return;
            }

            const saveResult = await this.autoSaveParsedCandidate(JSON.stringify(candidateData), primaryDocId);

            this.messages = [
                ...this.messages,
                {
                    id: (Date.now() + 1).toString(),
                    sender: 'agent',
                    senderClass: 'message-row agent',
                    text: 'Resume parsed and candidate profile saved successfully!',
                    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                }
            ];
        } else {
            // Call Chat Agent when no attachments exist
            const result = await sendMessageToAgent({
                request: {
                    userMessage: messageText,
                    agentApiName: this.agentApiName || this.agentId,
                    sessionId: this.sessionId,
                    contentDocumentIds: documentIds
                }
            });

            if (result?.sessionId) {
                this.sessionId = result.sessionId;
            }

            const agentText = result?.agentResponse || 'No response returned from Agentforce.';

            this.messages = [
                ...this.messages,
                {
                    id: (Date.now() + 1).toString(),
                    sender: 'agent',
                    senderClass: 'message-row agent',
                    text: agentText,
                    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                }
            ];
        }

        this.attachedFiles = [];

    } catch (error) {
        this.showToast('Error', error?.body?.message || error?.message, 'error');
    } finally {
        this.isThinking = false;
        this.scrollToBottom();
    }
}


    async autoSaveParsedCandidate(rawJson, documentId) {
        try {
            const candidateId = await saveCandidateFromJSON({
                rawJsonResponse: rawJson,
                contentDocumentId: documentId
            });
            this.showToast('Candidate Saved', `Candidate record created: ${candidateId}`, 'success');
        } catch (err) {
            this.showToast('Save Error', err?.body?.message || 'Failed to auto-create candidate record.', 'warning');
        }
    }

    isJsonString(str) {
        try {
            const parsed = JSON.parse(str);
            return typeof parsed === 'object' && parsed !== null;
        } catch (e) {
            return false;
        }
    }

    scrollToBottom() {
        window.requestAnimationFrame(() => {
            const chatBody = this.template.querySelector('.chat-body');
            if (chatBody) {
                chatBody.scrollTop = chatBody.scrollHeight;
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}