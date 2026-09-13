public with sharing class InvokeResumeParserPrompt {

    // Request Wrapper
    public class PromptRequest {
        @InvocableVariable(label='Content Document ID' description='Salesforce ContentDocumentId (069...) of the uploaded CV' required=true)
        public String contentDocumentId;

        @InvocableVariable(label='Prompt Template API Name' description='Developer name of the prompt template (Defaults to resumes_parser)' required=false)
        public String promptTemplateName;
    }

    // Response Wrapper
    public class PromptResponse {
        @InvocableVariable(label='Generated Response' description='Structured JSON response from Prompt Builder')
        public String agentResponse;

        @InvocableVariable(label='Is Success' description='True if generation succeeded')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message' description='Error details if execution failed')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Execute Resume Parser Prompt' 
        description='Invokes the Prompt Builder template using ContentDocument ID.'
        category='Agentforce'
    )
    public static List<PromptResponse> parseResumePrompt(List<PromptRequest> requests) {
        List<PromptResponse> responses = new List<PromptResponse>();

        for (PromptRequest req : requests) {
            PromptResponse res = new PromptResponse();
            try {
                if (String.isBlank(req.contentDocumentId)) {
                    res.isSuccess = false;
                    res.errorMessage = 'ContentDocument ID is required.';
                    responses.add(res);
                    continue;
                }

                Map<String, String> cdMap = new Map<String, String>();
                String targetDocumentId = req.contentDocumentId;
            
                if (req.contentDocumentId.startsWith('068')) {
                    List<ContentVersion> cvList = [ SELECT Id  FROM ContentVersion  WHERE id = :req.contentDocumentId 
                    AND IsLatest = true  LIMIT 1 ];
                    if (!cvList.isEmpty()) 
                        targetDocumentId = cvList[0].Id;
                }
                cdMap.put('id', targetDocumentId);
                ConnectApi.WrappedValue cdValue = new ConnectApi.WrappedValue();
                cdValue.value = cdMap;
                Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
                inputParams.put('Input:cv', cdValue);

                // Configure ConnectApi Payload
                ConnectApi.EinsteinPromptTemplateGenerationsInput input = 
                    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                input.inputParams = inputParams;
                input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
                input.additionalConfig.applicationName = 'PromptBuilderPreview';
                input.isPreview = false;

                String templateName = String.isNotBlank(req.promptTemplateName) 
                    ? req.promptTemplateName 
                    : 'resumes_parser';

                // Invoke ConnectApi
                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = 
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateName, input);

                if (output != null && output.generations != null && !output.generations.isEmpty()) {
                    String rawText = output.generations[0].text;

                    // Clean markdown code blocks if LLM wraps output in ```json ... ```
                    if (String.isNotBlank(rawText)) {
                        rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
                    }

                    res.agentResponse = rawText;
                    res.isSuccess = true;
                } else {
                    res.isSuccess = false;
                    res.errorMessage = 'No output returned from Prompt Builder.';
                }

            } catch (Exception e) {
                res.isSuccess = false;
                res.errorMessage = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Error in parseResumePrompt: ' + e.getMessage());
            }

            responses.add(res);
        }

        return responses;
    }
}