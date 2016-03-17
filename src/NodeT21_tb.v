module NodeT21_tb ();

reg clk = 1'b0;
reg rst = 1'b1;
reg [10:0] inData = 'd0;
wire [10:0] outData;


NodeT21 (
    // Config/Run signals
    .clk(clk),              ///< Clock for module. Should be same for all nodes.
    .rst(rst),              ///< Reset, active high
    .instrAddr(4'd0),  ///< [3:0] Address to write instr to
    .instrData(16'd0), ///< [15:0] Instruction to load into program memory
    .writeInstr(1'b0),       ///< Write instr to program memory

    // Port Signals
    .inUp,         ///< [10:0] Input from upper node
    .inRight,      ///< [10:0] Input from right node
    .inDown,       ///< [10:0] Input from lower node
    .inLeft,       ///< [10:0] Input from left node
    .readyUp,                    ///< Up node has data to pass
    .readyRight,                 ///< Right node has data to pass
    .readyDown,                  ///< Down node has data to pass
    .readyLeft,                  ///< Left node has data to pass
    .doneUp,                     ///< Up node received data from this node
    .doneRight,                  ///< Right node received data from this node
    .doneDown,                   ///< Down node received data from this node
    .doneLeft,                   ///< Left node received data from this node
    .outData, ///< [10:0] Data being sent to another node
    .recvUp,                ///< Received data from up node
    .recvRight,             ///< Received data from right node
    .recvDown,              ///< Received data from down node
    .recvLeft,              ///< Received data from left node
    .sendUp,                ///< Sending data to up node
    .sendRight,             ///< Sending data to right node
    .sendDown,              ///< Sending data to down node
    .sendLeft               ///< Sending data to left node
);
