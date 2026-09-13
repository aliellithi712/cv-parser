// 1. Fetch or create a test Job with parsed JSON data
Job__c testJob = [SELECT Id,data__c FROM Job__c LIMIT 1];
if (testJob.Data__c == null) {
    testJob.Data__c = '{"job":{"role":"Developer","desiredAchievements":["Platform Developer I","Platform App Builder"]}}';
    update testJob;
}

// 2. Fetch or create a test Candidate with parsed JSON data
Candidate__c testCand = [SELECT Id,data__c FROM Candidate__c LIMIT 1];
if (testCand.Data__c == null) {
    testCand.Data__c = '{"candidate":{"role":"Developer","achievements":["Platform Developer I"]}}';
    update testCand;
}

// 3. Build the Invocable Request
CandidateScoringInvocable.ScoringRequest req = new CandidateScoringInvocable.ScoringRequest();
req.jobId = testJob.Id;
req.candidateIds = new List<Id>{ testCand.Id };

// 4. Invoke the scoring service
List<CandidateScoringInvocable.ScoringResult> results = 
    CandidateScoringInvocable.calculateScores(new List<CandidateScoringInvocable.ScoringRequest>{ req });

// 5. Inspect the output
for (CandidateScoringInvocable.ScoringResult res : results) {
    System.debug('Candidate ID: ' + res.candidateId);
    System.debug('Total Score: ' + res.totalScore);
    System.debug('Explanation JSON: ' + res.explanationJson);
}