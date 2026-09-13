public with sharing class CandidateDataService {

    public class CandidateRequest {
        @InvocableVariable
        public String searchName; // Searches First Name or Last Name
    }

    public class CandidateResponse {
        @InvocableVariable
        public String candidateName;

        @InvocableVariable
        public String candidateData;
    }

    @InvocableMethod(
        label='Get Candidate Data'
        description='Retrieves comprehensive candidate profile, skills, achievements and work experience in a single JSON structure.'
    )
    public static List<CandidateResponse> getCandidateData(
        List<CandidateRequest> requests
    ) {
        Set<String> searchPatterns = new Set<String>();

        for (CandidateRequest request : requests) {
            if (String.isNotBlank(request.searchName)) {
                searchPatterns.add('%' + request.searchName.trim() + '%');
            }
        }

        List<Candidate__c> candidateList = [
            SELECT Id, Name, Email__c, First_Name__c, Last_Name__c, Phone__c, Summary__c,Full_Name__c
            FROM Candidate__c
            WHERE First_Name__c LIKE :searchPatterns
               OR Last_Name__c LIKE :searchPatterns
               OR Full_Name__c LIKE :searchPatterns
        ];

        if (candidateList.isEmpty()) {
            return new List<CandidateResponse>();
        }

        Set<Id> candidateIds = new Set<Id>();
        Map<Id, Candidate__c> candidates = new Map<Id, Candidate__c>();
        
        for (Candidate__c c : candidateList) {
            candidateIds.add(c.Id);
            candidates.put(c.Id, c);
        }

        Map<Id, List<String>> candidateSkills = new Map<Id, List<String>>();
        for (Candidate_Skill__c cs : [
            SELECT Candidate__c, Skill__r.Name
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateSkills.containsKey(cs.Candidate__c)) {
                candidateSkills.put(cs.Candidate__c, new List<String>());
            }
            if (cs.Skill__r != null) {
                candidateSkills.get(cs.Candidate__c).add(cs.Skill__r.Name);
            }
        }

        Map<Id, List<String>> candidateAchievements = new Map<Id, List<String>>();
        for (Candidate_Achievement__c ca : [
            SELECT Candidate__c, Achievement__r.Name
            FROM Candidate_Achievement__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateAchievements.containsKey(ca.Candidate__c)) {
                candidateAchievements.put(ca.Candidate__c, new List<String>());
            }
            if (ca.Achievement__r != null) {
                candidateAchievements.get(ca.Candidate__c).add(ca.Achievement__r.Name);
            }
        }

        Map<Id, List<Map<String, Object>>> candidateExperience = new Map<Id, List<Map<String, Object>>>();
        for (Work_Experience__c work : [
            SELECT Candidate__c, Name, Job_Title__c, Company__c, Start_Date__c, End_Date__c, Description__c
            FROM Work_Experience__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateExperience.containsKey(work.Candidate__c)) {
                candidateExperience.put(work.Candidate__c, new List<Map<String, Object>>());
            }

            Map<String, Object> workMap = new Map<String, Object>();
            workMap.put('name', work.Name);
            workMap.put('jobTitle', work.Job_Title__c);
            workMap.put('company', work.Company__c);
            workMap.put('startDate', work.Start_Date__c);
            workMap.put('endDate', work.End_Date__c);
            workMap.put('description', work.Description__c);

            candidateExperience.get(work.Candidate__c).add(workMap);
        }

        List<CandidateResponse> responses = new List<CandidateResponse>();

        for (Id candidateId : candidateIds) {
            Candidate__c candidate = candidates.get(candidateId);

            Map<String, Object> data = new Map<String, Object>();
            data.put('candidateId', candidateId);
            data.put('candidateName', candidate != null ? candidate.Name : null);
            data.put('firstName', candidate != null ? candidate.First_Name__c : null);
            data.put('lastName', candidate != null ? candidate.Last_Name__c : null);
            data.put('email', candidate != null ? candidate.Email__c : null);
            data.put('phone', candidate != null ? candidate.Phone__c : null);
            data.put('summary', candidate != null ? candidate.Summary__c : null);

            data.put('skills', candidateSkills.containsKey(candidateId) ? candidateSkills.get(candidateId) : new List<String>());
            data.put('achievements', candidateAchievements.containsKey(candidateId) ? candidateAchievements.get(candidateId) : new List<String>());
            data.put('workExperience', candidateExperience.containsKey(candidateId) ? candidateExperience.get(candidateId) : new List<Map<String, Object>>());

            CandidateResponse response = new CandidateResponse();
            response.candidateName = candidate != null ? candidate.Name : null;
            response.candidateData = JSON.serialize(data);

            responses.add(response);
        }

        return responses;
    }
}