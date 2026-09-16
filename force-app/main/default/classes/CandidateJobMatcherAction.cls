public class CandidateJobMatcherAction {

    public class Request {
        @InvocableVariable(required=true label='Job ID')
        public Id jobId;

        @InvocableVariable(required=true label='Candidate IDs')
        public List<Id> candidateIds;
    }

    public class Response {
        @InvocableVariable(label='Job Name')
        public String jobName;

        @InvocableVariable(label='Job Applications')
        public List<Job_Application__c> jobApplications;
    }

    @InvocableMethod(label='Get Job and Applications Data' description='Retrieves the job name and related job application records for specified candidates.')
    public static List<Response> getCandidateJobData(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.jobApplications = new List<Job_Application__c>();

            // Query Job Name
            Job__c job = [SELECT Id, Name FROM Job__c WHERE Id = :req.jobId LIMIT 1];
            if (job != null) {
                res.jobName = job.Name;
            }

            // Query Job Applications for the given job and candidates
            if (req.candidateIds == null || req.candidateIds.isEmpty()) {
                res.jobApplications = [
                SELECT Id, Candidate__c, Job__c, IsBookmarked__c, Comment__c, Data__c , Score__c
                FROM Job_Application__c 
                WHERE Job__c = :req.jobId
                LIMIT 10
            ];
            }
            else{

                res.jobApplications = [
                SELECT Id, Candidate__c, Job__c, IsBookmarked__c, Comment__c, Data__c , Score__c
                FROM Job_Application__c 
                WHERE Job__c = :req.jobId 
                AND Candidate__c IN :req.candidateIds
                ];

            }
            

            results.add(res);
        }

        return results;
    }
}