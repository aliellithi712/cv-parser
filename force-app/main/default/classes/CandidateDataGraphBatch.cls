public class CandidateDataGraphBatch implements Database.Batchable<String>, Database.AllowsCallouts {

    private String startTime;
    private String endTime;

    public CandidateDataGraphBatch(String startTime, String endTime) {
        this.startTime = startTime;
        this.endTime = endTime;
    }

    public Iterable<String> start(Database.BatchableContext BC) {
        List<String> individualIds = new List<String>();
        String sqlQuery =
            'SELECT ssot__Id__c, "Created_At__c" ' +
            'FROM ssot__Individual__dlm ' +
            'WHERE "Created_At__c" >= cast(\'' + startTime + '\' as timestamp(1)) ' +
            'AND "Created_At__c" <= cast(\'' + endTime + '\' as timestamp(1))';

        ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
        input.sql = sqlQuery;
        ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(input);

        if (queryOutput != null && queryOutput.data != null) {
            for (ConnectApi.CdpQueryV2Row row : queryOutput.data) {
                individualIds.add((String) row.rowData[0]);
            }
        }
        return individualIds;
    }

    public void execute(Database.BatchableContext BC, List<String> scope) {
        List<Candidate__c> candidatesToInsert = new List<Candidate__c>();

        Map<String, List<Work_Experience__c>> workExpMap = new Map<String, List<Work_Experience__c>>();
        Map<String, List<Education__c>> eduMap = new Map<String, List<Education__c>>();
        
        Map<String, List<Map<String, String>>> skillDataMap = new Map<String, List<Map<String, String>>>();
        Map<String, List<Map<String, String>>> achievementDataMap = new Map<String, List<Map<String, String>>>();

        for (String targetId : scope) {
            String lookupKeys = '[UnifiedLinkssotIndividualTest__dlm.SourceRecordId__c=' + targetId + ']';
            
            try {
                ConnectApi.CdpQueryOutput graphResponse = ConnectApi.CdpQuery.getDataGraphDataWithLookupKeys('resume_v13_Clone', lookupKeys);
                if (graphResponse.data == null || graphResponse.data.isEmpty()) continue;
                
                Map<String, Object> outerMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(graphResponse.data[0]));
                String jsonBlob = (String) outerMap.get('json_blob__c');
                if (String.isBlank(jsonBlob)) continue;
                
                Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBlob);
                
                String email = '';
                List<Object> contactEmails = (List<Object>) dataMap.get('UnifiedssotContactPointEmailTest__dlm');
                if (contactEmails != null && !contactEmails.isEmpty()) {
                    email = (String) ((Map<String, Object>) contactEmails[0]).get('ssot__EmailAddress__c') ?? '';
                }

                String phone = '';
                List<Object> contactPhones = (List<Object>) dataMap.get('UnifiedssotContactPointPhoneTest__dlm');
                if (contactPhones != null && !contactPhones.isEmpty()) {
                    phone = (String) ((Map<String, Object>) contactPhones[0]).get('ssot__FormattedE164PhoneNumber__c') ?? '';
                }

                List<Object> links = (List<Object>) dataMap.get('UnifiedLinkssotIndividualTest__dlm');
                if (links == null) continue;
                
                for (Object linkObj : links) {
                    Map<String, Object> link = (Map<String, Object>) linkObj;
                    List<Object> individuals = (List<Object>) link.get('ssot__Individual__dlm');
                    if (individuals == null) continue;
                
                    for (Object indObj : individuals) {
                        Map<String, Object> ind = (Map<String, Object>) indObj;
                        
                        Candidate__c cand = new Candidate__c(
                            First_Name__c = (String) ind.get('ssot__FirstName__c') ?? '',
                            Last_Name__c = (String) ind.get('ssot__LastName__c') ?? '',
                            Email__c = email,
                            Phone__c = phone,
                            Summary__c = (String) ind.get('Professional_Summary__c') ?? '',
                            Role__c = (String) ind.get('Professional_Role__c') ?? '',
                            External_Id__c = targetId
                        );
                        candidatesToInsert.add(cand);

                        // Process work experiences
                        List<Object> workExps = (List<Object>) ind.get('cv_parser_CandidateWorkExperien_53D3__dlm');
                        if (workExps != null) {
                            List<Work_Experience__c> weList = new List<Work_Experience__c>();
                            for (Object weObj : workExps) {
                                Map<String, Object> work = (Map<String, Object>) weObj;
                                weList.add(new Work_Experience__c(
                                    Company__c = (String) work.get('company_name__c') ?? '',
                                    Job_Title__c = (String) work.get('job_title__c') ?? '',
                                    Start_Date__c = String.isNotBlank((String) work.get('start_date__c')) ? Date.valueOf((String) work.get('start_date__c')) : null,
                                    End_Date__c = String.isNotBlank((String) work.get('end_date__c')) ? Date.valueOf((String) work.get('end_date__c')) : null
                                ));
                            }
                            workExpMap.put(targetId, weList);
                        }

                        // Process education records
                        List<Object> educations = (List<Object>) ind.get('cv_parser_CandidateEducation_0E518C4__dlm');
                        if (educations != null) {
                            List<Education__c> edList = new List<Education__c>();
                            for (Object edObj : educations) {
                                Map<String, Object> edu = (Map<String, Object>) edObj;
                                edList.add(new Education__c(
                                    Institution__c = (String) edu.get('institution_name__c') ?? '',
                                    Degree__c = (String) edu.get('degree__c') ?? '',
                                    Field_Of_Study__c = (String) edu.get('field_of_study__c') ?? ''
                                ));
                            }
                            eduMap.put(targetId, edList);
                        }

                        // Process candidate skills with external id mapping
                        List<Object> candSkills = (List<Object>) ind.get('cv_parser_CandidateSkill_AEC1E575__dlm');
                        if (candSkills != null) {
                            List<Map<String, String>> skList = new List<Map<String, String>>();
                            for (Object csObj : candSkills) {
                                Map<String, Object> candidateSkill = (Map<String, Object>) csObj;
                                String candidateSkillId = (String) candidateSkill.get('candidate_skill_id__c'); 
                                List<Object> skills = (List<Object>) candidateSkill.get('ssot__Skill__dlm');
                                if (skills != null) {
                                    for (Object sObj : skills) {
                                        Map<String, Object> skill = (Map<String, Object>) sObj;
                                        skList.add(new Map<String, String>{
                                            'externalId' => candidateSkillId ?? '',
                                            'name' => (String) skill.get('ssot__Name__c') ?? ''
                                        });
                                    }
                                }
                            }
                            skillDataMap.put(targetId, skList);
                        }

                        System.debug('Unique Skills Map: ' + skillDataMap);

                        // Process candidate achievements with external id mapping
                        List<Object> candAchievements = (List<Object>) ind.get('cv_parser_CandidateAchievement_E49D9__dlm');
                        if (candAchievements != null) {
                            List<Map<String, String>> achList = new List<Map<String, String>>();
                            for (Object caObj : candAchievements) {
                                Map<String, Object> candidateAchievement = (Map<String, Object>) caObj;
                                String candidateAchievementId = (String) candidateAchievement.get('candidateAchievement_id__c');
                                List<Object> achievements = (List<Object>) candidateAchievement.get('cv_parser_Achievement_7A6557E9__dlm');
                                if (achievements != null) {
                                    for (Object aObj : achievements) {
                                        Map<String, Object> achievement = (Map<String, Object>) aObj;
                                        achList.add(new Map<String, String>{
                                            'externalId' => candidateAchievementId ?? '',
                                            'name' => (String) achievement.get('achievementName__c') ?? ''
                                        });
                                    }
                                }
                            }
                            achievementDataMap.put(targetId, achList);
                        }
                        System.debug('Unique Achievements Map: ' + achievementDataMap);
                    }
                }
            } catch(Exception e) {
                System.debug('Error processing Data Graph: ' + e.getMessage());
            }
        }

        if (candidatesToInsert.isEmpty()) return;
        insert candidatesToInsert;

        // 1. Explicitly query fresh candidates to ensure IDs are populated
        Set<String> insertedExternalIds = new Set<String>();
        for (Candidate__c cand : candidatesToInsert) {
            if (cand.External_Id__c != null) {
                insertedExternalIds.add(cand.External_Id__c);
            }
        }

        Map<String, Id> dlmIdToCandidateId = new Map<String, Id>();
        for (Candidate__c freshCand : [SELECT Id, External_Id__c FROM Candidate__c WHERE External_Id__c IN :insertedExternalIds]) {
            dlmIdToCandidateId.put(freshCand.External_Id__c, freshCand.Id);
        }

        // 2. Prepare master records (Skills & Achievements) using External IDs
        Map<String, Skill__c> uniqueSkillsMap = new Map<String, Skill__c>();
        System.debug('Unique Achievements Map: ' + skillDataMap);
        Map<String, Achievement__c> uniqueAchievementsMap = new Map<String, Achievement__c>();

        for (String targetId : dlmIdToCandidateId.keySet()) {
            if (skillDataMap.containsKey(targetId)) {
                for (Map<String, String> skData : skillDataMap.get(targetId)) {
                    String extId = skData.get('externalId');
                    String sName = skData.get('name');
                    if (String.isNotBlank(extId) && !uniqueSkillsMap.containsKey(extId)) {
                        uniqueSkillsMap.put(extId, new Skill__c(External_Id__c = extId, Name = sName));
                    }
                }
            }

            if (achievementDataMap.containsKey(targetId)) {
                for (Map<String, String> achData : achievementDataMap.get(targetId)) {
                    String extId = achData.get('externalId');
                    String title = achData.get('name');
                    System.debug('Processing Achievement Data NAME: ' + achData);
                    String descr = achData.get('description');
                    
                    if (String.isNotBlank(extId) && !uniqueAchievementsMap.containsKey(extId)) {
                        uniqueAchievementsMap.put(extId, new Achievement__c(External_Id__c = extId, Name = title, Description__c = descr));
                    }
                }
            }
        }

        System.debug('Unique Skills Map: ' + uniqueSkillsMap);
        System.debug('Unique Achievements Map: ' + uniqueAchievementsMap);

        if (!uniqueSkillsMap.isEmpty()) {
            upsert uniqueSkillsMap.values() External_Id__c;
        }

        if (!uniqueAchievementsMap.isEmpty()) {
            upsert uniqueAchievementsMap.values() External_Id__c;
        }

        // 3. Query fresh master records using External IDs to retrieve their Salesforce IDs
        Map<String, Id> skillExtIdToId = new Map<String, Id>();
        if (!uniqueSkillsMap.isEmpty()) {
            for (Skill__c sk : [SELECT Id, External_Id__c FROM Skill__c WHERE External_Id__c IN :uniqueSkillsMap.keySet()]) {
                skillExtIdToId.put(sk.External_Id__c, sk.Id);
            }
        }

        Map<String, Id> achievementExtIdToId = new Map<String, Id>();
        if (!uniqueAchievementsMap.isEmpty()) {
            for (Achievement__c ach : [SELECT Id, External_Id__c FROM Achievement__c WHERE External_Id__c IN :uniqueAchievementsMap.keySet()]) {
                achievementExtIdToId.put(ach.External_Id__c, ach.Id);
            }
        }

        // 4. Build related child and junction list records using queried IDs
        List<Work_Experience__c> allWorkExps = new List<Work_Experience__c>();
        List<Education__c> allEdus = new List<Education__c>();
        List<Candidate_Skill__c> allCandSkills = new List<Candidate_Skill__c>();
        List<Candidate_Achievement__c> allCandAch = new List<Candidate_Achievement__c>();

        for (String targetId : dlmIdToCandidateId.keySet()) {
            Id parentCandidateId = dlmIdToCandidateId.get(targetId);

            if (workExpMap.containsKey(targetId)) {
                for (Work_Experience__c we : workExpMap.get(targetId)) {
                    we.Candidate__c = parentCandidateId;
                    allWorkExps.add(we);
                }
            }
            if (eduMap.containsKey(targetId)) {
                for (Education__c ed : eduMap.get(targetId)) {
                    ed.Candidate__c = parentCandidateId;
                    allEdus.add(ed);
                }
            }
            if (skillDataMap.containsKey(targetId)) {
                for (Map<String, String> skData : skillDataMap.get(targetId)) {
                    String extId = skData.get('externalId');
                    Id skillId = skillExtIdToId.get(extId);
                    if (skillId != null) {
                        allCandSkills.add(new Candidate_Skill__c(
                            Candidate__c = parentCandidateId,
                            Skill__c = skillId
                        ));
                    }
                }
            }
            if (achievementDataMap.containsKey(targetId)) {
                for (Map<String, String> achData : achievementDataMap.get(targetId)) {
                    String extId = achData.get('externalId');
                    Id achievementId = achievementExtIdToId.get(extId);
                    if (achievementId != null) {
                        allCandAch.add(new Candidate_Achievement__c(
                            Candidate__c = parentCandidateId,
                            Achievement__c = achievementId
                        ));
                    }
                }
            }
        }

        if (!allWorkExps.isEmpty()) insert allWorkExps;
        if (!allEdus.isEmpty()) insert allEdus;
        if (!allCandSkills.isEmpty()) insert allCandSkills;
        if (!allCandAch.isEmpty()) insert allCandAch;
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Candidate Data Graph Batch Execution Completed.');
    }
}