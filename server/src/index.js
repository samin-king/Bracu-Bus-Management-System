// Default startup must never expose the legacy development identity or
// unguarded management routers. The integrated server validates configuration
// and schema before listening; the lower-level app remains reusable in tests.
await import('./authenticatedIndex.js');
