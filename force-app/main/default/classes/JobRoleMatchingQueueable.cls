public class JobRoleMatchingQueueable implements Queueable {
    private Set<Id> jobIds;

    public JobRoleMatchingQueueable(Set<Id> jobIds) {
        this.jobIds = jobIds;
    }

    public void execute(QueueableContext context) {
        List<Job__c> jobs = [
            SELECT Id, Data__c FROM Job__c WHERE Id IN :jobIds
        ];

        Map<String, Set<Id>> roleToJobIds = new Map<String, Set<Id>>();
        Set<String> roles = new Set<String>();

        for (Job__c job : jobs) {
            if (String.isBlank(job.Data__c)) continue;
            Map<String, Object> jobRoot = (Map<String, Object>) JSON.deserializeUntyped(job.Data__c);
            Map<String, Object> jobData = jobRoot.containsKey('job') ? (Map<String, Object>) jobRoot.get('job') : jobRoot;
            String role = (String) jobData.get('role');

            if (String.isBlank(role)) continue;
            String cleanRole = role.toLowerCase().trim();
            roles.add(cleanRole);

            if (!roleToJobIds.containsKey(cleanRole)) {
                roleToJobIds.put(cleanRole, new Set<Id>());
            }
            roleToJobIds.get(cleanRole).add(job.Id);
        }

        if (roles.isEmpty()) return;

        List<Candidate__c> allCandidates = [SELECT Id, Data__c,role__c FROM Candidate__c where role__c IN :roles];
        Map<Id, List<Id>> jobToCandidateIdsMap = new Map<Id, List<Id>>();

        for (Candidate__c cand : allCandidates) {
            Map<String, Object> candRoot = (Map<String, Object>) JSON.deserializeUntyped(cand.Data__c);
            Map<String, Object> candData = candRoot.containsKey('candidate') ? (Map<String, Object>) candRoot.get('candidate') : candRoot;
            String candRole = (String) candData.get('role');

            if (String.isBlank(candRole)) continue;
            String cleanCandRole = candRole.toLowerCase().trim();

            if (roleToJobIds.containsKey(cleanCandRole)) {
                for (Id jobId : roleToJobIds.get(cleanCandRole)) {
                    if (!jobToCandidateIdsMap.containsKey(jobId)) {
                        jobToCandidateIdsMap.put(jobId, new List<Id>());
                    }
                    jobToCandidateIdsMap.get(jobId).add(cand.Id);
                }
            }
        }

        List<CandidateScoringInvocable.ScoringRequest> requests = new List<CandidateScoringInvocable.ScoringRequest>();
        for (Id jobId : jobToCandidateIdsMap.keySet()) {
            CandidateScoringInvocable.ScoringRequest req = new CandidateScoringInvocable.ScoringRequest();
            req.jobIds = new List<Id>{ jobId };
            req.candidateIds = jobToCandidateIdsMap.get(jobId);
            requests.add(req);
        }

        if (!requests.isEmpty()) {
            System.enqueueJob(new NestedJobScoringQueueable(requests, 0));
        }
    }
}