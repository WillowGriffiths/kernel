# Kernel

## About

This is a bare-metal kernel-ish program which runs on the RISC-V CPU architecture. RISC-V is a modern, open source architecture which avoids some of the mistakes of its predecessors such as x86-64. Since your computer almost certainly _isn't_ runnin on RISC-V, I use a VM to emulate the instruction set so that we can run this architecture-dependent program on any computer.

## What it does

At the moment, the boot process is as follows:

### Early boot

- The system firmware, supplied in `fw_dynamic.bin` loads my compiled code into memory, starting at the physical address 0x81000000.
- The firmware chooses one of the virtual machine's four (simulated) cpu cores to start running my code. In RISC-V, cores are known as 'harts' short for hardware threads.
- The firmware jumps to the function `_start`, the entrypoint for my code. This is defined as an assembly snippet in `entry.zig`. A normal zig function couldn't be used as no stack has been initialised yet.
- `_start` is passed two arguments by the firmware: the id of the current hart in register a0 and the memory address of the device tree in a1 (a structure in memory which informs the kernel about details of the machine).
- I don't use the device tree at the moment, so we can ignore that. However, I copy the hart id from register a0 into the tp (thread pointer) register for later use.
- I load the address of a temporary stack used for booting into the sp (stack pointer) register then jump to the `init_pagetables` function.
- `init_pagetables` builds a page table, which specifies which addresses in virtual memory map to which pages in physical memory.
- All of the memory pages holding the boot code are mapped to a virtual address equal to their physical address. This is known as identity mapping and is necessary for our code to keep functioning after paging is enabled. Otherwise the program counter would suddenly be pointing to an invalid address.
- Pages holding the kernel code are mapped to a range of virtual addresses starting at `0xffffffff80000000` corresponding to the first physical page storing the code. A few extra pages after this are mapped for later use.
- This address can be thought of as 2GiB away from the very highest 64-bit address (0xffffffffffffffff), or you can think of it as -2GiB if you treat the address as a signed (two's complement) integer.
- The address of the pagetable just initialised is put into the `satp` register to enable paging.
- Some information about the memory layout is copied into a structure to be used later.
- The code returns to the `_start` function, which loads a different stack into the stack pointer before jumping to the `main` function, defined in `main.zig`.

### Initial Initialisation

- The `main` function first enables interrupts for the current core. This is done by writing the address of the ISR into the `stvec` register before clearing a bit in the `sstatus` register to tell the CPU that we're ready for interrupts.
- Then, the memory system is initialised:

### Memory Initialisation

- A buddy allocator is initialised to help share the system's memory between code that needs it. This represents all of the system's allocatable memory as a binary tree, where parts of memory are successively divided in two, down to a minimum allocation size of one page (4KiB).
- The allocator's binary tree (represented as a `MemoryNode` in `memory.zig`) is initialised with one page already allocated, which is used to store the tree itself. This is the first free page after the kernel code, which was mapped previously.
- Once the allocator is initialised, it is used to allocate pages for a new page table which maps the kernel code as before, as well as all of physical RAM starting at the virtual address `0xffffffd600000000`, or -168GiB. This leaves a 166GiB gap before the start of the kernel code, which should leave enough space to map all available system memory.
- The new page table is activated as before and we return to `main` for the next stage:

### Multi-core Initialisation

- Our code is, as of memory initialisation, only running on one of the virtual machine's four harts. The `initHarts` function gets the other three up and running.
- Firstly, three more stacks are allocated using the newly initialised memory allocator to be used by the other harts.
- Three structs are allocated and filled with the information needed for the other harts to boot, namely the address of our main pagetable in memory and the address of the hart's stack.
- A firmware function is used to start each hart running at `_secondaryStart`, defined in `entry.zig`, and to pass in the _physical_ address of the init info for that hart. We need to use the physical address as paging will not be enabled when it first boots.
- `_secondaryStart` performs a few initialisation tasks: first, it stores the current hart id in tp, which was again passed by the firmware in a0. Then, it stores the address of the page table and stack from the initialisation info struct passed to it into a0 and a1 respectively.
- The initial page table (prepared by `init_pagetables`) is activated before jumping to the `secondaryMain` function defined in `main.zig`.
- This activates the page table and stack stored in a0 and a1 respectively before jumping to the `main` function, with `boot_hart` set to false.
- This time, `main` simply prints a hello message before waiting indefinitely on each hart. The print function needs to use a spinlock to avoid concurrency issues which would otherwise arise. This functions by setting a boolean flag when one hart needs to lock a section of code. Then, if another tries to access it simultaneously, it will simply wait until the original thread sets it to false and then setting it to true again. For slower functions, this can become inefficient because one or more harts spend a bunch of time just waiting for a lock to be released.

### Main loop

- Back on the main hart, we tell the CPU to send a timer interrupt one second in the future and print a message before waiting indefinitely.
- After a second, the timer interrupt is fired. The interrupt service routine decrements a counter, which starts at 5, before clearing the pending interrupt and telling the CPU to send another timer interrupt another second into the future.
- When the counter reaches 0, the isr tells the firmware to shut the machine down.

### Other Info

The memory layout is copied from [Linux](https://github.com/torvalds/linux/blob/master/Documentation/arch/riscv/vm-layout.rst). There are practically infinite layouts you could choose but Linux's seems sensible.

## Actually running it

I've set up a [devcontainer](https://code.visualstudio.com/docs/devcontainers/containers), so if you install docker on your computer you should be able to click on the little arrows at the bottom left of VSCode to enter into a container (just click 'Reopen in Container' in the menu that pops up). From there, you can open the VSCode terminal and run the following command:

```
zig build run
```

To compile the program with Zig and run it in a VM, both of which will be installed automatically.
