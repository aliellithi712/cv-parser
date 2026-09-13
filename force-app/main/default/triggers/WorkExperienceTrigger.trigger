trigger WorkExperienceTrigger on Work_Experience__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        if (Trigger.isDelete) {
            WorkExperienceTriggerHandler.updateCandidateExperience(null, Trigger.old);
        } else {
            WorkExperienceTriggerHandler.updateCandidateExperience(Trigger.new, Trigger.old);
        }
    }
}