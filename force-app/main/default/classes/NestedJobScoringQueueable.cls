public class NestedJobScoringQueueable implements Queueable {
    private List<CandidateScoringInvocable.ScoringRequest> requests;
    private Integer currentIndex;

    public NestedJobScoringQueueable(List<CandidateScoringInvocable.ScoringRequest> requests, Integer currentIndex) {
        this.requests = requests;
        this.currentIndex = currentIndex;
    }

    public void execute(QueueableContext context) {
        if (currentIndex < requests.size()) {
            CandidateScoringInvocable.ScoringRequest currentReq = requests[currentIndex];
            
            CandidateScoringInvocable.calculateScores(new List<CandidateScoringInvocable.ScoringRequest>{ currentReq });

            Integer nextIndex = currentIndex + 1;
            if (nextIndex < requests.size()) {
                System.enqueueJob(new NestedJobScoringQueueable(requests, nextIndex));
            }
        }
    }
}