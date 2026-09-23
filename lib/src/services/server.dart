var server = 'https://backend.portfolio.rsaw409.me/split';
// var server = 'http://localhost:3000';

/// Reads fail benignly — cache-first paint keeps whatever is already on screen
/// and flips `isStale` — so they give up sooner rather than holding a spinner.
const Duration readTimeout = Duration(seconds: 15);

/// Writes get longer: abandoning one that may already have been committed is
/// worse than waiting. Retries are safe regardless, since every write carries
/// an idempotency key.
const Duration writeTimeout = Duration(seconds: 20);
