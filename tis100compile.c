
/**
# TIS-100 Compiler #

## Program Format ##
Programs for the TIS-100 have the following syntax:

```
<source_test> ::= <node_name> | <code_line> | <comment_string>

<node_name> ::= @<INTEGER>
<code_line> ::= [<label>] <command_string> [<comment_string>]

<label> ::= <LABEL_NAME> ":"
<comment_string> ::= "#" <COMMENT>

<command_string> ::= <opcode> {" " | ","} [<argument>] [<argument>]
<opcode> ::= NOP | MOV | SWP | SAV | ADD | SUB | NEG | 
             JMP | JEZ | JNZ | JGZ | JLZ | JRO
<argument> ::= <INTEGER> | ACC | NIL | UP | DOWN | LEFT | RIGHT

```

See https://alandesmet.github.io/TIS-100-Hackers-Guide/assembly.html for a more 
detailed breakdown of the assembly language.


## Compiled Opcodes ##

### Registers ###

| Code | Register Name      |
| ---  | ---                |
| 0    | NIL                |
| 1    | ACC                |
| 2    | ANY                |
| 3    | LAST               |
| 4    | LEFT  - Neighbor 0 |
| 5    | RIGHT - Neighbor 1 |
| 6    | UP    - Neighbor 2 |
| 7    | DOWN  - Neighbor 3 |

### Instruction Set ###

A is a 3-bit value corresponding to a register.
B is a 12-bit value: if MSB is 1, bits [10:8] specify a register. Otherwise bits [10:0] specify a constant.
C is a 4-bit value pointing to an instruction in program memory.
X is a don't care - this data is ignored.

| Instruction Code | Instruction                                                                      |
| ---              | ---                                                                              |
| 0aaabbbbbbbbbbbb | MOV b, a. Moves B to A. All zeros = MOV 0, NIL = NOP                             |
| 1000bbbbbbbbbbbb | ADD b                                                                            |
| 1001bbbbbbbbbbbb | SUB b                                                                            |
| 1010bbbbbbbbbbbb | JRO b. Only uses lower 4 bits of constant/register contents. Rollover may occur. |
| 1011bbbbbbbbbbbb | RESERVED                                                                         |
| 110000ccccxxxxxx | JMP c                                                                            |
| 110001ccccxxxxxx | JEZ c                                                                            |
| 110010ccccxxxxxx | JNZ c                                                                            |
| 110011ccccxxxxxx | JGZ c                                                                            |
| 110100ccccxxxxxx | JLZ c                                                                            |
| 110NNNccccxxxxxx | RESERVED for all N > 4                                                           |
| 1110000xxxxxxxxx | NEG                                                                              |
| 1110001xxxxxxxxx | SAV                                                                              |
| 1110010xxxxxxxxx | SWP                                                                              |
| 1110NNNxxxxxxxxx | RESERVED for all N > 2.                                                          |


## Expected programming interface ##

1. Write one-byte command: program a node
2. Next byte is node number
3. Next byte is lower byte of program memory space 0
4. Next byte is upper byte of program memory space 0
5. Repeat 3 & 4 for spaces 1 to 15.
6. Programming of node complete. Device will respond with checksum.

*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

// Function Declarations
uint16_t GenCommand(int node, int line, const char* cmd, const char* arg0, const char* arg1);
uint16_t EncodeSource(int node, int line, const char* source);
uint16_t EncodeReg(int node, int line, const char* reg);
void EncodeLabels(int node,  uint16_t commands[], const char labels[][32], const char jump_labels[][32]);

// Global Variables
bool failedCompile = false;

int main (int argc, char *argv[])
{
  if (argc != 2) {
    printf("Usage: %s PROGRAM\n", argv[0]);
    return 0;
  }

  FILE* code = fopen(argv[1], "r");
  if (code == NULL) {
    printf("Failed to open file %s for compiling.\n", argv[1]);
    return 0;
  };

  bool nodeProcessed = false; // At least one node has been processed
  char line[32];
  char labels[16][32];
  char jump_labels[16][32];
  uint16_t commands[16];
  char word[32];
  int wordindex;
  int command;
  bool commentflag;

  char cmd[32];
  char arg0[32];
  char arg1[32];
  int node = 0;
  int lineNum = 0;
  int cmdLineNum = 0;

  // Compile to hex codes
  while (fgets(line, 32, code) != NULL) {
    // Initialize line processing variables
    // Parse the line
    // --------------
    // Node designator
    if (line[0] == '@') {
      // Print out processed node commands
      if (nodeProcessed) {
        EncodeLabels(node, commands, labels, jump_labels);
        for (int j=0; j<16; j++) {
          fprintf(stdout, "%02x%02x", commands[j] & 0xFF, (commands[j] >> 8) & 0xFF);
          if ((j & 0x3) == 0x3) {
            putc('\n', stdout);
          }
          else {
            putc(' ', stdout);
          }
        }
      }
      // Reinitialize command & label arrays
      for (int j=0; j < 16; j++) {
        commands[j] = 0xC000; // Default is to jump to start. This more closely models the TIS-100, which does not execute empty lines
        memset(labels[j], '\0', sizeof(char));
        memset(jump_labels[j], '\0', sizeof(char));
        lineNum = 0;
        cmdLineNum = 0;
      }
      // Get the Node index and print it
      nodeProcessed = true;
      node = atoi(&line[1]);
      fprintf(stdout, "\n%02x\n", node & 0xFF);
    }

    // Regular command
    else {
      commentflag = false;
      command = 0;
      word[0] = '\0';
      wordindex = 0;
      cmd[0] = '\0';
      arg0[0] = '\0';
      arg1[0] = '\0';
      int i=0;
      while (line[i] != '\0') {
        if (line[i] == ':' && !commentflag && cmdLineNum < 16) { // Label end
          word[wordindex] = '\0';
          strcpy(labels[cmdLineNum], word);
          wordindex = 0;
          word[0] = '\0';
        }
        else if (line[i] == '#') { // Comment start
          commentflag = true;
        }
        else if (!commentflag && (line[i] == ',' || line[i] == ' ' || line[i] == '\r' || line[i] == '\n')) { // Whitespace
          if (wordindex > 0) {
            word[wordindex] = '\0';
            if      (cmd[0]  == '\0') { strcpy(cmd,  word); }
            else if (arg0[0] == '\0') { strcpy(arg0, word); }
            else if (arg1[0] == '\0') { strcpy(arg1, word); }
            else {
              failedCompile = true;
              fprintf(stderr, "Node %i, line %i: Too many arguments.\n", node, lineNum);
            }
          }
          wordindex = 0;
          word[0] = '\0';
        }
        else { // Push character onto word
          word[wordindex] = line[i];
          wordindex++;
        }
        i++;
      }
      if (cmd[0] != '\0') {
        if (cmdLineNum >= 16) {
          cmdLineNum = 0;
          failedCompile = true;
          fprintf(stderr, "Node %i: Too many lines of code\n", node);
        }
        commands[cmdLineNum] = GenCommand(node, lineNum, cmd, arg0, arg1);
        if ((commands[cmdLineNum] & 0xE000) == 0xC000) { // Check for jump instruction
          strcpy(jump_labels[cmdLineNum], arg0); // Store jump destination
        }
        cmdLineNum++;
      }
      lineNum++;
    }
  }
  fclose(code);

  // Print out processed node commands of the final node
  if (nodeProcessed) {
    EncodeLabels(node, commands, labels, jump_labels);
    for (int j=0; j<16; j++) {
      fprintf(stdout, "%02x%02x", commands[j] & 0xFF, (commands[j] >> 8) & 0xFF);
      if ((j & 0x3) == 0x3) {
        putc('\n', stdout);
      }
      else {
        putc(' ', stdout);
      }
    }
  }

  // Finish up
  if (failedCompile) {
    fprintf(stderr, "\nCompilation Failed\n");
    return 1;
  }
  return 0;
}


// Generate a command from an input command string and argument strings
uint16_t GenCommand(int node, int line, const char* cmd, const char* arg0, const char* arg1) {
  uint16_t command;
  // Command Table
  // Move
  if      (strcmp(cmd, "MOV") == 0) { command = 0x0000 | EncodeSource(node, line, arg0) | (EncodeReg(node, line, arg1) << 12); }
  // Single-argument operations
  else if (strcmp(cmd, "ADD") == 0) { command = 0x8000 | EncodeSource(node, line, arg0); }
  else if (strcmp(cmd, "SUB") == 0) { command = 0x8001 | EncodeSource(node, line, arg0); }
  else if (strcmp(cmd, "JRO") == 0) { command = 0x8002 | EncodeSource(node, line, arg0); }
  // Jump instructions using labels. Instruction pointer is updated in a 
  // separate routine.
  else if (strcmp(cmd, "JMP") == 0) { command = 0xC000; }
  else if (strcmp(cmd, "JEZ") == 0) { command = 0xC400; }
  else if (strcmp(cmd, "JNZ") == 0) { command = 0xC800; }
  else if (strcmp(cmd, "JGZ") == 0) { command = 0xCC00; }
  else if (strcmp(cmd, "JLZ") == 0) { command = 0xD000; }
  // No-argument operations
  else if (strcmp(cmd, "NEG") == 0) { command = 0xE000; }
  else if (strcmp(cmd, "SAV") == 0) { command = 0xE200; }
  else if (strcmp(cmd, "SWP") == 0) { command = 0xE400; }
  else if (strcmp(cmd, "NOP") == 0) { command = 0x0000; }
  else {
    command = 0x0000; // Default to NOP
    fprintf(stderr, "Node %i, line %i: Opcode %s is not valid.\n", node, line+1, cmd);
    failedCompile = true;
  }
  return command;
}


// Encode a source string as a register or as a number.
// The encoding is as a 12-bit value. If the MSB is 1, bits [10:8] specify a 
// register. Otherwise bits [10:0] specify a constant.
uint16_t EncodeSource(int node, int line, const char* source) {
  // Figure out if we're looking at a number or not
  int i=0;
  bool isDigit = true;
  while (source[i] != '\0') {
    if ((source[i] < '0' || source[i] > '9') && !(i==0 & source[i] == '-')) {
      isDigit = false;
    }
    i++;
  }
  if (i==0) { isDigit = false; } // 0-length should be processed as a register
  // Process as a number or as a register
  uint16_t encoded;
  if (isDigit) {
    int number = atoi(source);
    if (number > 1023 || number < -1024) {
      failedCompile = true;
      fprintf(stderr, "Node %i, line %i: Literal %i is outside valid range of -1024 to 1023.\n", node, line+1, number);
    }
    encoded = (uint16_t)number & 0x7FF;
  }
  else {
    encoded = ((EncodeReg(node, line, source) << 8) & 0x700) | 0x800;
  }
  return encoded;  
}

// Register encoding based on string
uint16_t EncodeReg(int node, int line, const char* reg) {
  if      (strcmp(reg, "NIL"  ) == 0) { return 0; }
  else if (strcmp(reg, "ACC"  ) == 0) { return 1; }
  else if (strcmp(reg, "ANY"  ) == 0) { return 2; }
  else if (strcmp(reg, "LAST" ) == 0) { return 3; }
  else if (strcmp(reg, "LEFT" ) == 0) { return 4; }
  else if (strcmp(reg, "RIGHT") == 0) { return 5; }
  else if (strcmp(reg, "UP"   ) == 0) { return 6; }
  else if (strcmp(reg, "DOWN" ) == 0) { return 7; }
  else {
    failedCompile = true;
    fprintf(stderr, "Node %i, line %i: Register Name %s is not valid.\n", node, line+1, reg);
    return 0;
  }
}

// Fill in Jump Labels as required
// node        - Current node this command word set is for
// commands    - 16 deep array of command words
// labels      - 16-deep array of strings containing labels for each line
// jump_labels - 16-deep array of strings containing the destination labels for 
//               each jump command
void EncodeLabels(int node,  uint16_t commands[], const char labels[][32], const char jump_labels[][32]) { 
  for (int i=0; i<16; i++) {
    if ((commands[i] & 0xE000) == 0xC000) { // Check for jump instruction
      int j=0;
      while (j<16) {
        if (strcmp(labels[j],jump_labels[i]) == 0) {
          break;
        }
        j++;
      }
      if (j==16) {
        fprintf(stderr, "Node %i, Line %i: Label %s not found.\n", node, i+1, jump_labels[i]);
        failedCompile = true;
      }
      else {
        commands[i] = commands[i] | (j << 6);
      }
    }
  }
}


