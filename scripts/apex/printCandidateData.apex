Candidate__c sampleCandidate = [SELECT Id, First_Name__c FROM Candidate__c LIMIT 1];

if (sampleCandidate != null) {
    CandidateDataService.CandidateRequest request = new CandidateDataService.CandidateRequest();
    request.searchName = sampleCandidate.First_Name__c;

    List<CandidateDataService.CandidateResponse> results = CandidateDataService.getCandidateData(
        new List<CandidateDataService.CandidateRequest>{ request }
    );

    for (CandidateDataService.CandidateResponse result : results) {
        System.debug('==============================');
        System.debug('CANDIDATE ID: ' + result.candidateId);
        System.debug('CANDIDATE NAME: ' + result.candidateName);
        System.debug('JSON PAYLOAD:\n' + result.candidateData);
        System.debug('==============================');
    }
} else {
    System.debug('No Candidate records found.');
}