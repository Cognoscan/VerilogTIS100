
module NodeT30 #(
	parameter DEPTH=32 // Should be a power of 2
)(
    // Config/Run signals
    input clk,              ///< Clock for module. Should be same for all nodes.
    input rst,              ///< Reset, active high

    // Port Signals
    input signed [10:0] in0,           ///< Input from node 0
    input signed [10:0] in1,           ///< Input from node 1
    input signed [10:0] in2,           ///< Input from node 2
    input signed [10:0] in3,           ///< Input from node 3
    input [3:0] ready,                 ///< Neighbor has data to pass to this node
    input [3:0] done,                  ///< Neighbor received data from this node
    output reg  signed [10:0] outData, ///< Data being sent to another node
    output reg [3:0] recv,             ///< Received data from neighbor
    output wire [3:0] send             ///< Sending data to neighbor
);

parameter integer CNT_WIDTH = $clog2(DEPTH);

wire [CNT_WIDTH:0] nextCount;

reg [10:0] stack[DEPTH-1:0];
reg [CNT_WIDTH-1:0] count;
reg empty;
wire full;

integer i;

assign send = {4{~empty}}; // Data is always available to whoever wants it.

initial begin
	for (i=0; i<DEPTH; i=i+1) begin
		stack[i] = 11'd0;
	end
	count = 'd0;
	empty = 1'b1;
end

always @(posedge clk) begin
	outData <= stack[count]; // Output the top of the stack
end

assign nextCount = count + |ready - |done;
assign full = (nextCount == DEPTH);
always @(posedge clk) begin
	if (rst) begin
		count <= 'd0;
		empty <= 1'b1;
	end else begin
		// Increment count as appropriate
		if ((nextCount < DEPTH) && !empty) begin
			count <= nextCount;
			empty <= 1'b0;
		end else if ((nextCount == 'd1) && empty) begin
			count <= 0;
			empty <= 1'b0;
		end else if (nextCount >= DEPTH) begin
			count <= 0;
			empty <= 1'b1;
		end
		// Push data onto stack
		if (!full) begin
			if (ready[0]) begin
				stack[count] <= in0;
				recv <= 4'b0001;
			end else if (ready[1]) begin
				stack[count] <= in1;
				recv <= 4'b0010;
			end else if (ready[2]) begin
				stack[count] <= in2;
				recv <= 4'b0100;
			end else if (ready[3]) begin
				stack[count] <= in3;
				recv <= 4'b1000;
			end else begin
				recv <= 4'b0000;
			end
		end else begin
			recv <= 4'b0000;
		end
	end
end


endmodule
