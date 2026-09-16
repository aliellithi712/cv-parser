public class JobRoleMatchingQueueable implements Queueable {

    private Set<Id> jobIds;

    public JobRoleMatchingQueueable(Set<Id> jobIds) {
        this.jobIds = jobIds;
    }

    public void execute(QueueableContext context) {

        List<Job__c> jobs = [
            SELECT Id, Role__c
            FROM Job__c
            WHERE Id IN :jobIds
        ];

        Map<String, Set<Id>> roleToJobIds =
            new Map<String, Set<Id>>();

        Set<String> roles = new Set<String>();

        for (Job__c job : jobs) {

            if (String.isBlank(job.Role__c)) {
                continue;
            }

            String cleanRole =
                job.Role__c.toLowerCase().trim();

            roles.add(cleanRole);

            if (!roleToJobIds.containsKey(cleanRole)) {
                roleToJobIds.put(
                    cleanRole,
                    new Set<Id>()
                );
            }

            roleToJobIds.get(cleanRole).add(job.Id);
        }

        if (roles.isEmpty()) {
            return;
        }

        List<Candidate__c> candidates = [
            SELECT Id, Role__c
            FROM Candidate__c
            WHERE Role__c IN :roles
        ];

        Map<Id, List<Id>> jobToCandidateIds =
            new Map<Id, List<Id>>();

        for (Candidate__c candidate : candidates) {

            if (String.isBlank(candidate.Role__c)) {
                continue;
            }

            String cleanRole = candidate.Role__c.toLowerCase().trim();

            if (!roleToJobIds.containsKey(cleanRole)) {
                continue;
            }

            for (Id jobId : roleToJobIds.get(cleanRole)) {

                if (!jobToCandidateIds.containsKey(jobId)) {
                    jobToCandidateIds.put(
                        jobId,
                        new List<Id>()
                    );
                }

                jobToCandidateIds
                    .get(jobId)
                    .add(candidate.Id);
            }
        }

        // Pass ONLY IDs to scoring
        List<CandidateScoringInvocable.ScoringRequest> requests =
            new List<CandidateScoringInvocable.ScoringRequest>();

        for (Id jobId : jobToCandidateIds.keySet()) {

            CandidateScoringInvocable.ScoringRequest request =
                new CandidateScoringInvocable.ScoringRequest();

            request.jobIds = new List<Id>{ jobId };
            request.candidateIds = jobToCandidateIds.get(jobId);

            requests.add(request);
        }

        if (!requests.isEmpty()) {
            System.enqueueJob(
                new NestedJobScoringQueueable(
                    requests,
                    0
                )
            );
        }
    }
}