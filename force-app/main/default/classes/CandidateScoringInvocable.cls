public class CandidateScoringInvocable {

    public class ScoringRequest {
        @InvocableVariable(required=true label='Job IDs')
        public List<Id> jobIds;

        @InvocableVariable(required=true label='Candidate IDs')
        public List<Id> candidateIds;
    }

    public class ScoringResult {
        @InvocableVariable public Id jobId;
        @InvocableVariable public Id candidateId;
        @InvocableVariable public Decimal totalScore;
        @InvocableVariable public String explanationJson;
    }

    @InvocableMethod(label='Calculate Candidate Scores')
    public static List<ScoringResult> calculateScores(
        List<ScoringRequest> requests
    ) {

        List<ScoringResult> allResults = new List<ScoringResult>();

        Set<Id> jobIds = new Set<Id>();
        Set<Id> candidateIds = new Set<Id>();

        for (ScoringRequest req : requests) {
            if (req.jobIds != null) {
                jobIds.addAll(req.jobIds);
            }

            if (req.candidateIds != null) {
                candidateIds.addAll(req.candidateIds);
            }
        }

        if (jobIds.isEmpty() || candidateIds.isEmpty()) {
            return allResults;
        }

        // ---------------------------------------------------------
        // JOBS
        // ---------------------------------------------------------

        Map<Id, Job__c> jobsMap = new Map<Id, Job__c>([
            SELECT Id,
                   Role__c,
                   Data__c,
                   Job_Scoring_Config__c,
                   Job_Scoring_Config__r.Skill_Weight__c,
                   Job_Scoring_Config__r.Education_Weight__c,
                   Job_Scoring_Config__r.Experience_Weight__c,
                   Job_Scoring_Config__r.Achievement_Weight__c
            FROM Job__c
            WHERE Id IN :jobIds
        ]);

        // ---------------------------------------------------------
        // CANDIDATES
        // ---------------------------------------------------------

        Map<Id, Candidate__c> candidatesMap =
            new Map<Id, Candidate__c>([
                SELECT Id,
                       Role__c,
                       Experience_Years__c
                FROM Candidate__c
                WHERE Id IN :candidateIds
            ]);

        // ---------------------------------------------------------
        // CANDIDATE SKILLS
        // ---------------------------------------------------------

        Map<Id, Set<String>> candidateSkillsMap =
            new Map<Id, Set<String>>();

        for (Candidate_Skill__c record : [
            SELECT Id, Candidate__c, Skill__c, Skill__r.Name
            FROM Candidate_Skill__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!candidateSkillsMap.containsKey(record.Candidate__c)) {
                candidateSkillsMap.put(
                    record.Candidate__c,
                    new Set<String>()
                );
            }

            if (!String.isBlank(record.Skill__c)) {
                candidateSkillsMap
                    .get(record.Candidate__c)
                    .add(record.Skill__r.Name.toLowerCase().trim());
            }
        }

        // ---------------------------------------------------------
        // CANDIDATE ACHIEVEMENTS
        // ---------------------------------------------------------

        Map<Id, Set<String>> candidateAchievementsMap =
            new Map<Id, Set<String>>();

        for (Candidate_Achievement__c record : [
            SELECT Id, Candidate__c, Achievement__c, Achievement__r.Name
            FROM Candidate_Achievement__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!candidateAchievementsMap.containsKey(record.Candidate__c)) {
                candidateAchievementsMap.put(
                    record.Candidate__c,
                    new Set<String>()
                );
            }

            if (!String.isBlank(record.Achievement__c)) {
                candidateAchievementsMap
                    .get(record.Candidate__c)
                    .add(record.Achievement__r.Name.toLowerCase().trim());
            }
        }

        // ---------------------------------------------------------
        // CANDIDATE EDUCATION
        // ---------------------------------------------------------

        Map<Id, Set<String>> candidateEducationMap =
            new Map<Id, Set<String>>();

        for (Education__c record : [
            SELECT Id,
                   Candidate__c,
                   Degree__c,
                   Field_of_Study__c,
                   Institution__c,
                   Start_Date__c,
                   End_Date__c
            FROM Education__c
            WHERE Candidate__c IN :candidateIds
        ]) {

            if (!candidateEducationMap.containsKey(record.Candidate__c)) {
                candidateEducationMap.put(
                    record.Candidate__c,
                    new Set<String>()
                );
            }

            Set<String> educationValues =
                candidateEducationMap.get(record.Candidate__c);

            if (!String.isBlank(record.Degree__c)) {
                educationValues.add(
                    record.Degree__c.toLowerCase().trim()
                );
            }

            if (!String.isBlank(record.Field_of_Study__c)) {
                educationValues.add(
                    record.Field_of_Study__c.toLowerCase().trim()
                );
            }

            if (!String.isBlank(record.Institution__c)) {
                educationValues.add(
                    record.Institution__c.toLowerCase().trim()
                );
            }
        }

        // ---------------------------------------------------------
        // EXISTING APPLICATIONS
        // ---------------------------------------------------------

        Map<String, Job_Application__c> existingAppsMap =
            new Map<String, Job_Application__c>();

        for (Job_Application__c app : [
            SELECT Id, Job__c, Candidate__c
            FROM Job_Application__c
            WHERE Job__c IN :jobIds
            AND Candidate__c IN :candidateIds
        ]) {

            existingAppsMap.put(
                app.Job__c + '-' + app.Candidate__c,
                app
            );
        }

        List<Job_Application__c> appsToInsert =
            new List<Job_Application__c>();

        List<Job_Application__c> appsToUpdate =
            new List<Job_Application__c>();

        // ---------------------------------------------------------
        // SCORING
        // ---------------------------------------------------------

        for (ScoringRequest req : requests) {

            if (req.jobIds == null ||
                req.candidateIds == null) {
                continue;
            }

            for (Id jobId : req.jobIds) {

                Job__c job = jobsMap.get(jobId);

                if (job == null ||
                    String.isBlank(job.Data__c)) {
                    continue;
                }

                // -------------------------------------------------
                // WEIGHTS
                // -------------------------------------------------

                Job_Scoring_Config__c config =
                    job.Job_Scoring_Config__r;

                Decimal wSkill =
                    config != null &&
                    config.Skill_Weight__c != null
                    ? config.Skill_Weight__c
                    : 1;

                Decimal wEdu =
                    config != null &&
                    config.Education_Weight__c != null
                    ? config.Education_Weight__c
                    : 0;

                Decimal wExp =
                    config != null &&
                    config.Experience_Weight__c != null
                    ? config.Experience_Weight__c
                    : 1;

                Decimal wAch =
                    config != null &&
                    config.Achievement_Weight__c != null
                    ? config.Achievement_Weight__c
                    : 1;

                Decimal totalWeight =
                    wSkill + wEdu + wExp + wAch;

                if (totalWeight <= 0) {
                    totalWeight = 1;
                }

                // -------------------------------------------------
                // JOB REQUIREMENTS
                // -------------------------------------------------

                Map<String, Object> jobRoot =
                    (Map<String, Object>)
                    JSON.deserializeUntyped(job.Data__c);

                Map<String, Object> jobData =
                    jobRoot.containsKey('job')
                    ? (Map<String, Object>) jobRoot.get('job')
                    : jobRoot;

                String jobRole = job.Role__c;

                Decimal minExp = 0;

                if (jobData.get('minExperienceYears') != null) {
                    minExp = Decimal.valueOf(
                        String.valueOf(
                            jobData.get('minExperienceYears')
                        )
                    ).setScale(
                        0,
                        RoundingMode.CEILING
                    );
                }

                List<Object> jobSkills =
                    jobData.containsKey('desiredSkills')
                    ? (List<Object>) jobData.get('desiredSkills')
                    : new List<Object>();

                List<Object> jobAchievements =
                    jobData.containsKey('desiredAchievements')
                    ? (List<Object>) jobData.get('desiredAchievements')
                    : new List<Object>();

                List<Object> jobEducation =
                    jobData.containsKey('desiredEducation')
                    ? (List<Object>) jobData.get('desiredEducation')
                    : new List<Object>();

                // -------------------------------------------------
                // CANDIDATES
                // -------------------------------------------------

                for (Id candidateId : req.candidateIds) {

                    Candidate__c candidate =
                        candidatesMap.get(candidateId);

                    if (candidate == null) {
                        continue;
                    }

                    // Role
                    Boolean roleMatch =
                        !String.isBlank(jobRole) &&
                        !String.isBlank(candidate.Role__c) &&
                        jobRole.equalsIgnoreCase(
                            candidate.Role__c
                        );

                    // Experience
                    Decimal candidateExperience =
                        candidate.Experience_Years__c != null
                        ? candidate.Experience_Years__c.setScale(
                            0,
                            RoundingMode.CEILING
                        )
                        : 0;

                    Boolean experienceMatch =
                        candidateExperience >= minExp;

                    // Candidate skills
                    Set<String> candidateSkills =
                        candidateSkillsMap.containsKey(candidateId)
                        ? candidateSkillsMap.get(candidateId)
                        : new Set<String>();

                    // Candidate achievements
                    Set<String> candidateAchievements =
                        candidateAchievementsMap.containsKey(candidateId)
                        ? candidateAchievementsMap.get(candidateId)
                        : new Set<String>();

                    // Candidate education
                    Set<String> candidateEducation =
                        candidateEducationMap.containsKey(candidateId)
                        ? candidateEducationMap.get(candidateId)
                        : new Set<String>();

                    // -------------------------------------------------
                    // MATCHING
                    // -------------------------------------------------

                    MatchResult skillMatch =
                        getDetailedMatches(
                            jobSkills,
                            candidateSkills
                        );

                    MatchResult achievementMatch =
                        getDetailedMatches(
                            jobAchievements,
                            candidateAchievements
                        );

                    MatchResult educationMatch =
                        getDetailedMatches(
                            jobEducation,
                            candidateEducation
                        );

                    // -------------------------------------------------
                    // SCORES
                    // -------------------------------------------------

                    Decimal skillScore =
                        skillMatch.total > 0
                        ? (
                            Decimal.valueOf(
                                skillMatch.matchedCount
                            ) /
                            Decimal.valueOf(
                                skillMatch.total
                            )
                        ) * 100
                        : 100;

                    Decimal achievementScore =
                        achievementMatch.total > 0
                        ? (
                            Decimal.valueOf(
                                achievementMatch.matchedCount
                            ) /
                            Decimal.valueOf(
                                achievementMatch.total
                            )
                        ) * 100
                        : 100;

                    Decimal educationScore =
                        educationMatch.total > 0
                        ? (
                            Decimal.valueOf(
                                educationMatch.matchedCount
                            ) /
                            Decimal.valueOf(
                                educationMatch.total
                            )
                        ) * 100
                        : 100;

                    Decimal experienceScore =
                        experienceMatch ? 100 : 0;

                    // -------------------------------------------------
                    // TOTAL
                    // -------------------------------------------------

                    Decimal totalScore = 0;

                    if (roleMatch) {

                        totalScore =
                            (
                                (skillScore * wSkill) +
                                (educationScore * wEdu) +
                                (experienceScore * wExp) +
                                (achievementScore * wAch)
                            ) / totalWeight;
                    }

                    totalScore =
                        totalScore.setScale(
                            2,
                            RoundingMode.HALF_UP
                        );

                    // -------------------------------------------------
                    // EXPLANATION JSON
                    // -------------------------------------------------

                    Map<String, Object> explanation =
                        new Map<String, Object>{

                            'totalScore' => totalScore,

                            'roleMatch' => roleMatch,

                            'candidateExperience' =>
                                candidateExperience,

                            'requiredExperience' =>
                                minExp,

                            'experienceMatch' =>
                                experienceMatch,

                            'scoresBreakdown' =>
                                new Map<String, Object>{
                                    'skillScore' =>
                                        skillScore,
                                    'educationScore' =>
                                        educationScore,
                                    'experienceScore' =>
                                        experienceScore,
                                    'achievementScore' =>
                                        achievementScore
                                },

                            'skillsBreakdown' =>
                                new Map<String, Object>{
                                    'matched' =>
                                        skillMatch.matchedList,
                                    'missing' =>
                                        skillMatch.missingList,
                                    'total' =>
                                        skillMatch.total
                                },

                            'achievementsBreakdown' =>
                                new Map<String, Object>{
                                    'matched' =>
                                        achievementMatch.matchedList,
                                    'missing' =>
                                        achievementMatch.missingList,
                                    'total' =>
                                        achievementMatch.total
                                },

                            'educationBreakdown' =>
                                new Map<String, Object>{
                                    'matched' =>
                                        educationMatch.matchedList,
                                    'missing' =>
                                        educationMatch.missingList,
                                    'total' =>
                                        educationMatch.total
                                },

                            'weightsApplied' =>
                                new Map<String, Object>{
                                    'skillWeight' => wSkill,
                                    'educationWeight' => wEdu,
                                    'experienceWeight' => wExp,
                                    'achievementWeight' => wAch,
                                    'totalWeightSum' => totalWeight
                                }
                        };

                    String explanationJson =
                        JSON.serialize(explanation);

                    // -------------------------------------------------
                    // JOB APPLICATION
                    // -------------------------------------------------

                    String compositeKey =
                        jobId + '-' + candidateId;

                    if (existingAppsMap.containsKey(compositeKey)) {

                        Job_Application__c app =
                            existingAppsMap.get(compositeKey);

                        app.Score__c = totalScore;
                        app.Data__c = explanationJson;

                        appsToUpdate.add(app);

                    } else {

                        Job_Application__c app =
                            new Job_Application__c(
                                Job__c = jobId,
                                Candidate__c = candidateId,
                                Score__c = totalScore,
                                Data__c = explanationJson
                            );

                        appsToInsert.add(app);

                        existingAppsMap.put(
                            compositeKey,
                            app
                        );
                    }

                    // Result
                    ScoringResult result =
                        new ScoringResult();

                    result.jobId = jobId;
                    result.candidateId = candidateId;
                    result.totalScore = totalScore;
                    result.explanationJson =
                        explanationJson;

                    allResults.add(result);
                }
            }
        }

        // ---------------------------------------------------------
        // DML
        // ---------------------------------------------------------

        if (!appsToInsert.isEmpty()) {
            insert appsToInsert;
        }

        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
        }

        return allResults;
    }

    // =============================================================
    // MATCH RESULT
    // =============================================================

    private class MatchResult {

        public List<String> matchedList =
            new List<String>();

        public List<String> missingList =
            new List<String>();

        public Integer matchedCount = 0;

        public Integer total = 0;
    }

    // =============================================================
    // MATCHING
    // =============================================================

    private static MatchResult getDetailedMatches(
        List<Object> jobItems,
        Set<String> candidateItems
    ) {

        MatchResult result =
            new MatchResult();

        if (jobItems == null) {
            return result;
        }

        result.total = jobItems.size();

        for (Object item : jobItems) {

            if (item == null) {
                continue;
            }

            String rawValue =
                String.valueOf(item);

            String cleanValue =
                rawValue.toLowerCase().trim();

            if (candidateItems.contains(cleanValue)) {

                result.matchedCount++;
                result.matchedList.add(rawValue);

            } else {

                result.missingList.add(rawValue);
            }
        }

        return result;
    }
}