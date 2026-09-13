public class JobCandidateMatcherAction {

    public class Request {
        @InvocableVariable(label='Job ID' description='The ID of the selected job' required=true)
        public Id jobId;
    }

    public class CandidateInfo {
        @InvocableVariable(label='Applicant Name' description='Name of the candidate')
        public String candidateName;

        @InvocableVariable(label='Application Data' description='JSON data__c field containing score breakdown')
        public String candidateData;
    }

    public class Result {
        @InvocableVariable(label='Top Candidates' description='List of top 3 matching applications with names and scoring data')
        public List<CandidateInfo> candidates;
    }

    @InvocableMethod(label='Find Top Candidates for Job' description='Returns applicant name and data__c of the top 3 job applications matching the selected job by score.')
    public static List<Result> getTopCandidates(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        
        Id targetJobId = requests[0].jobId;
        
        List<Job_Application__c> topApplications = [
            SELECT Id, Name, Data__c, Score__c, Candidate__r.Name, Candidate__r.First_Name__c, Candidate__r.Last_Name__c
            FROM Job_Application__c  
            WHERE Job__c = :targetJobId 
            ORDER BY Score__c DESC 
            LIMIT 3
        ];
        
        List<CandidateInfo> candidateInfoList = new List<CandidateInfo>();
        for (Job_Application__c app : topApplications) {
            CandidateInfo info = new CandidateInfo();
            info.candidateName = (app.Candidate__r != null) ? app.Candidate__r.First_Name__c + ' ' + app.Candidate__r.Last_Name__c : 'Unknown';
            info.candidateData = app.Data__c;
            candidateInfoList.add(info);
        }
        
        Result res = new Result();
        res.candidates = candidateInfoList;
        results.add(res);
        
        return results;
    }
}