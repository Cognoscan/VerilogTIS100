//
// Registers
// =========
//
// 0 - NIL
// 1 - ACC
// 2 - ANY
// 3 - LAST
// 4 - Neighbor 0
// 5 - Neighbor 1
// 6 - Neighbor 2
// 7 - Neighbor 3
//
// Instruction Set
// ===============
//
// A is a 3-bit value corresponding to a register.
// B is a 12-bit value: if MSB is 1, bits [10:8] specify a register. Otherwise bits [10:0] specify a constant.
// C is a 4-bit value pointing to an instruction in program memory.
// X is a don't care - this data is ignored.
//
// 0aaabbbbbbbbbbbb - MOV b, a. Moves B to A. All zeros = MOV 0, NIL = NOP
// 1000bbbbbbbbbbbb - ADD b
// 1001bbbbbbbbbbbb - SUB b
// 1010bbbbbbbbbbbb - JRO b. Only uses lower 4 bits of constant/register contents. Rollover may occur.
// 1011bbbbbbbbbbbb - RESERVED
// 110000ccccxxxxxx - JMP c
// 110001ccccxxxxxx - JEZ c
// 110010ccccxxxxxx - JNZ c
// 110011ccccxxxxxx - JGZ c
// 110100ccccxxxxxx - JLZ c
// 110NNNccccxxxxxx - RESERVED for all N > 4
// 1110000xxxxxxxxx - NEG
// 1110001xxxxxxxxx - SAV
// 1110010xxxxxxxxx - SWP
// 1110NNNxxxxxxxxx - RESERVED for all N > 2.


module NodeT21 #(
    parameter PROGRAM0  = 16'b0000_0000_0000_0000,
    parameter PROGRAM1  = 16'b0000_0000_0000_0000,
    parameter PROGRAM2  = 16'b0000_0000_0000_0000,
    parameter PROGRAM3  = 16'b0000_0000_0000_0000,
    parameter PROGRAM4  = 16'b0000_0000_0000_0000,
    parameter PROGRAM5  = 16'b0000_0000_0000_0000,
    parameter PROGRAM6  = 16'b0000_0000_0000_0000,
    parameter PROGRAM7  = 16'b0000_0000_0000_0000,
    parameter PROGRAM8  = 16'b0000_0000_0000_0000,
    parameter PROGRAM9  = 16'b0000_0000_0000_0000,
    parameter PROGRAM10 = 16'b0000_0000_0000_0000,
    parameter PROGRAM11 = 16'b0000_0000_0000_0000,
    parameter PROGRAM12 = 16'b0000_0000_0000_0000,
    parameter PROGRAM13 = 16'b0000_0000_0000_0000,
    parameter PROGRAM14 = 16'b0000_0000_0000_0000,
    parameter PROGRAM15 = 16'b0000_0000_0000_0000
)(
    // Config/Run signals
    input clk,              ///< Clock for module. Should be same for all nodes.
    input rst,              ///< Reset, active high
    input [3:0] instrAddr,  ///< Address to write instr to
    input [15:0] instrData, ///< Instruction to load into program memory
    input writeInstr,       ///< Write instr to program memory

    // Port Signals
    input signed [10:0] in0,          ///< Input from node 0
    input signed [10:0] in1,          ///< Input from node 1
    input signed [10:0] in2,          ///< Input from node 2
    input signed [10:0] in3,          ///< Input from node 3
    input [3:0] ready,                ///< Neighbor has data to pass to this node
    input [3:0] done,                 ///< Neighbor received data from this node
    output reg signed [10:0] outData, ///< Data being sent to another node
    output reg [3:0] recv,            ///< Received data from neighbor
    output reg [3:0] send             ///< Sending data to neighbor
);

///////////////////////////////////////////////////////////////////////////
// Parameter Declarations
///////////////////////////////////////////////////////////////////////////

localparam REG_ACC   = 0;
localparam REG_NIL   = 1;
localparam REG_ANY   = 2;
localparam REG_LAST  = 3;
localparam REG_0     = 4;
localparam REG_1     = 5;
localparam REG_2     = 6;
localparam REG_3     = 7;

///////////////////////////////////////////////////////////////////////////
// Signal Declarations
///////////////////////////////////////////////////////////////////////////

wire [15:0] instr;
wire accZero;
wire accNegative;

reg [15:0] program[15:0]; ///< Program memory

reg signed [10:0] acc;
reg signed [10:0] bak;
reg signed [10:0] nextAcc;
reg signed [10:0] nextBak;
reg signed [10:0] nextOutData;
reg signed [10:0] src;
reg [3:0] instrPointer;
reg [3:0] nextInstrPointer;
reg [1:0] lastReg;
reg [1:0] nextLast;
reg [1:0] nextLastReg;
reg movState;
reg nextMovState;
reg received;
reg canGet;

///////////////////////////////////////////////////////////////////////////
// Main Code
///////////////////////////////////////////////////////////////////////////

// Initialize program memory
initial begin
    program[0 ] = PROGRAM0 ;
    program[1 ] = PROGRAM1 ;
    program[2 ] = PROGRAM2 ;
    program[3 ] = PROGRAM3 ;
    program[4 ] = PROGRAM4 ;
    program[5 ] = PROGRAM5 ;
    program[6 ] = PROGRAM6 ;
    program[7 ] = PROGRAM7 ;
    program[8 ] = PROGRAM8 ;
    program[9 ] = PROGRAM9 ;
    program[10] = PROGRAM10;
    program[11] = PROGRAM11;
    program[12] = PROGRAM12;
    program[13] = PROGRAM13;
    program[14] = PROGRAM14;
    program[15] = PROGRAM15;
end

// Write to program memory
always @(posedge clk) begin
    if (writeInstr) program[instrAddr] <= instrData;
end
assign instr = program[instrPointer];

always @(posedge clk) begin
    if (rst) begin
        instrPointer <= 4'd0;
        acc          <= 11'd0;
        bak          <= 11'd0;
        outData      <= 11'd0;
        lastReg      <= 2'd0;
        recv         <= 4'd0;
        movState     <= 1'b0;
    end else begin
        instrPointer <= nextInstrPointer;
        acc          <= nextAcc;
        bak          <= nextBak;
        lastReg      <= nextLastReg;
        outData      <= nextOutData;
        movState     <= nextMovState;

        if (received && (instr[10:8] > 1)) begin
            case (nextLastReg)
                2'd0 : recv <= 4'b0001;
                2'd1 : recv <= 4'b0010;
                2'd2 : recv <= 4'b0100;
                2'd3 : recv <= 4'b1000;
            endcase
        end else begin
            recv <= 4'd0;
        end
    end
end

assign accZero = (acc == 11'd0);
assign accNegative = acc[10];

// CPU State machine
always @(*) begin
    // Figure out Source register first
    src = 'd0;
    nextLast = lastReg;
    canGet = 1'b0;
    if (instr[11]) begin // Register
        case (instr[10:8])
            REG_ACC   : begin src = acc; nextLast = lastReg; canGet = 1'b1; end
            REG_NIL   : begin src = 'd0; nextLast = lastReg; canGet = 1'b1; end
            REG_ANY   : begin
                if      (ready[0]) begin src = in0; nextLast = 2'd0; canGet = 1'b1; end
                else if (ready[1]) begin src = in1; nextLast = 2'd1; canGet = 1'b1; end
                else if (ready[2]) begin src = in2; nextLast = 2'd2; canGet = 1'b1; end
                else if (ready[3]) begin src = in3; nextLast = 2'd3; canGet = 1'b1; end
                else               begin src = 'd0; nextLast = 2'd0; canGet = 1'b0; end
            end
            REG_LAST  : begin
                case (lastReg)
                    2'd0 : begin src = in0; nextLast = 2'd0; canGet = ready[0]; end
                    2'd1 : begin src = in1; nextLast = 2'd1; canGet = ready[1]; end
                    2'd2 : begin src = in2; nextLast = 2'd2; canGet = ready[2]; end
                    2'd3 : begin src = in3; nextLast = 2'd3; canGet = ready[3]; end
                endcase
            end
            REG_0 : begin src = in0; nextLast = 2'd0; canGet = ready[0]; end
            REG_1 : begin src = in1; nextLast = 2'd1; canGet = ready[1]; end
            REG_2 : begin src = in2; nextLast = 2'd2; canGet = ready[2]; end
            REG_3 : begin src = in3; nextLast = 2'd3; canGet = ready[3]; end
        endcase
    end else begin // Constant
        src = instr[10:0];
        nextLast = lastReg;
        canGet = 1'b1;
    end

    // Defaults
    nextInstrPointer = instrPointer + 1;
    nextAcc          = acc;
    nextBak          = bak;
    nextLastReg      = lastReg;
    nextOutData      = outData;
    nextMovState     = movState;
    received         = 1'b0;
    send             = 4'b0000;
    casez (instr[15:9])
        7'b0?????? : begin // MOV (2 states)
            // Check if source is ready
            if (!movState && canGet) begin
                nextOutData = src;
                nextMovState = 1'b1;
                nextInstrPointer = instrPointer; // Block
                nextLastReg = nextLast;
                received = instr[11];
            end else if (movState) begin
                // Check if destination is ready
                case (instr[14:12])
                    REG_ACC : begin
                        nextAcc = outData;
                        nextMovState = 1'b0;
                    end
                    REG_NIL : begin
                        nextMovState = 1'b0;
                    end
                    REG_ANY : begin
                        // Edge case: Sending to ANY means that multiple nodes could receive the data.
                        // Send out to all nodes
                        send = 4'b1111;
                        // Block until a done signal is received
                        if (~(|done)) begin
                            nextInstrPointer = instrPointer;
                        end else begin
                            nextMovState = 1'b0;
                        end
                    end
                    REG_LAST : begin
                        send[lastReg] = 1'b1;
                        if (~done[lastReg]) begin
                            nextInstrPointer = instrPointer;
                        end else begin
                            nextMovState = 1'b0;
                        end
                    end
                    REG_0, REG_1, REG_2, REG_3 : begin
                        send[instr[13:12]] = 1'b1;
                        if (~done[instr[13:12]]) begin
                            nextInstrPointer = instrPointer; // Block
                        end else begin
                            nextMovState = 1'b0;
                        end
                    end
                endcase
            end else begin
                nextInstrPointer = instrPointer; // Block
            end
        end
        7'b100???? : begin // ADD / SUB
            if (canGet) begin
                // Following adds/subtracts src based on instr[12]
                nextAcc = acc + $signed(src ^ {11{instr[12]}}) + $signed({1'b0, instr[12]});
                nextLastReg = nextLast;
                // Strobe receive line if getting data from register
                received = instr[11];
            end else begin
                nextInstrPointer = instrPointer; // Block
            end
        end
        7'b1010??? : begin // JRO
            nextInstrPointer = instrPointer + src[3:0];
            nextLastReg = nextLast;
        end
        7'b110000? : begin // JMP
            nextInstrPointer = instr[9:6];
        end
        7'b110001? : begin // JEZ
            if (accZero) nextInstrPointer = instr[9:6];
        end
        7'b110010? : begin // JNZ
            if (!accZero) nextInstrPointer = instr[9:6];
        end
        7'b110011? : begin // JGZ
            if (!accZero & !accNegative) nextInstrPointer = instr[9:6];
        end
        7'b110100? : begin // JLZ
            if (accNegative) nextInstrPointer = instr[9:6];
        end
        7'b1110000 : begin // NEG
            nextAcc = -acc;
        end
        7'b1110001 : begin // SAV
            nextBak = acc;
        end
        7'b1110010 : begin // SWP
            nextBak = acc;
            nextAcc = bak;
        end
        default : begin
            // Do nothing different
        end
    endcase
end

endmodule
