
// To be consistant with the Node numbering system, we will increment from 0 to 3 going left to right
// Rules for handling unconnected edges / "error nodes":
//  - They will never drive a "ready" line high for a node
//  - They will never strobe a "done" line for a node
//  - The result is that reading/writing an empty node will always hang
//
//  Node Types
//  ==========
//  Inputs
//  ------
//   - 0: No input
//   - 1: Input from console is presented here
//
//  Nodes
//  -----
//   - C: Basic Computation Node T21
//   - S: Stack Node T30
//   - E: Error Node (disconnected)
//
//  Outputs
//  -------
//   - 0: No output
//   - 1: Console Output
//   - 2: Image Module (only one allowed)

module TIS100
#(
   parameter [7:0] IN_NODES[0:3]  = {"1","0","0","1"},
   parameter [7:0] NODES_0[0:3]   = {"E","C","C","S"},
   parameter [7:0] NODES_1[0:3]   = {"C","C","C","C"},
   parameter [7:0] NODES_2[0:3]   = {"C","C","C","S"},
   parameter [7:0] OUT_NODES[0:3] = {"0","0","1","0"}
) (
    input clk,
    input rst,
    input [3:0] instrAddr,
    input [15:0] instrData,
    input writeInstr,
    input [10:0] inData, ///< Data to buffer on an input node
    input  [0:3] writeIn, ///< Write strobes for input buffers
    input read, ///< Read from the output buffer

    output [10:0] outData, ///< Data from the output buffer
    output [1:0] dataFrom, ///< Records which TIS100 output the data is from
    output dataReady, ///< High when there is data in the output buffer
    output hsync, ///< Horizontal Sync for VGA output
    output vsync, ///< Vertical Sync for VGA output
    output [2:0] red, ///< Red Color for VGA output
    output [2:0] green, ///< Green Color for VGA output
    output [1:0] blue, ///< Blue Color for VGA output
    output [0:3] full, ///< Input buffer full indicators


