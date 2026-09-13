public class CandidateRoleMatchingQueueable implements Queueable {
    private Set<Id> candidateIds;

    public CandidateRoleMatchingQueueable(Set<Id> candidateIds) {
        this.candidateIds = candidateIds;
    }

    public void execute(QueueableContext context) {
        List<Candidate__c> candidates = [
            SELECT Id, Data__c, role__c FROM Candidate__c WHERE Id IN :candidateIds
        ];

        Map<String, Set<Id>> roleToCandidateIds = new Map<String, Set<Id>>();
        Set<String> roles = new Set<String>();

        for (Candidate__c cand : candidates) {
            if (String.isBlank(cand.Data__c)) continue;
            Map<String, Object> candRoot = (Map<String, Object>) JSON.deserializeUntyped(cand.Data__c);
            Map<String, Object> candData = candRoot.containsKey('candidate') ? (Map<String, Object>) candRoot.get('candidate') : candRoot;
            // String role = (String) cand.Role__c;
            String role = (String) candData.get('role');

            if (String.isBlank(role)) continue;
            String cleanRole = role.toLowerCase().trim();
            roles.add(cleanRole);

            if (!roleToCandidateIds.containsKey(cleanRole)) {
                roleToCandidateIds.put(cleanRole, new Set<Id>());
            }
            roleToCandidateIds.get(cleanRole).add(cand.Id);
        }

        if (roles.isEmpty()) return;

        List<Job__c> allJobs = [SELECT Id, Data__c,role__c FROM Job__c where role__c IN :roles];
        Map<Id, List<Id>> candidateToJobIdsMap = new Map<Id, List<Id>>();

        for (Job__c job : allJobs) {
            Map<String, Object> jobRoot = (Map<String, Object>) JSON.deserializeUntyped(job.Data__c);
            Map<String, Object> jobData = jobRoot.containsKey('job') ? (Map<String, Object>) jobRoot.get('job') : jobRoot;
            String jobRole = (String) jobData.get('role');

            if (String.isBlank(jobRole)) continue;
            String cleanJobRole = jobRole.toLowerCase().trim();

            if (roleToCandidateIds.containsKey(cleanJobRole)) {
                for (Id candId : roleToCandidateIds.get(cleanJobRole)) {
                    if (!candidateToJobIdsMap.containsKey(candId)) {
                        candidateToJobIdsMap.put(candId, new List<Id>());
                    }
                    candidateToJobIdsMap.get(candId).add(job.Id);
                }
            }
        }

        List<CandidateScoringInvocable.ScoringRequest> requests = new List<CandidateScoringInvocable.ScoringRequest>();
        for (Id candId : candidateToJobIdsMap.keySet()) {
            CandidateScoringInvocable.ScoringRequest req = new CandidateScoringInvocable.ScoringRequest();
            req.candidateIds = new List<Id>{ candId };
            req.jobIds = candidateToJobIdsMap.get(candId);
            requests.add(req);
        }

        if (!requests.isEmpty()) {
            System.enqueueJob(new NestedCandidateScoringQueueable(requests, 0));
        }
    }
}