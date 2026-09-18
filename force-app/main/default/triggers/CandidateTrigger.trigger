trigger CandidateTrigger on Candidate__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        Set<Id> candidateIds = new Set<Id>();
        for (Candidate__c cand : Trigger.new) {
            candidateIds.add(cand.Id);
        }
        TriggerControl.runJunctionTrigger = false;
        System.enqueueJob(new CandidateRoleMatchingQueueable(candidateIds));
    }
}