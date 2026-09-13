public with sharing class WorkExperienceTriggerHandler {
    public static void updateCandidateExperience(List<Work_Experience__c> newList, List<Work_Experience__c> oldList) {
        Set<Id> candidateIds = new Set<Id>();
        
        if (newList != null) {
            for (Work_Experience__c we : newList) {
                if (we.Candidate__c != null) candidateIds.add(we.Candidate__c);
            }
        }
        if (oldList != null) {
            for (Work_Experience__c we : oldList) {
                if (we.Candidate__c != null) candidateIds.add(we.Candidate__c);
            }
        }
        
        if (candidateIds.isEmpty()) return;
        
        List<Work_Experience__c> allExperiences = [
            SELECT Candidate__c, Start_Date__c, End_Date__c 
            FROM Work_Experience__c 
            WHERE Candidate__c IN :candidateIds
        ];
        
        Map<Id, Decimal> totalMonthsMap = new Map<Id, Decimal>();
        for (Work_Experience__c we : allExperiences) {
            if (we.Start_Date__c != null) {
                Date endDate = (we.End_Date__c != null) ? we.End_Date__c : Date.today();
                
                if (endDate >= we.Start_Date__c) {
                    Integer months = we.Start_Date__c.monthsBetween(endDate);
                    Decimal currentMonths = totalMonthsMap.containsKey(we.Candidate__c) ? totalMonthsMap.get(we.Candidate__c) : 0;
                    totalMonthsMap.put(we.Candidate__c, currentMonths + months);
                }
            }
        }
        
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        for (Id candId : candidateIds) {
            Decimal totalMonths = totalMonthsMap.containsKey(candId) ? totalMonthsMap.get(candId) : 0;
            Decimal totalYears = (totalMonths / 12.0).setScale(1, RoundingMode.HALF_UP);
            candidatesToUpdate.add(new Candidate__c(Id = candId, Experience_Years__c = totalYears));
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }
}