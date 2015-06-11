module NodeT30_tb ();

reg clk = 1'b0;
reg rst = 1'b1;
always #1 clk = ~clk;
initial #5 rst = 1'b0;


reg [10:0] in0 = 11'd1;
reg [10:0] in1 = 11'd0;
reg [3:0] ready = 4'd0;
reg [3:0] done = 4'd0;
wire [3:0] recv;
wire [3:0] send;
wire [10:0] outData;

integer i;
integer sum = 0;

initial begin
	wait(~rst);
	for (i=0; i<40; i=i+1) begin
		in0 = i;
		ready[0] = 1'b1;
		wait(recv);
		@(posedge clk);
	end
	ready[0] = 1'b0;
end

initial begin
	wait(~rst);
	#20
	while (send[0]) begin
		@(posedge clk);
		sum = sum + outData;
		done[0] <= 1'b1;
		@(posedge clk);
		done[0] <= 1'b0;
	end
end




NodeT30 #(
	.DEPTH(32)
) uut (
    // Config/Run signals
    .clk(clk),         ///< Clock for module. Should be same for all nodes.
    .rst(rst),         ///< Reset, active high

    // Port Signals
    .in0(in0),         ///< [10:0] Input from node 0
    .in1(in1),         ///< [10:0] Input from node 1
    .in2(11'd0),       ///< [10:0] Input from node 2
    .in3(11'd0),       ///< [10:0] Input from node 3
    .ready(ready),     ///< [3:0] Neighbor has data to pass to this node
    .done(done),       ///< [3:0] Neighbor received data from this node
    .outData(outData), ///< [10:0] Data being sent to another node
    .recv(recv),       ///< [3:0] Received data from neighbor
    .send(send)        ///< [3:0] Sending data to neighbor
);

endmodule
