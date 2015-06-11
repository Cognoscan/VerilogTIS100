# TIS-100 Tesselated Intelligence System

This is an implementation of the Tesselated Intelligence System architecture in 
Verilog. So far, only Node Type T21 is implemented.

The TIS-100 is from the game, [TIS-100](http://www.zachtronics.com/tis-100/).

## Implementation Details

### Node Type T21 - Basic Execution Node

Node Type T21 provides basic processing functionality. Diverging slightly from 
the game, it uses 11-bit signed data, such that the range of values is -1024 to 
1023. Unlike the game, this T21 does not saturate, but undergoes rollover for 
both data instructions and for the instruction pointer.

All 12 instructions are implemented using a 16-bit instruction word. The format 
is as follows:

- Let A be a 3-bit value corresponding to a register.
- Let B be a 12-bit value. If the MSB is 1, bits [10:8] specify a register. 
  Otherwise bits [10:0] specify a constant.
- Let C be a 4-bit value, pointing to an location in program memory.

#### Instructions
```
[15:0] Instruction word - Description
0aaabbbbbbbbbbbb 				- MOV b, a. Moves B to A. All zeros = MOV 0, NIL = NOP
1000bbbbbbbbbbbb 				- ADD b. Adds b to ACC.
1001bbbbbbbbbbbb 				- SUB b. Subtracts b from ACC.
1010bbbbbbbbbbbb 				- JRO b. Bits [3:0] of b used. Rollover can occur.
1011bbbbbbbbbbbb 				- RESERVED
110000ccccxxxxxx 				- JMP c. Jumps to c.
110001ccccxxxxxx 				- JEZ c. Jumps to c if ACC == 0.
110010ccccxxxxxx 				- JNZ c. Jumps to c if ACC != 0.
110011ccccxxxxxx 				- JGZ c. Jumps to c if ACC > 0.
110100ccccxxxxxx 				- JLZ c. Jumps to c if ACC < 0.
110NNNccccxxxxxx 				- RESERVED for all N > 4
1110000xxxxxxxxx 				- NEG. Negates ACC.
1110001xxxxxxxxx 				- SAV. Saves ACC to BAK register.
1110010xxxxxxxxx 				- SWP. Swaps ACC and BAK.
1110NNNxxxxxxxxx 				- RESERVED for all N > 2.
```

#### Registers
The Node itself does not specify which neighbor is UP, DOWN, LEFT, or RIGHT. 
Priority is given to 0, then 1, then 2, and then 3. To match the game, 0/1/2/3 
should correspond to LEFT/RIGHT/UP/DOWN.

| Number  | Register   |
| --      | --         |
| 0       | nil        |
| 1       | acc        |
| 2       | any        |
| 3       | last       |
| 4       | Neighbor 0 |
| 5       | Neighbor 1 |
| 6       | Neighbor 2 |
| 7       | Neighbor 3 |

### Node Type T22 - Lightweight Execution Node

Not present in the game, but offered here as a lighter-weight alternative to 
T21. It does not implement the ANY or LAST registers in order to save on size, 
but is otherwise identical to T21.

### Node Type T30 - Stack Memory Node

Planned to function using a compact RAM with a stack pointer.

### Visualization Module

Planned to use VGA output and a small video RAM with 3-bit data. Will have more 
colors and the option to skip updating a pixel, but otherwise functions the same 
as the in-game module.

| Number | Color       |
| --     | --          |
| 0      | Black       |
| 1      | Dark Grey   |
| 2      | Bright Grey |
| 3      | White       |
| 4      | Red         |
| 5      | Green       |
| 6      | Blue        |
| 7      | SKIP PIXEL  |

## Module Connections

All nodes expect the following inputs:
- [10:0] in0 - in3: Inputs from neighboring nodes
- [3:0] ready - Bits are high when neighbor is attempting to send data to this node
- [3:0] done - Bits strobe when corresponding neighbor received data from this 
  node.

All nodes provide the following outputs:
- [3:0] recv - Bits strobe when data has been received from corresponding 
  neighbor.
- [3:0] send - Bits are high when attempting to send data to corresponding neighbor.
- [10:0] outData - Data the node is attempting to send out.

I/O Modules, like the Visualization Module, have the following connections:
- Input [10:0] in - Input from attached node
- Input ready - High when node is sending data to module
- Input done - Strobed when node received data from this module
- Output recv - Strobed when module received data from this node
- Output send - High when module is sending data to node
- Output [10:0] out - Data being sent to attached node

