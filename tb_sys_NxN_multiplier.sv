`timescale 1ns / 1ps

module tb_sys_NxN_multiplier;

    // ---- change these two to test different sizes ----
    parameter N = 4;   // array is N x N
    parameter W = 8;   // signed input width in bits
    // --------------------------------------------------

    localparam ACC_W     = 2*W + $clog2(N);
    localparam NUM_TESTS = 3;

    reg clock;
    reg resetn;
    reg signed [W-1:0]     A [N-1:0][N-1:0];
    reg signed [W-1:0]     B [N-1:0][N-1:0];
    wire signed [ACC_W-1:0] C [N-1:0][N-1:0];
    wire done;

    reg signed [ACC_W-1:0] expected_C [N-1:0][N-1:0];

    integer i, j, k, t;
    integer errors, total_errors;
    integer seed;

    // Device under test
    sys_NxN_multiplier #(.N(N), .W(W)) u_dut (
        .clock  (clock),
        .resetn (resetn),
        .A      (A),
        .B      (B),
        .C      (C),
        .done   (done)
    );

    // 100 MHz clock
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // scales with N (each test needs about 3N cycles plus reset)
    initial begin
        #(NUM_TESTS * 10 * (3*N + 10));
        $display("TIMEOUT: done never asserted");
        $finish;
    end

    // Fill A and B for a given test number
    task load_matrices(input integer test_id);
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    case (test_id)
                        0: begin // random values over the full signed range
                            A[i][j] = $random(seed);
                            B[i][j] = $random(seed);
                        end
                        1: begin // worst case: every entry is the most negative value
                            A[i][j] = -(1 << (W-1));
                            B[i][j] = -(1 << (W-1));
                        end
                        default: begin // identity times random, so C should equal B
                            A[i][j] = (i == j) ? 1 : 0;
                            B[i][j] = $random(seed);
                        end
                    endcase
                end
            end
        end
    endtask

    // Software golden model
    task compute_expected;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    expected_C[i][j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        expected_C[i][j] = expected_C[i][j] + (A[i][k] * B[k][j]);
                end
            end
        end
    endtask

    // Reset, run, wait for done, compare
    task run_test(input integer test_id);
        begin
            resetn = 0;
            load_matrices(test_id);
            compute_expected;

            @(posedge clock);
            @(posedge clock);
            @(negedge clock);   // release reset away from the active edge
            resetn = 1;

            wait (done == 1);
            #1;

            errors = 0;
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (C[i][j] !== expected_C[i][j]) begin
                        errors = errors + 1;
                        $display("  MISMATCH C[%0d][%0d]: HW = %0d, expected = %0d",
                                 i, j, C[i][j], expected_C[i][j]);
                    end
                end
            end

            if (errors == 0)
                $display("Test %0d: PASS (all %0d elements matched)", test_id, N*N);
            else
                $display("Test %0d: FAIL (%0d mismatches)", test_id, errors);

            total_errors = total_errors + errors;
        end
    endtask

    // Main sequence
    initial begin
        $dumpfile("systolic_array.vcd");
        $dumpvars(0, tb_sys_NxN_multiplier);

        seed         = 1;
        total_errors = 0;
        resetn       = 0;

        $display("%0dx%0d SYSTOLIC ARRAY, %0d-bit inputs, %0d-bit accumulators",
                 N, N, W, ACC_W);

        for (t = 0; t < NUM_TESTS; t = t + 1)
            run_test(t);

        if (total_errors == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: FAILED with %0d total mismatches", total_errors);

    end

endmodule