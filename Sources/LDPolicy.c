#include "LDPolicy.h"
#include <math.h>
#include <string.h>
bool LDNoticeReady(double now, double shownAt) {
    return isfinite(now) && isfinite(shownAt) && shownAt >= 0 && now - shownAt >= 2.0;
}
double LDInterval(double value) {
    if (!isfinite(value)) return 30;
    return fmin(300, fmax(30, floor(value)));
}
double LDRetryInterval(double interval, unsigned failures) {
    double delay = LDInterval(interval);
    for (unsigned i = 0; i < failures && delay < 300; i++) delay *= 2;
    return fmin(300, delay);
}
bool LDDue(double now, double lastAttempt, double interval, unsigned failures) {
    return lastAttempt <= 0 || now - lastAttempt >= LDRetryInterval(interval, failures);
}
static bool contains(const char *key, const char *const *items, size_t count) {
    if (!key || !*key) return false;
    for (size_t i = 0; i < count; i++) if (items[i] && strcmp(key, items[i]) == 0) return true;
    return false;
}
size_t LDNewItems(const char *const *current, size_t count,
                  const char *const *previous, size_t previousCount,
                  const char *const *seen, size_t seenCount,
                  bool baselineValid, bool previousComplete,
                  bool *selected, bool *gap) {
    size_t limit = count, result = 0;
    *gap = false;
    for (size_t i = 0; i < count; i++) selected[i] = false;
    if (!baselineValid) return 0;
    if (!previousComplete) {
        for (size_t i = 0; i < count; i++) {
            if (contains(current[i], previous, previousCount)) { limit = i; break; }
        }
        // No common anchor: record as newly observed, never as an exact like time.
        *gap = limit == count && count > 0;
    }
    for (size_t i = 0; i < limit; i++) {
        if (!current[i] || !*current[i] || contains(current[i], previous, previousCount) ||
            contains(current[i], seen, seenCount) || contains(current[i], current, i)) continue;
        selected[i] = true;
        result++;
    }
    return result;
}
