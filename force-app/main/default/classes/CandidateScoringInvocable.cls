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
    public static List<ScoringResult> calculateScores(List<ScoringRequest> requests) {
        List<ScoringResult> allResults = new List<ScoringResult>();
        Set<Id> jobIds = new Set<Id>();
        Set<Id> allCandidateIds = new Set<Id>();
        
        for (ScoringRequest req : requests) {
            if (req.jobIds != null) jobIds.addAll(req.jobIds);
            if (req.candidateIds != null) allCandidateIds.addAll(req.candidateIds);
        }

        Map<Id, Job__c> jobsMap = new Map<Id, Job__c>([
            SELECT Id, Data__c, Job_Scoring_Config__c, 
                   Job_Scoring_Config__r.Skill_Weight__c, 
                   Job_Scoring_Config__r.Education_Weight__c, 
                   Job_Scoring_Config__r.Experience_Weight__c, 
                   Job_Scoring_Config__r.Achievement_Weight__c 
            FROM Job__c 
            WHERE Id IN :jobIds
        ]);

        Map<String, Job_Application__c> existingAppsMap = new Map<String, Job_Application__c>();
        for (Job_Application__c existingApp : [
            SELECT Id, Job__c, Candidate__c FROM Job_Application__c 
            WHERE Job__c IN :jobIds AND Candidate__c IN :allCandidateIds
        ]) {
            existingAppsMap.put(existingApp.Job__c + '-' + existingApp.Candidate__c, existingApp);
        }

        List<Job_Application__c> appsToInsert = new List<Job_Application__c>();
        List<Job_Application__c> appsToUpdate = new List<Job_Application__c>();

        for (ScoringRequest req : requests) {
            if (req.jobIds == null || req.candidateIds == null) continue;

            Map<Id, Candidate__c> candidates = new Map<Id, Candidate__c>([
                SELECT Id, Data__c, Experience_Years__c FROM Candidate__c WHERE Id IN :req.candidateIds
            ]);

            for (Id jobId : req.jobIds) {
                Job__c job = jobsMap.get(jobId);
                if (job == null || String.isBlank(job.Data__c)) continue;

                Job_Scoring_Config__c config = job.Job_Scoring_Config__r;
                Decimal wSkill = (config != null && config.Skill_Weight__c != null) ? config.Skill_Weight__c : 1;
                Decimal wEdu = (config != null && config.Education_Weight__c != null) ? config.Education_Weight__c : 0;
                Decimal wExp = (config != null && config.Experience_Weight__c != null) ? config.Experience_Weight__c : 1;
                Decimal wAch = (config != null && config.Achievement_Weight__c != null) ? config.Achievement_Weight__c : 1;
                Decimal totalWeight = wSkill + wEdu + wExp + wAch;
                if (totalWeight <= 0) totalWeight = 1;

                Map<String, Object> jobRoot = (Map<String, Object>) JSON.deserializeUntyped(job.Data__c);
                Map<String, Object> jobData = jobRoot.containsKey('job') ? (Map<String, Object>) jobRoot.get('job') : jobRoot;
                
                String jobRole = (String) jobData.get('role');
                Decimal minExp = (jobData.get('minExperienceYears') != null) ? Decimal.valueOf(String.valueOf(jobData.get('minExperienceYears'))).setScale(0, RoundingMode.CEILING) : 0;
                
                List<Object> jobSkills = jobData.containsKey('desiredSkills') ? (List<Object>) jobData.get('desiredSkills') : new List<Object>();
                List<Object> jobAch = jobData.containsKey('desiredAchievements') ? (List<Object>) jobData.get('desiredAchievements') : new List<Object>();
                List<Object> jobEdu = jobData.containsKey('desiredEducation') ? (List<Object>) jobData.get('desiredEducation') : new List<Object>();

                for (Id candId : req.candidateIds) {
                    Candidate__c cand = candidates.get(candId);
                    if (cand == null || String.isBlank(cand.Data__c)) continue;

                    Map<String, Object> candRoot = (Map<String, Object>) JSON.deserializeUntyped(cand.Data__c);
                    Map<String, Object> candData = candRoot.containsKey('candidate') ? (Map<String, Object>) candRoot.get('candidate') : candRoot;

                    String candRole = (String) candData.get('role');
                    Boolean roleMatch = (jobRole != null && jobRole.equalsIgnoreCase(candRole));

                    Decimal candExp = (cand.Experience_Years__c != null) ? cand.Experience_Years__c.setScale(0, RoundingMode.CEILING) : 0;

                    Set<String> candSkillSet = extractStringSet(candData, new List<String>{'skills', 'desiredSkills'});
                    Set<String> candAchSet = extractStringSet(candData, new List<String>{'achievements', 'certifications', 'qualifications'});
                    Set<String> candEduSet = extractStringSet(candData, new List<String>{'education', 'degrees', 'degreesList'});

                    MatchResult skillMatchRes = getDetailedMatches(jobSkills, candSkillSet);
                    MatchResult achMatchRes = getDetailedMatches(jobAch, candAchSet);
                    MatchResult eduMatchRes = getDetailedMatches(jobEdu, candEduSet);

                    Boolean expMatch = (candExp >= minExp);

                    Decimal skillScore = (skillMatchRes.total > 0) ? (Decimal.valueOf(skillMatchRes.matchedCount) / Decimal.valueOf(skillMatchRes.total)) * 100 : 100;
                    Decimal achScore = (achMatchRes.total > 0) ? (Decimal.valueOf(achMatchRes.matchedCount) / Decimal.valueOf(achMatchRes.total)) * 100 : 100;
                    Decimal eduScore = (eduMatchRes.total > 0) ? (Decimal.valueOf(eduMatchRes.matchedCount) / Decimal.valueOf(eduMatchRes.total)) * 100 : 100;
                    Decimal expScore = expMatch ? 100 : 0;

                    Decimal totalScore = 0;
                    if (roleMatch) {
                        totalScore = ((skillScore * wSkill) + (eduScore * wEdu) + (expScore * wExp) + (achScore * wAch)) / totalWeight;
                    }
                    totalScore = totalScore.setScale(2, RoundingMode.HALF_UP);

                    Map<String, Object> explanation = new Map<String, Object>{
                        'totalScore' => totalScore,
                        'roleMatch' => roleMatch,
                        'weightsApplied' => new Map<String, Object>{
                            'skillWeight' => wSkill,
                            'educationWeight' => wEdu,
                            'experienceWeight' => wExp,
                            'achievementWeight' => wAch,
                            'totalWeightSum' => totalWeight
                        },
                        'scoresBreakdown' => new Map<String, Object>{
                            'skillScore' => skillScore,
                            'educationScore' => eduScore,
                            'experienceScore' => expScore,
                            'achievementScore' => achScore
                        },
                        'candidateExperience' => candExp,
                        'requiredExperience' => minExp,
                        'experienceMatch' => expMatch,
                        'skillsBreakdown' => new Map<String, Object>{
                            'matched' => skillMatchRes.matchedList,
                            'missing' => skillMatchRes.missingList,
                            'total' => skillMatchRes.total
                        },
                        'achievementsBreakdown' => new Map<String, Object>{
                            'matched' => achMatchRes.matchedList,
                            'missing' => achMatchRes.missingList,
                            'total' => achMatchRes.total
                        },
                        'educationBreakdown' => new Map<String, Object>{
                            'matched' => eduMatchRes.matchedList,
                            'missing' => eduMatchRes.missingList,
                            'total' => eduMatchRes.total
                        }
                    };

                    String explanationJsonStr = JSON.serialize(explanation);

                    String compositeKey = jobId + '-' + candId;
                    if (existingAppsMap.containsKey(compositeKey)) {
                        Job_Application__c appToUpdate = existingAppsMap.get(compositeKey);
                        appToUpdate.Score__c = totalScore;
                        appToUpdate.Data__c = explanationJsonStr;
                        appsToUpdate.add(appToUpdate);
                    } else {
                        Job_Application__c newApp = new Job_Application__c(
                            Job__c = jobId,
                            Candidate__c = candId,
                            Score__c = totalScore,
                            Data__c = explanationJsonStr
                        );
                        appsToInsert.add(newApp);
                        existingAppsMap.put(compositeKey, newApp);
                    }

                    ScoringResult res = new ScoringResult();
                    res.jobId = jobId;
                    res.candidateId = candId;
                    res.totalScore = totalScore;
                    res.explanationJson = explanationJsonStr;
                    allResults.add(res);
                }
            }
        }

        if (!appsToInsert.isEmpty()) {
            insert appsToInsert;
        }
        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
        }

        return allResults;
    }

    private class MatchResult {
        public List<String> matchedList = new List<String>();
        public List<String> missingList = new List<String>();
        public Integer matchedCount = 0;
        public Integer total = 0;
    }

    private static Set<String> extractStringSet(Map<String, Object> dataMap, List<String> possibleKeys) {
        Set<String> resultSet = new Set<String>();
        List<Object> rawList = new List<Object>();
        
        for (String key : possibleKeys) {
            if (dataMap.containsKey(key) && dataMap.get(key) instanceof List<Object>) {
                rawList = (List<Object>) dataMap.get(key);
                break;
            }
        }

        for (Object item : rawList) {
            if (item == null) continue;
            if (item instanceof String) {
                resultSet.add(((String) item).toLowerCase().trim());
            } else if (item instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) item;
                String val = (String) m.get('name');
                if (val == null) val = (String) m.get('title');
                if (val == null) val = (String) m.get('skill');
                if (val != null) resultSet.add(val.toLowerCase().trim());
            }
        }
        return resultSet;
    }

    private static MatchResult getDetailedMatches(List<Object> jobItems, Set<String> candItemSet) {
        MatchResult res = new MatchResult();
        if (jobItems == null) return res;
        res.total = jobItems.size();

        for (Object ji : jobItems) {
            if (ji == null) continue;
            String rawVal = String.valueOf(ji);
            String cleanVal = rawVal.toLowerCase().trim();
            if (candItemSet.contains(cleanVal)) {
                res.matchedCount++;
                res.matchedList.add(rawVal);
            } else {
                res.missingList.add(rawVal);
            }
        }
        return res;
    }
}