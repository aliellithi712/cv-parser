public with sharing class JobApplicantBookmarkAction {

    @InvocableMethod(label='Bookmark Job Applicant' description='Bookmarks a Job Applicant if not already bookmarked and adds an optional comment.' category='Job Applicant')
    public static List<Result> bookmarkApplicant(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Job_Application__c> applicantsToUpdate = new List<Job_Application__c>();
        
        Map<Id, Request> candidateIdToRequestMap = new Map<Id, Request>();
        for (Request req : requests) {
            candidateIdToRequestMap.put(req.candidateId, req);
        }

        // Query Job Applications related to the candidates
        Map<Id, Job_Application__c> appMap = new Map<Id, Job_Application__c>();
        for (Job_Application__c app : [
            SELECT Id, Candidate__c, IsBookmarked__c, Comment__c 
            FROM Job_Application__c 
            WHERE Candidate__c IN :candidateIdToRequestMap.keySet()
        ]) {
            appMap.put(app.Candidate__c, app);
        }

        for (Request req : requests) {
            Result res = new Result();
            Job_Application__c app = appMap.get(req.candidateId);

            if (app != null) {
                if (app.IsBookmarked__c == true) {
                    res.success = false;
                    res.message = 'This candidate is already bookmarked.';
                } else {
                    app.IsBookmarked__c = true;
                    if (req.comment != null) {
                        app.Comment__c = req.comment;
                    }
                    applicantsToUpdate.add(app);
                    
                    res.success = true;
                    res.message = 'Candidate successfully bookmarked.';
                }
            } else {
                res.success = false;
                res.message = 'Job application record not found for this candidate.';
            }
            results.add(res);
        }

        if (!applicantsToUpdate.isEmpty()) {
            update applicantsToUpdate;
        }

        return results;
    }

    public class Request {
        @InvocableVariable(required=true label='Candidate ID')
        public Id candidateId;

        @InvocableVariable(required=false label='Comment')
        public String comment;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }
}