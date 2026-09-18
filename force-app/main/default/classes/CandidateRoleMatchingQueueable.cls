public class CandidateRoleMatchingQueueable implements Queueable {

    private Set<Id> candidateIds;

    public CandidateRoleMatchingQueueable(Set<Id> candidateIds) {
        this.candidateIds = candidateIds;
    }

    public void execute(QueueableContext context) {

        // Get Candidates
        List<Candidate__c> candidates = [
            SELECT Id, Role__c
            FROM Candidate__c
            WHERE Id IN :candidateIds
        ];

        // if candidate has job application quit the execute 
        for (Candidate__c cand : candidates) {
            if ([SELECT COUNT() FROM Job_Application__c WHERE Candidate__c = :cand.Id] > 0) {
                return;
            }
        }


        // Group candidates by role
        Map<String, Set<Id>> roleToCandidateIds =
            new Map<String, Set<Id>>();

        Set<String> roles = new Set<String>();

        for (Candidate__c cand : candidates) {

            if (String.isBlank(cand.Role__c)) {
                continue;
            }

            String cleanRole = cand.Role__c.toLowerCase().trim();

            roles.add(cleanRole);

            if (!roleToCandidateIds.containsKey(cleanRole)) {
                roleToCandidateIds.put(
                    cleanRole,
                    new Set<Id>()
                );
            }

            roleToCandidateIds.get(cleanRole).add(cand.Id);
        }

        if (roles.isEmpty()) {
            return;
        }

        // Get Jobs using structured Role field
        List<Job__c> allJobs = [
            SELECT Id,
                   Role__c
            FROM Job__c
            WHERE Role__c IN :roles
        ];

        Map<Id, List<Id>> candidateToJobIdsMap =
            new Map<Id, List<Id>>();

        for (Job__c job : allJobs) {

            if (String.isBlank(job.Role__c)) {
                continue;
            }

            String cleanJobRole =
                job.Role__c.toLowerCase().trim();

            if (!roleToCandidateIds.containsKey(cleanJobRole)) {
                continue;
            }

            for (Id candidateId :
                 roleToCandidateIds.get(cleanJobRole)) {

                if (!candidateToJobIdsMap.containsKey(candidateId)) {
                    System.debug('Adding candidateId to candidateToJobIdsMap: ' + candidateId);
                    candidateToJobIdsMap.put(
                        candidateId,
                        new List<Id>()
                    );
                }

                candidateToJobIdsMap
                    .get(candidateId)
                    .add(job.Id);
            }
        }

        // Create scoring requests
        List<CandidateScoringInvocable.ScoringRequest> requests =
            new List<CandidateScoringInvocable.ScoringRequest>();

        for (Id candidateId : candidateToJobIdsMap.keySet()) {

            CandidateScoringInvocable.ScoringRequest req =
                new CandidateScoringInvocable.ScoringRequest();

            req.candidateIds = new List<Id>{ candidateId };
            req.jobIds = candidateToJobIdsMap.get(candidateId);

            requests.add(req);
        }

        // Start scoring
        if (!requests.isEmpty()) {

            System.enqueueJob(
                new NestedCandidateScoringQueueable(
                    requests,
                    0
                )
            );
        }
    }
}