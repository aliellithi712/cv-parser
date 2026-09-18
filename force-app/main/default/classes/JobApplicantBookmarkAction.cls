public with sharing class JobApplicantBookmarkAction {

    @InvocableMethod(label='Manage Job Applicant Bookmark' description='Checks, bookmarks, or updates comments for Job Applicants.')
    public static List<Result> manageBookmark(List<Request> requests) {
        List<Result> results = new List<Result>();
        Map<Id, Request> candidateIdToRequestMap = new Map<Id, Request>();
        for (Request req : requests) {
            candidateIdToRequestMap.put(req.candidateId, req);
        }

        Map<Id, Job_Application__c> appMap = new Map<Id, Job_Application__c>();
        for (Job_Application__c app : [
            SELECT Id, Candidate__c, IsBookmarked__c, Comment__c 
            FROM Job_Application__c 
            WHERE Candidate__c IN :candidateIdToRequestMap.keySet()
        ]) {
            appMap.put(app.Candidate__c, app);
        }

        List<Job_Application__c> appsToUpdate = new List<Job_Application__c>();

        for (Request req : requests) {
            Result res = new Result();
            Job_Application__c app = appMap.get(req.candidateId);

            if (app == null) {
                res.success = false;
                res.message = 'Job application record not found.';
                results.add(res);
                continue;
            }

            res.isBookmarked = app.IsBookmarked__c;
            String action = req.action != null ? req.action.toLowerCase() : 'bookmark';

            if (action == 'check') {
                res.success = true;
                res.message = 'Status checked successfully.';
            } else if (action == 'bookmark') {
                app.IsBookmarked__c = true;
                if (req.comment != null) {
                    app.Comment__c = req.comment;
                }
                appsToUpdate.add(app);
                res.success = true;
                res.message = 'Candidate successfully bookmarked.';
                res.isBookmarked = true;
            } else if (action == 'updatecomment') {
                if (req.comment != null) {
                    app.Comment__c = req.comment;
                    appsToUpdate.add(app);
                    res.success = true;
                    res.message = 'Comment updated successfully.';
                } else {
                    res.success = false;
                    res.message = 'Comment is required for update.';
                }
            }
            results.add(res);
        }

        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
        }

        return results;
    }

    public class Request {
        @InvocableVariable(required=true label='Candidate ID')
        public Id candidateId;

        @InvocableVariable(required=false label='Action (Check, Bookmark, UpdateComment)')
        public String action;

        @InvocableVariable(required=false label='Comment')
        public String comment;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Is Bookmarked')
        public Boolean isBookmarked;
    }
}