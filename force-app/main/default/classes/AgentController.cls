public with sharing class AgentController {

    public class SessionInitResponse {
        @AuraEnabled public String sessionId { get; set; }
        @AuraEnabled public String initialMessage { get; set; }
    }


    public class AgentRequestWrapper {
            @AuraEnabled public String userMessage { get; set; }
            @AuraEnabled public String agentApiName { get; set; }
            @AuraEnabled public String sessionId { get; set; }
            @AuraEnabled public List<String> contentDocumentIds { get; set; } // List for multiple files
        }

    public class AgentResponseWrapper {
        @AuraEnabled public String agentResponse { get; set; }
        @AuraEnabled public String sessionId { get; set; }
    }

    public class CandidateData {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public String role;
        public String summary;
        public List<skillData> skills;
        public List<WorkExperienceData> workExperience;
        public List<EducationData> education;
        public List<AchievementData> achievements;
    }

    public class skillData {
        public String name;
        public String description;
    }

    public class WorkExperienceData {
        public String company;
        public String jobTitle;
        public String startDate;
        public String endDate;
        public String description;
    }

    public class EducationData {
        public String institution;
        public String degree;
        public String fieldOfStudy;
        public String startDate;
        public String endDate;
    }

    public class AchievementData {
        public String name;
        public String issuingOrganization;
        public String issueDate;
    }


    @AuraEnabled
    public static SessionInitResponse startAgentSession(String agentApiName) {

        Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', agentApiName);
        action.setInvocationParameter('userMessage', 'Hello, start a new session');
        
        // action.setInvocationParameter('userEmaill', 'ali@test.com');
        // action.setInvocationParameter('password', '123');

    
        List<Invocable.Action.Result> results = action.invoke();

        if (!results.isEmpty() && results[0].isSuccess()) {
            String sessionId = (String) results[0].getOutputParameters().get('sessionId');
            String agentResponse = (String) results[0].getOutputParameters().get('agentResponse');
            
            System.debug('New Agent Session ID: ' + sessionId);
            System.debug('Agent Response: ' + agentResponse);
        } else {
            System.debug('Failed to invoke agent: ' + results[0].getErrors());
        }

        SessionInitResponse response = new SessionInitResponse();
        response.sessionId = (String) results[0].getOutputParameters().get('sessionId');
        response.initialMessage = (String) results[0].getOutputParameters().get('agentResponse');

        return response;

    }


    @AuraEnabled
    public static AgentResponseWrapper invokeAgentforce(AgentRequestWrapper request) {
        if (String.isBlank(request.agentApiName)) {
            throw new AuraHandledException('Agent API Name is required.');
        }

        AgentResponseWrapper response = new AgentResponseWrapper();

        try {
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                request.agentApiName
            );

            String payloadText = String.isNotBlank(request.userMessage) ? request.userMessage : 'Hello';
            action.setInvocationParameter('userMessage', payloadText);
            
            if (String.isNotBlank(request.sessionId)) {
                action.setInvocationParameter('sessionId', request.sessionId);
            }

        
            // Pass Document IDs
            if (request.contentDocumentIds != null && !request.contentDocumentIds.isEmpty()) {
                action.setInvocationParameter('contentDocId', request.contentDocumentIds);
            }
            

            List<Invocable.Action.Result> results = action.invoke();
            System.debug('Agentforce invocation results: ' + results);
            Invocable.Action.Result result = results[0];
            String agentResponse = (String) result.getOutputParameters().get('agentResponse');
            String rawAgentResponse = (String) result.getOutputParameters().get('agentResponse');

            if (String.isNotBlank(rawAgentResponse)) {
                if (rawAgentResponse.startsWith('{') && rawAgentResponse.contains('"value"')) {
                    try {
                        Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(rawAgentResponse);
                        response.agentResponse = (String) parsedJson.get('value');
                    } catch (Exception parseEx) {
                        response.agentResponse = rawAgentResponse;
                    }
                } else {
                    response.agentResponse = rawAgentResponse;
                }
            } else {
                response.agentResponse = 'No response text returned by Agentforce.';
            }


            response.sessionId = (String) result.getOutputParameters().get('sessionId');


        } catch (Exception e) {
            system.debug('Error invoking Agentforce: ' + e.getMessage());
            throw new AuraHandledException('Execution Exception: ' + e.getMessage());
        }

        return response;
    }
    /** 
    @AuraEnabled
    public static String sendMessageToAgent(ChatRequest request) {
        try {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            if (request.contentDocumentId != null) {
                Map<String, String> cdMap = new Map<String, String>();
                cdMap.put('id', request.contentDocumentId);
                
                ConnectApi.WrappedValue cdValue = new ConnectApi.WrappedValue();
                cdValue.value = cdMap;
                
                inputParams.put('Input:cv', cdValue);
            }

            if (String.isNotBlank(request.message)) {
                ConnectApi.WrappedValue textValue = new ConnectApi.WrappedValue();
                textValue.value = request.message;
                inputParams.put('Input:User_Input', textValue);
            }

            ConnectApi.EinsteinPromptTemplateGenerationsInput input = 
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.inputParams = inputParams;
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';
            input.isPreview = false;

            String templateName = String.isNotBlank(request.promptTemplateName) 
                ? request.promptTemplateName 
                : 'resumes_parser';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = 
                new ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(templateName, input);

            return output.generations[0].text;

        } catch (Exception e) {
            throw new AuraHandledException('Prompt Template Error: ' + e.getMessage());
        }
    }
        */


    @AuraEnabled
    public static Id saveCandidateFromJSON(String rawJsonResponse, Id contentDocumentId) {
        try {
            system.debug('Raw JSON Response: ' + rawJsonResponse);
            // Clean JSON string formatting if generated from LLM output
            String sanitizedJson = rawJsonResponse.replace('"lastName "', '"lastName"');
            CandidateData data = (CandidateData) JSON.deserialize(sanitizedJson, CandidateData.class);
            system.debug('Parsed Candidate Data: ' + data);
    
            
            // 1. Insert Parent Candidate Record
            Candidate__c candidate = new Candidate__c(
                First_Name__c = data.firstName,
                Last_Name__c = data.lastName,
                Email__c = data.email,
                Phone__c = data.phone,
                Summary__c = data.summary,
                role__c = data.role != null ? data.role : null,
                data__c = rawJsonResponse

            );
            insert candidate;

            // 2. Process Skills (Junction to Skill__c Catalog)
            if (data.skills != null && !data.skills.isEmpty()) {
                handleSkills(candidate.Id, data.skills);
            }

            // 3. Process Achievements (Junction to Achievement__c Catalog)
            if (data.achievements != null && !data.achievements.isEmpty()) {
                handleAchievements(candidate.Id, data.achievements);
            }

            // 4. Process Work Experience (Direct Lookup)
            if (data.workExperience != null && !data.workExperience.isEmpty()) {
                handleWorkExperience(candidate.Id, data.workExperience);
            }

            // 5. Process Education (Direct Lookup)
            if (data.education != null && !data.education.isEmpty()) {
                handleEducation(candidate.Id, data.education);
            }
            

            // 6. Link Resume Document (ContentDocumentLink)
            if (contentDocumentId != null) {
                insert new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = candidate.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
            }

            return candidate.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to process candidate JSON: ' + e.getMessage());
        }
    }

    // --- Helper Methods ---

    private static void handleSkills(Id candidateId, List<SkillData> skillList) {
        Set<String> uniqueNames = new Set<String>();
        Map<String, String> skillDescMap = new Map<String, String>();
        
        for (SkillData s : skillList) {
            if (String.isNotBlank(s.name)) {
                String trimmedName = s.name.trim();
                uniqueNames.add(trimmedName);
                skillDescMap.put(trimmedName.toLowerCase(), s.description);
            }
        }

        Map<String, Skill__c> existingSkills = new Map<String, Skill__c>();
        for (Skill__c sk : [SELECT Id, Name, Description__c FROM Skill__c WHERE Name IN :uniqueNames WITH USER_MODE]) {
            existingSkills.put(sk.Name.toLowerCase(), sk);
        }

        List<Skill__c> newSkills = new List<Skill__c>();
        for (String name : uniqueNames) {
            if (!existingSkills.containsKey(name.toLowerCase())) {
                newSkills.add(new Skill__c(
                    Name = name,
                    Description__c = skillDescMap.get(name.toLowerCase())
                ));
            }
        }
        
        if (!newSkills.isEmpty()) {
            insert newSkills;
            for (Skill__c sk : newSkills) {
                existingSkills.put(sk.Name.toLowerCase(), sk);
            }
        }

        List<Candidate_Skill__c> junctions = new List<Candidate_Skill__c>();
        for (String name : uniqueNames) {
            Skill__c sk = existingSkills.get(name.toLowerCase());
            if (sk != null) {
                junctions.add(new Candidate_Skill__c(
                    Candidate__c = candidateId,
                    Skill__c = sk.Id
                ));
            }
        }
        
        if (!junctions.isEmpty()) {
            insert junctions;
        }
    }



    private static void handleAchievements(Id candidateId, List<AchievementData> achievements) {
        Set<String> uniqueNames = new Set<String>();
        for (AchievementData ach : achievements) {
            if (String.isNotBlank(ach.name)) {
                uniqueNames.add(ach.name.trim());
            }
        }

        Map<String, Achievement__c> existingAchievements = new Map<String, Achievement__c>();
        for (Achievement__c ach : [SELECT Id, Name FROM Achievement__c WHERE Name IN :uniqueNames WITH USER_MODE]) {
            existingAchievements.put(ach.Name.toLowerCase(), ach);
        }

        List<Achievement__c> newAchievements = new List<Achievement__c>();
        for (String name : uniqueNames) {
            if (!existingAchievements.containsKey(name.toLowerCase())) {
                newAchievements.add(new Achievement__c(Name = name));
            }
        }
        if (!newAchievements.isEmpty()) {
            insert newAchievements;
            for (Achievement__c ach : newAchievements) {
                existingAchievements.put(ach.Name.toLowerCase(), ach);
            }
        }

        List<Candidate_Achievement__c> junctions = new List<Candidate_Achievement__c>();
        for (AchievementData ach : achievements) {
            if (String.isNotBlank(ach.name)) {
                Achievement__c targetAch = existingAchievements.get(ach.name.trim().toLowerCase());
                if (targetAch != null) {
                    junctions.add(new Candidate_Achievement__c(
                        Candidate__c = candidateId,
                        Achievement__c = targetAch.Id
                    ));
                }
            }
        }
        if (!junctions.isEmpty()) {
            insert junctions;
        }
    }

    private static void handleWorkExperience(Id candidateId, List<WorkExperienceData> workList) {
        List<Work_Experience__c> records = new List<Work_Experience__c>();
        for (WorkExperienceData w : workList) {
            records.add(new Work_Experience__c(
                Candidate__c = candidateId,
                Company__c = w.company,
                Job_Title__c = w.jobTitle,
                Start_Date__c = parseDate(w.startDate),
                End_Date__c = parseDate(w.endDate),
                Description__c = w.description
            ));
        }
        if (!records.isEmpty()) {
            insert records;
        }
    }

    private static void handleEducation(Id candidateId, List<EducationData> eduList) {
        List<Education__c> records = new List<Education__c>();
        for (EducationData e : eduList) {
            records.add(new Education__c(
                Candidate__c = candidateId,
                Institution__c = e.institution,
                Degree__c = e.degree,
                Field_of_Study__c = e.fieldOfStudy,
                Start_Date__c = parseDate(e.startDate),
                End_Date__c = parseDate(e.endDate)
            ));
        }
        if (!records.isEmpty()) {
            insert records;
        }
    }

    private static Date parseDate(String dateStr) {
        if (String.isNotBlank(dateStr) && dateStr.contains('/')) {
            List<String> parts = dateStr.split('/');
            if (parts.size() == 2) {
                Integer month = Integer.valueOf(parts[0]);
                Integer year = Integer.valueOf(parts[1]);
                return Date.newInstance(year, month, 1); // Defaults to the 1st of the month
            }
        }
        return null;
    }
}