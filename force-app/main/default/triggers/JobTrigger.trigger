trigger JobTrigger on Job__c (after insert, after update) {
    Set<Id> jobIds = new Set<Id>();
    for (Job__c job : Trigger.new) {
        // or assign new Job_Scoring_Config__c
        if (job.Description__c != null && (Trigger.isInsert || job.Description__c != Trigger.oldMap.get(job.Id).Description__c || job.Job_Scoring_Config__c != Trigger.oldMap.get(job.Id).Job_Scoring_Config__c)) {
            jobIds.add(job.Id);
        }
    }
    if (!jobIds.isEmpty()) {
        JobParserQueueable.enqueueJobParsing(jobIds);
    }
}