
public class AvailableJobsAction {
    public class Request {
        @InvocableVariable(label='Search Filter' description='Optional filter to search jobs by keyword' required=false)
        public String searchFilter;
    }

    @InvocableMethod(label='List Jobs' description='Returns a list of open job records.')
    public static List<List<Job__c>> getJobs(List<Request> requests) {

        if (requests == null || requests.isEmpty() || String.isBlank(requests[0].searchFilter)) {
            List<Job__c> jobs = [
                SELECT Id, Name, Description__c, Role__c, Data__c
                FROM Job__c
                LIMIT 50
            ];
            return new List<List<Job__c>>{ jobs };
        }
        else{
            String searchFilter = requests[0].searchFilter;
            List<Job__c> jobs = [
                SELECT Id, Name, Description__c, Role__c, Data__c
                FROM Job__c
                WHERE Name LIKE :('%' + searchFilter + '%')
                LIMIT 50
            ];
            return new List<List<Job__c>>{ jobs };
        }
    }
}