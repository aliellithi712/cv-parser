trigger CandidateSkillTrigger on Candidate_Skill__c (
    after insert,
    after update,
    after delete,
    after undelete
) {

    if (!TriggerControl.runJunctionTrigger) {
        return;
    }

    Set<Id> candidateIds = new Set<Id>();

    if (Trigger.isDelete) {
        for (Candidate_Skill__c record : Trigger.old) {
            if (record.Candidate__c != null) {
                candidateIds.add(record.Candidate__c);
            }
        }
    } else {
        for (Candidate_Skill__c record : Trigger.new) {
            if (record.Candidate__c != null) {
                candidateIds.add(record.Candidate__c);
            }
        }
    }

    if (!candidateIds.isEmpty()) {
        System.enqueueJob(
            new CandidateRoleMatchingQueueable(candidateIds)
        );
    }
}