#define _GNU_SOURCE
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdarg.h>
#include <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>
#include <time.h>

// If the below is set to 0, we will always return immediately
// Otherwise, we will selectively yield based on the modulus of a random int
#define SELECTIVE_YIELD 1

#if SELECTIVE_YIELD

#define YIELD_DEBUG_VAR "YIELD_DEBUG"
#define DEFAULT_YIELD_MODULUS 8
#define YIELD_MODULUS_VAR "YIELD_MODULUS"
#define ENABLE_DYNAMIC_YIELD_DEBUG 1

static void yield_hook_init_rand() __attribute__((constructor));
static void yield_hook_debug_printf(char*, ...);
static int (*orig_sched_yield)();
static int yield_hook_modulus;

# if ENABLE_DYNAMIC_YIELD_DEBUG
static bool yield_hook_debug;
# else
#define yield_hook_debug 0
# endif // ENABLE_DYNAMIC_YIELD_DEBUG


static void yield_hook_debug_printf(char* buf, ...) {
	if (yield_hook_debug) {
		va_list args;
		va_start(args, buf);
		pid_t pid = getpid();
		fprintf(stderr, "yield_hook(%d): ", pid);
		vfprintf(stderr, buf, args);
	}
	return;
}

static void yield_hook_init_rand() {
	orig_sched_yield = dlsym(RTLD_NEXT, "sched_yield");
# if ENABLE_DYNAMIC_YIELD_DEBUG
	yield_hook_debug = (bool) getenv(YIELD_DEBUG_VAR);
# endif
	char* modulus_val = getenv(YIELD_MODULUS_VAR);
	if (!modulus_val) {
		yield_hook_debug_printf("no modulus specified, will never yield\n");
		return;
	}
	yield_hook_debug_printf("initializing rand\n");
	srand(time(NULL));
	if (modulus_val) {
		yield_hook_modulus= atoi(modulus_val);
	} else {
		yield_hook_modulus = DEFAULT_YIELD_MODULUS;
	}

}
#endif // SELECTIVE_YIELD

int sched_yield() {
#if SELECTIVE_YIELD
	if (yield_hook_modulus) {
		int randval = rand();
		yield_hook_debug_printf("yield_hook: Modulus: %d\n", randval);
		if (randval % yield_hook_modulus == 0) {
			yield_hook_debug_printf("yield_hook: Calling original yield\n");
			return orig_sched_yield();
		}
	}
#endif
	return 0;
}
