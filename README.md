# NxN_Systolic_Array
An N×N systolic array that multiplies two signed matrices (C = A × B), written in SystemVerilog. Entirely scalable!

<img width="937" height="403" alt="image" src="https://github.com/user-attachments/assets/e3735686-4fea-4e94-b0d5-00fc18efb523" />

# How it works

<img width="960" height="428" alt="image" src="https://github.com/user-attachments/assets/6d909288-d4a5-49fc-936f-3a4446b9b327" />

=> This Image I found online helped me a lot


- Matrix A flows left to right along the rows of PEs, and matrix B flows top to bottom along the columns.
- Each PE multiplies its two inputs, adds the product to a running sum on the clock edge, and passes both inputs on to its neighbours one cycle later.
- Row `r` of A and column `r` of B are delayed by `r` cycles at the array edge (up to N-1 cycles), so matching elements arrive at PE(i,j) on the same cycle.
- The full result takes 3N-2 cycles.

### Architecture

- Each square in the array is a PE module that holds its own running-sum register.
- The accumulator is sized for the worst case, N × (-128)² = 65536 for a 4×4 with 8-bit inputs, which needs 18 bits (`2*W + $clog2(N)`).
### Code

- **Counter:** counts cycles up to 3N-2, then raises `done` and freezes the PEs.
- **Skewing:** `a_edge[r]` and `b_edge[r]` feed the left and top edges. With `k = cycle - r`, they send 0 until `k` reaches 0, then send the next element each cycle, then 0 again once `k` reaches N:

    ```systemverilog
    a_edge[r] = (k >= 0 && k < N) ? A[r][k] : '0;
    b_edge[r] = (k >= 0 && k < N) ? B[k][r] : '0;
    ```
    
- **Interconnect:** `a_w[i][j]` and `b_w[i][j]` feed PE(i,j). Each array has one extra entry in the direction of travel for the last PE’s output.
- **Generate:** a nested `generate` loop instantiates the N×N PEs and wires each one’s outputs into its neighbors’ inputs.

# Running the Simulation

### ModelSim

The design uses unpacked array ports, so use a simulator with SystemVerilog support. Download the relevant files and use the following commands in ModelSim:

```systemverilog
vlib work
vlog -sv sys_NxN_multiplier.sv tb_sys_NxN_multiplier.sv
vsim -voptargs=+acc work.tb_sys_NxN_multiplier
add wave -r /*
config wave -signalnamewidth 1
run 450ns
```
To test a different size, simply change `N` and `W` in the testbench file

### Expected Output:

```
4x4 SYSTOLIC ARRAY, 8-bit inputs, 18-bit accumulators
Test 0: PASS (all 16 elements matched)
Test 1: PASS (all 16 elements matched)
Test 2: PASS (all 16 elements matched)
STATUS: ALL TESTS PASSED
```

### Verification

1) Random - Random signed values over the full input range
2) Worst case - Every entry is the most negative value, checking the accumulator width
3) Identity × random - Result should equal the second matrix

Results are compared against a software golden model computed in the testbench.

# Results 
Simulated using Quartus Prime Lite on Cyclone V 5CGXFC7C7F23C8, slow 85°C model, virtual I/O

| N | W | ALMs | Registers | DSPs | Fmax | Latency |
|---|---|------|-----------|------|------|---------|
| 4 | 8 |  598   |    421      |  16  | 93 MHz | 10 cycles (~107 ns) |
