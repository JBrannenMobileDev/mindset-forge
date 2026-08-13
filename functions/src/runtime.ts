/**
 * Shared Cloud Run runtime options.
 *
 * Cloud Run bills reserved instance allocation (memory x max instances) against
 * a per-region quota shared by every function in the project. Exceeding it does
 * not fail at configuration time: deploys instead fail later at container
 * health check with a misleading "Quota exceeded for total allowable CPU"
 * message, and which function fails is essentially arbitrary.
 */

/**
 * Scheduled functions are invoked once per schedule and fan out internally over
 * a user loop, so they can never use the global concurrency ceiling. Keeping
 * them at the global `maxInstances` reserves capacity that is never used and
 * starves deploys of the request-serving functions that do need it. Two leaves
 * headroom for an overlapping run without meaningfully reserving quota.
 */
export const SCHEDULED_MAX_INSTANCES = 2;
