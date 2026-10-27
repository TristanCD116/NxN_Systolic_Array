// A x B = C

module sys_NxN_multiplier 
	#(parameter N = 4, W = 8)
	(
	input clock,
	input resetn,
	input signed [W-1:0] A [N-1:0][N-1:0],
	input signed [W-1:0] B [N-1:0][N-1:0], 
	output signed [2*W + $clog2(N) - 1:0] C [N-1:0][N-1:0],
	output done
	);
	
	
	
	// count the number of cycles 3N-2
	reg signed [$clog2(3*N):0] cycle;
	
	always @(posedge clock) begin
	
       if (!resetn)        
			cycle <= 0;
			
       else if (cycle != 3*N-2)  
			cycle <= cycle + 1;
   end
    
	assign done = (cycle == 3*N-2);
	
	// applying the skewing on the edges feeding into the outer PEs
	
	reg signed [W-1:0] a_edge [N-1:0];
	reg signed [W-1:0] b_edge [N-1:0];
	
	integer r, k;

	always @(*) begin
	
		for (r = 0; r < N; r = r + 1) begin
			k = cycle - r;
         a_edge[r] = (k >= 0 && k < N) ? A[r][k] : 0; // rows of A
         b_edge[r] = (k >= 0 && k < N) ? B[k][r] : 0; // cols of B
      end
	end
	
	// signal interconnects
	wire signed [W-1:0] a_w [0:N-1][0:N];   // a_w[i][j] feeds PE(i,j) row by row
   wire signed [W-1:0] b_w [0:N][0:N-1];   // b_w[i][j] feeds PE(i,j) col by col
		
	genvar i, j;
	generate gen_array:
	
		// assign the outermost vars
		for (i = 0; i < N; i = i + 1) begin : g_assign
			assign a_w [i][0] = a_edge[i];
			assign b_w [0][i] = b_edge[i];
		end
			
		for (i = 0; i < N; i = i + 1) begin : g_row
			for (j = 0; j < N; j = j + 1) begin : g_col
				
				PE #(.N(N), .W(W)) u_PE 
				   (
					.clock(clock), 
					.resetn(resetn), 
					.en(!done),
					.a_in(a_w[i][j]),
					.b_in(b_w[i][j]),
					.a_out(a_w[i][j+1]),
					.b_out(b_w[i+1][j]),
					.sum(C[i][j])
				   );
			end
		end
	endgenerate
endmodule
			
module PE 

	#(parameter N = 4, W = 8)
	(
   input clock,
   input resetn,
	input en,
   input signed [W-1:0] a_in, b_in,
   output reg signed [W-1:0] a_out, b_out,
   output reg signed [2*W+$clog2(N)-1:0] sum
	);
	
   always @(posedge clock) begin
       if (!resetn) begin
           a_out <= 0;
           b_out <= 0;
           sum <= 0;
       end 
		  
		  else if (en) begin
            sum   <= sum + a_in * b_in;
            a_out <= a_in;
            b_out <= b_in;
        end
    end
endmodule