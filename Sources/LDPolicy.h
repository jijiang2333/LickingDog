#ifndef LDPolicy_h
#define LDPolicy_h
#include <stdbool.h>
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
bool LDNoticeReady(double now, double shownAt);
double LDInterval(double value);
double LDRetryInterval(double interval, unsigned failures);
bool LDDue(double now, double lastAttempt, double interval, unsigned failures);
/* New prefixes only for a partial previous page; tail fill is not a new like. */
size_t LDNewItems(const char *const *current, size_t count,
                  const char *const *previous, size_t previousCount,
                  const char *const *seen, size_t seenCount,
                  bool baselineValid, bool previousComplete,
                  bool *selected, bool *gap);
#ifdef __cplusplus
}
#endif
#endif
