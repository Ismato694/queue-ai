// Pure helpers for the worker (testable without starting the HTTP server).

export function messageFor(event: string): string {
  switch (event) {
    case 'your_turn': return "It's almost your turn — please proceed to the counter.";
    case 'leave_now': return 'Time to head over — leave now so you arrive right as you are called.';
    case 'delayed':   return 'Your wait has increased slightly. Thanks for your patience.';
    default:          return 'Update on your visit.';
  }
}

// Cost-aware routing (R6): which channel for an event. Push is free; SMS reserved for
// high-value events the patient must act on.
export function channelFor(event: string): 'push' | 'sms' {
  return event === 'your_turn' || event === 'leave_now' ? 'sms' : 'push';
}
