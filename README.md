An assortment of scripts used to wrangle folding
processes, more documentation forthcoming.

## Important files:

### [better\_pinning.sh](./foldingathome/better_pinning.sh)

A script (currently very tailored to my TR 1920x machine) for
pinning folding at home cores to specific threads, and moving
all other threads appropriately.

### [irq\_move.sh](./rosetta@home/irq_move.sh)

A script for moving kernel threads and IRQs around to
processors you specify (mostly so they don't interrupt
folding threads).

### [FahCore\_22](./foldingathome/FahCore_22)

A bash script interposed between the F@H manager and the GPU
folding core that forces all memory allocations to be bound to
NUMA node 1, for reasons I will explain later.


### [FahCore\_a7](./foldingathome/FahCore_a7)

A bash script interposed between the F@H manager and the CPU
folding core that forces all memory allocations to be bound to
the node upon which a thread is running. Also sets up the LD\_PRELOAD
for not calling `sched_yield`.

### [sched\_yield\_hook.c](./foldingathome/sched_yield_hook.c)

A C file that, when built using the provided Makefile, produces a shared
object that can be preloaded that always causes the libc wrapper over the
`sched_yield` syscall to return 0 before every yielding to the kernel.
Also optionally can be built in a configruation that allows for selective
yielding, but there's no evidence there's any use case where that leads to
a performance gain.

### [Makefile](./foldingathome/Makefile)

Builds the shared library described above using GCC settings tuned for
the Zen microarcheticture.

## License:

Dual licensed under the MIT license and the AntiLicense, see [LICENSE.md](./LICENSE.md).
