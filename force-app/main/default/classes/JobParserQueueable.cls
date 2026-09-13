public class JobParserQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> jobIds;

    public JobParserQueueable(Set<Id> jobIds) {
        this.jobIds = jobIds;
    }

    public static void enqueueJobParsing(Set<Id> jobIds) {
        System.enqueueJob(new JobParserQueueable(jobIds));
    }

    public void execute(QueueableContext context) {
        Set<Id> idsToChain = new Set<Id>(this.jobIds);
        List<Job__c> jobs = [SELECT Id, Description__c FROM Job__c WHERE Id IN :jobIds];
        List<Job__c> jobsToUpdate = new List<Job__c>();

        for (Job__c job : jobs) {
            try {
                Map<String, String> jobMap = new Map<String, String>();
                jobMap.put('id', job.Id);
                jobMap.put('description', job.Description__c);

                ConnectApi.WrappedValue jobVal = new ConnectApi.WrappedValue();
                jobVal.value = jobMap;
                
                Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
                inputParams.put('Input:Job_Id', jobVal);

                ConnectApi.EinsteinPromptTemplateGenerationsInput input = 
                    new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                input.inputParams = inputParams;
                input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
                input.additionalConfig.applicationName = 'PromptBuilderPreview';
                input.isPreview = false;

                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation genRep = 
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Summarize_Job', input);

                if (genRep != null && genRep.generations != null && !genRep.generations.isEmpty()) {
                    String jsonResponse = genRep.generations[0].text;
                    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
                    Map<String, Object> jobObj = (Map<String, Object>) root.get('job');
                    String extractedRole = jobObj != null ? (String) jobObj.get('role') : null;

                    jobsToUpdate.add(new Job__c(
                        Id = job.Id, 
                        Data__c = jsonResponse, 
                        Role__c = extractedRole
                    ));
                }
            } catch (Exception e) {
                System.debug('Error calling prompt template for job ' + job.Id + ': ' + e.getMessage());
            }
        }

        if (!jobsToUpdate.isEmpty()) {
            update jobsToUpdate;
        }

        // Chain the role matching queueable after parsing finishes
        if (!idsToChain.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new JobRoleMatchingQueueable(jobIds));
        }
    }
}