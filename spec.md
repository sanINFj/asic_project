# 8-bit ALU Specification

Project Overview

This project implements a simple 8-bit Arithmetic Logic Unit (ALU) as part of a larger goal of learning the complete digital ASIC design flow using open-source tools.

The ALU will be described in Verilog, verified using simulation, synthesized into a gate-level netlist, and eventually taken through physical design using OpenLane/OpenROAD.


Objective

Design an 8-bit combinational ALU capable of performing basic arithmetic and logical operations selected using an opcode.


Functional Requirements

The ALU shall:

- Accept two 8-bit input operands.
- Accept a control signal (opcode) that selects the operation.
- Produce an 8-bit output result.
- Generate status flags where applicable.


Inputs

| Signal | Width | Description |
|---------|------:|-------------|
| A | 8 bits | First operand |
| B | 8 bits | Second operand |
| Opcode | 3 bits | Selects the operation |


Outputs

| Signal | Width | Description |
|---------|------:|-------------|
| Result | 8 bits | Output of the selected operation |
| Carry | 1 bit | Carry-out for arithmetic operations |
| Zero | 1 bit | High when Result equals zero |


Supported Operations

| Opcode | Operation | Description |
|---------|-----------|-------------|
| 000 | ADD | A + B |
| 001 | SUB | A - B |
| 010 | AND | Bitwise AND |
| 011 | OR | Bitwise OR |
| 100 | XOR | Bitwise XOR |
| 101 | Shift Left | Shift A left by one bit |
| 110 | Shift Right | Shift A right by one bit |
| 111 | NOT | Bitwise NOT of A |


Design Constraints

- The ALU shall be purely combinational.
- No clock input shall be used.
- No internal memory elements shall be used.
- Outputs shall update immediately when inputs change.


Assumptions

- Inputs are valid binary values.
- Overflow detection is not included in this version.
- Shift operations shift by one bit only.
- Only unsigned arithmetic is considered.


Future Improvements

Possible extensions include:

- Overflow flag
- Negative flag
- Signed arithmetic
- Variable shift amount
- Multiplication
- Comparison operations
