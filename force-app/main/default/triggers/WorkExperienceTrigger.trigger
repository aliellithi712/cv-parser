trigger WorkExperienceTrigger on Work_Experience__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    if (Trigger.isAfter) {

        if (Trigger.isDelete) {
            WorkExperienceTriggerHandler.updateCandidateExperience(
                null,
                Trigger.old
            );
        } else {
            WorkExperienceTriggerHandler.updateCandidateExperience(
                Trigger.new,
                Trigger.old
            );
        }

        if (!TriggerControl.runJunctionTrigger) {
            return;
        }

        // Call scoring/matching after experience update
        Set<Id> candidateIds = new Set<Id>();

        List<Work_Experience__c> records =
            Trigger.isDelete ? Trigger.old : Trigger.new;

        for (Work_Experience__c record : records) {
            if (record.Candidate__c != null) {
                candidateIds.add(record.Candidate__c);
            }
        }

        if (!candidateIds.isEmpty()) {
            System.enqueueJob(
                new CandidateRoleMatchingQueueable(candidateIds)
            );
        }
    }
}