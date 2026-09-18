public with sharing class CandidateDataService {

    public class CandidateRequest {
        @InvocableVariable
        public String searchName;
    }

    public class CandidateResponse {
        @InvocableVariable
        public String candidateHyperlink; // Preformatted Markdown link for Agentforce

        @InvocableVariable
        public Id candidateId;

        @InvocableVariable
        public String candidateName;

        @InvocableVariable
        public String role;

        @InvocableVariable
        public Decimal experienceYears;

        @InvocableVariable
        public List<String> skills;

        @InvocableVariable
        public List<String> achievements;

        @InvocableVariable
        public List<String> education;

        @InvocableVariable
        public List<String> workExperience;
    }

    @InvocableMethod(
        label='Get Candidate Data'
        description='Retrieves structured candidate information including skills, achievements, education, and work experience.'
    )
    public static List<CandidateResponse> getCandidateData(
        List<CandidateRequest> requests
    ) {

        Set<String> searchNames = new Set<String>();

        for (CandidateRequest request : requests) {
            if (String.isNotBlank(request.searchName)) {
                searchNames.add(request.searchName.trim());
            }
        }

        if (searchNames.isEmpty()) {
            return new List<CandidateResponse>();
        }

        // Candidates
        List<Candidate__c> candidates = [
            SELECT Id,
                   Name,
                   First_Name__c,
                   Last_Name__c,
                   Full_Name__c,
                   Role__c,
                   Experience_Years__c
            FROM Candidate__c
            WHERE First_Name__c IN :searchNames
               OR Last_Name__c IN :searchNames
               OR Full_Name__c IN :searchNames
        ];

        if (candidates.isEmpty()) {
            return new List<CandidateResponse>();
        }

        Set<Id> candidateIds = new Set<Id>();

        for (Candidate__c candidate : candidates) {
            candidateIds.add(candidate.Id);
        }

        // Skills
        Map<Id, List<String>> candidateSkills =
            new Map<Id, List<String>>();

        for (Candidate_Skill__c record : [
            SELECT Candidate__c,
                   Skill__c,
                   Skill__r.Name
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateSkills.containsKey(record.Candidate__c)) {
                candidateSkills.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            if (record.Skill__r != null) {
                candidateSkills
                    .get(record.Candidate__c)
                    .add(record.Skill__r.Name);
            }
        }

        // Achievements
        Map<Id, List<String>> candidateAchievements =
            new Map<Id, List<String>>();

        for (Candidate_Achievement__c record : [
            SELECT Candidate__c,
                   Achievement__c,
                   Achievement__r.Name
            FROM Candidate_Achievement__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateAchievements.containsKey(record.Candidate__c)) {
                candidateAchievements.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            if (record.Achievement__r != null) {
                candidateAchievements
                    .get(record.Candidate__c)
                    .add(record.Achievement__r.Name);
            }
        }

        // Education
        Map<Id, List<String>> candidateEducation =
            new Map<Id, List<String>>();

        for (Education__c record : [
            SELECT Candidate__c,
                   Degree__c,
                   Field_of_Study__c,
                   Institution__c,
                   Start_Date__c,
                   End_Date__c
            FROM Education__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateEducation.containsKey(record.Candidate__c)) {
                candidateEducation.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            String educationText = '';

            if (String.isNotBlank(record.Degree__c)) {
                educationText += record.Degree__c;
            }

            if (String.isNotBlank(record.Field_of_Study__c)) {
                if (educationText != '') {
                    educationText += ' - ';
                }
                educationText += record.Field_of_Study__c;
            }

            if (String.isNotBlank(record.Institution__c)) {
                if (educationText != '') {
                    educationText += ' - ';
                }
                educationText += record.Institution__c;
            }

            if (record.Start_Date__c != null) {
                if (educationText != '') {
                    educationText += ' - ';
                }
                educationText += record.Start_Date__c.format();
            }

            if (record.End_Date__c != null) {
                if (educationText != '') {
                    educationText += ' - ';
                }
                educationText += record.End_Date__c.format();
            }

            if (educationText != '') {
                candidateEducation
                    .get(record.Candidate__c)
                    .add(educationText);
            }
        }

        // Work Experience
        Map<Id, List<String>> candidateWorkExperience = new Map<Id, List<String>>();

        for (Work_Experience__c record : [
            SELECT Candidate__c, Job_Title__c, Description__c, Start_Date__c, End_Date__c
            FROM Work_Experience__c
            WHERE Candidate__c IN :candidateIds
        ]) {
            if (!candidateWorkExperience.containsKey(record.Candidate__c)) {
                candidateWorkExperience.put(record.Candidate__c, new List<String>());
            }
            
            String formattedExp = record.Job_Title__c + ' (' + record.Start_Date__c + ' to ' + record.End_Date__c + '): ' + record.Description__c;
            candidateWorkExperience.get(record.Candidate__c).add(formattedExp);
        }

        // Build response
        List<CandidateResponse> responses =
            new List<CandidateResponse>();

        for (Candidate__c candidate : candidates) {

            CandidateResponse response =
                new CandidateResponse();

            response.candidateId = candidate.Id;
            response.candidateName = candidate.Name;
            response.role = candidate.Role__c;
            response.experienceYears =
                candidate.Experience_Years__c;

            // Generate absolute Markdown link directly in Apex to prevent builder/redaction path errors
            // String to get current org instance URL
            // String orgUrl = System.Url.getOrgDomainUrl().toExternalForm();
            String orgUrl = System.Url.getOrgDomainUrl().toExternalForm();
            response.candidateHyperlink = '<a href="https://orgfarm-e307e8ad28-dev-ed.develop.lightning.force.com/lightning/r/Candidate__c/' + candidate.Id + '/view" target="_blank">View Record</a>';
            // response.candidateHyperlink = '[View Record](' + orgUrl + '/lightning/r/Candidate__c/' + candidate.Id + '/view)';

            response.skills =
                candidateSkills.containsKey(candidate.Id)
                ? candidateSkills.get(candidate.Id)
                : new List<String>();

            response.achievements =
                candidateAchievements.containsKey(candidate.Id)
                ? candidateAchievements.get(candidate.Id)
                : new List<String>();

            response.education =
                candidateEducation.containsKey(candidate.Id)
                ? candidateEducation.get(candidate.Id)
                : new List<String>();

            response.workExperience =
                candidateWorkExperience.containsKey(candidate.Id)
                ? candidateWorkExperience.get(candidate.Id)
                : new List<String>();

            responses.add(response);
        }

        return responses;
    }
}