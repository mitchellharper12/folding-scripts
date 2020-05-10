yield_hook.so: sched_yield_hook.c
	gcc -march=znver1 -fPIC -shared sched_yield_hook.c -g -O3 -o yield_hook.so -ldl
