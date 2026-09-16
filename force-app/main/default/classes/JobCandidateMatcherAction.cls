public class JobCandidateMatcherAction {

    public class Request {
        @InvocableVariable(
            label='Job ID'
            description='The ID of the selected job'
            required=true
        )
        public Id jobId;
    }

    public class CandidateInfo {

        @InvocableVariable(label='Applicant Name')
        public String candidateName;

        @InvocableVariable(label='Candidate ID')
        public Id candidateId;

        @InvocableVariable(label='Role')
        public String role;

        @InvocableVariable(label='Experience Years')
        public Decimal experienceYears;

        @InvocableVariable(label='Skills')
        public List<String> skills;

        @InvocableVariable(label='Achievements')
        public List<String> achievements;

        @InvocableVariable(label='Education')
        public List<String> education;

        @InvocableVariable(label='Work Experience')
        public List<String> workExperience;

        @InvocableVariable(label='Score')
        public Decimal score;

        @InvocableVariable(label='Score Explanation')
        public String scoreExplanation;
    }

    public class Result {

        @InvocableVariable(
            label='Top Candidates'
            description='Top 3 candidates with structured candidate information'
        )
        public List<CandidateInfo> candidates;
    }

    @InvocableMethod(
        label='Find Top Candidates for Job'
        description='Returns the top 3 candidates for the selected job with structured candidate information.'
    )
    public static List<Result> getTopCandidates(
        List<Request> requests
    ) {

        List<Result> results = new List<Result>();

        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Id targetJobId = requests[0].jobId;

        List<Job_Application__c> applications = [
            SELECT Id,
                   Score__c,
                   Data__c,
                   Candidate__c,
                   Candidate__r.Id,
                   Candidate__r.Name,
                   Candidate__r.First_Name__c,
                   Candidate__r.Last_Name__c,
                   Candidate__r.Role__c,
                   Candidate__r.Experience_Years__c
            FROM Job_Application__c
            WHERE Job__c = :targetJobId
            ORDER BY Score__c DESC NULLS LAST
            LIMIT 3
        ];

        Set<Id> candidateIds = new Set<Id>();

        for (Job_Application__c app : applications) {
            if (app.Candidate__c != null) {
                candidateIds.add(app.Candidate__c);
            }
        }

        // -------------------------
        // Skills
        // -------------------------

        Map<Id, List<String>> skillsMap =
            new Map<Id, List<String>>();

        for (Candidate_Skill__c record : [
            SELECT Candidate__c,
                   Skill__c,
                   Skill__r.Name
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!skillsMap.containsKey(record.Candidate__c)) {
                skillsMap.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            if (record.Skill__r != null) {
                skillsMap
                    .get(record.Candidate__c)
                    .add(record.Skill__r.Name);
            }
        }

        // -------------------------
        // Achievements
        // -------------------------

        Map<Id, List<String>> achievementsMap =
            new Map<Id, List<String>>();

        for (Candidate_Achievement__c record : [
            SELECT Candidate__c,
                   Achievement__c,
                   Achievement__r.Name
            FROM Candidate_Achievement__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!achievementsMap.containsKey(record.Candidate__c)) {
                achievementsMap.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            if (record.Achievement__r != null) {
                achievementsMap
                    .get(record.Candidate__c)
                    .add(record.Achievement__r.Name);
            }
        }

        // -------------------------
        // Education
        // -------------------------

        Map<Id, List<String>> educationMap =
            new Map<Id, List<String>>();

        for (Education__c record : [
            SELECT Candidate__c,
                   Degree__c,
                   Field_of_Study__c,
                   Institution__c
            FROM Education__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!educationMap.containsKey(record.Candidate__c)) {
                educationMap.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            String education = '';

            if (String.isNotBlank(record.Degree__c)) {
                education += record.Degree__c;
            }

            if (String.isNotBlank(record.Field_of_Study__c)) {
                if (education != '') {
                    education += ' - ';
                }

                education += record.Field_of_Study__c;
            }

            if (String.isNotBlank(record.Institution__c)) {
                if (education != '') {
                    education += ' - ';
                }

                education += record.Institution__c;
            }

            if (education != '') {
                educationMap
                    .get(record.Candidate__c)
                    .add(education);
            }
        }

        // -------------------------
        // Work Experience
        // -------------------------

        Map<Id, List<String>> workExperienceMap =
            new Map<Id, List<String>>();

        for (Work_Experience__c record : [
            SELECT Candidate__c,
                   Name
            FROM Work_Experience__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!workExperienceMap.containsKey(record.Candidate__c)) {
                workExperienceMap.put(
                    record.Candidate__c,
                    new List<String>()
                );
            }

            workExperienceMap
                .get(record.Candidate__c)
                .add(record.Name);
        }

        // -------------------------
        // Build result
        // -------------------------

        List<CandidateInfo> candidateInfoList =
            new List<CandidateInfo>();

        for (Job_Application__c app : applications) {

            CandidateInfo info = new CandidateInfo();

            if (app.Candidate__r != null) {

                info.candidateId = app.Candidate__r.Id;

                info.candidateName =
                    String.isNotBlank(app.Candidate__r.First_Name__c)
                    ? app.Candidate__r.First_Name__c +
                      ' ' +
                      app.Candidate__r.Last_Name__c
                    : app.Candidate__r.Name;

                info.role =
                    app.Candidate__r.Role__c;

                info.experienceYears =
                    app.Candidate__r.Experience_Years__c;

                info.skills =
                    skillsMap.containsKey(app.Candidate__c)
                    ? skillsMap.get(app.Candidate__c)
                    : new List<String>();

                info.achievements =
                    achievementsMap.containsKey(app.Candidate__c)
                    ? achievementsMap.get(app.Candidate__c)
                    : new List<String>();

                info.education =
                    educationMap.containsKey(app.Candidate__c)
                    ? educationMap.get(app.Candidate__c)
                    : new List<String>();

                info.workExperience =
                    workExperienceMap.containsKey(app.Candidate__c)
                    ? workExperienceMap.get(app.Candidate__c)
                    : new List<String>();
            }

            info.score = app.Score__c;

            // This is scoring output, not candidate source data.
            info.scoreExplanation = app.Data__c;

            candidateInfoList.add(info);
        }

        Result res = new Result();
        res.candidates = candidateInfoList;

        results.add(res);

        return results;
    }
}