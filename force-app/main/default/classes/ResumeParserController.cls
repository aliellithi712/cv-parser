public with sharing class ResumeParserController {

    @AuraEnabled
    public static String parseResumeDirect(String contentVersionId, String contentDocumentId) {
        InvokeResumeParserPrompt.PromptRequest req = new InvokeResumeParserPrompt.PromptRequest();
        req.contentDocumentId = String.isNotBlank(contentVersionId) ? contentVersionId : contentDocumentId;
        req.promptTemplateName = 'resumes_parser';

        List<InvokeResumeParserPrompt.PromptResponse> responses = 
            InvokeResumeParserPrompt.parseResumePrompt(new List<InvokeResumeParserPrompt.PromptRequest>{ req });
        
        if (!responses.isEmpty()) {
            system.debug('ResumeParserController.parseResumeDirect: Received response from InvokeResumeParserPrompt: ' + responses[0]);
            String serializedObj = JSON.serialize(responses[0]);
            Map<String, Object> untypedResponse = (Map<String, Object>) JSON.deserializeUntyped(serializedObj);
            return JSON.serialize(untypedResponse);
        } else {
            Map<String, Object> errMap = new Map<String, Object>{
                'isSuccess' => false,
                'errorMessage' => 'No response returned from parser Apex class.'
            };
            return JSON.serialize(errMap);
        }
    }
}