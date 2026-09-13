// Create an instance of the invocable action for Agentforce
Invocable.Action action = Invocable.Action.createCustomAction('generateAiAgentResponse', 'Your_Agent_API_Name');

// Set the required user message/prompt
action.setInvocationParameter('userMessage', 'Hello, start a new session');

// Execute the action
List<Invocable.Action.Result> results = action.invoke();

if (!results.isEmpty() && results[0].isSuccess()) {
    // Extract and print the newly generated Session ID from output parameters
    String sessionId = (String) results[0].getOutputParameters().get('sessionId');
    String agentResponse = (String) results[0].getOutputParameters().get('agentResponse');
    
    System.debug('New Agent Session ID: ' + sessionId);
    System.debug('Agent Response: ' + agentResponse);
} else {
    System.debug('Failed to invoke agent: ' + results[0].getErrors());
}
