# Kernel

## About

This is a bare-metal kernel-ish program which runs on the RISC-V CPU architecture. RISC-V is a modern, open source architecture which avoids some of the mistakes of its predecessors such as x86-64. Since your computer almost certainly _isn't_ runnin on RISC-V, I use a VM to emulate the instruction set so that we can run this architecture-dependent program on any computer.

## What it does

At the moment, the boot process is as follows:

- The system firmware, supplied in `fw_dynamic.bin` loads my compiled code at the physical address 0x81000000.
- The code starts in src/entry.zig, when the firmware jumps to the `_start` function (which is written in assembly).
- The `_start` function calls the `init_pagetables` function which initialises the page tables used to set up paging.
- `init_pagetables` creates a pagetable which maps virtual addresses starting from 0x81000000 to physical addresses starting from, again, 0x81000000. Mapping a virtual address to the same physical address is called 'identity mapping' and is necessary to keep the same code running before and after enabling kernel paging. Otherwise, the address stored in the program counter register would suddenly point to a completely different section of memory after we enable paging!
- Next, a pagetable is created which maps virtual addresses from 0xffffffff80000000 to our main kernel code. This is at _negative_ 2GiB in two's complement.
- Paging is enabled by writing a certain value into a CPU register then we return to the `_start` function to jump to our main kernel code in `main.zig`.
- `main.zig` is where the main behaviour of the kernel happens. We enable interrupts on the current CPU core, initialising the `stvec` register to the address of our ISR. Then, we set up timer interrupts, and configure the timer to fire an interrupt a short period in the future.
- We then enter into a loop of stalling the CPU to wait for interrupts. When an interrupt happens, the CPU jumps to the code in `interrupt_handler`. This clears the interrupt flag on the CPU so that a new interrupt can arrive, sets the timer to fire again 1 second into the future, and prints a message to the console.
- That's about it! Printing to the console uses a function of the system firmware (quite like the BIOS on most systems) defined in sbi.zig.

## Actually running it

I've set up a [devcontainer](https://code.visualstudio.com/docs/devcontainers/containers), so if you install docker on your computer you should be able to click on the little arrows at the bottom left of VSCode to enter into a container (just click 'Reopen in Container' in the menu that pops up). From there, you can open the VSCode terminal and run the following command:

```
zig build run
```

To compile the program with Zig and run it in a VM, both of which will be installed automatically.
