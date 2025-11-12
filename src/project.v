/*
 * Copyright (c) 2024 Your Name
 *
 * SPDX-License-Identifier: Apache-2.0
 */

module tt_um_ccmed_morse_translator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// I/O assignments
// ui_in[4:0]: 5-bit character input (1-26 for A-Z, 0 for space)
// ui_in[5]: Start transmission (rising edge)
// uo_out[7:0]: To 7-segment display
// uio_out[0]: Serial morse output
// uio_out[1]: Busy signal

// FSM States
localparam IDLE = 0;
localparam START_TRANSMISSION = 1;
localparam TRANSMIT_SYMBOL = 2;
localparam SYMBOL_GAP = 3;
localparam LETTER_GAP = 4;
localparam WORD_GAP = 5;

// Timing constants
localparam TIME_UNIT = 250000;
localparam DOT_DURATION = TIME_UNIT;
localparam DASH_DURATION = 3 * TIME_UNIT;
localparam SYMBOL_GAP_DURATION = TIME_UNIT;
localparam LETTER_GAP_DURATION = 3 * TIME_UNIT;
localparam WORD_GAP_DURATION = 7 * TIME_UNIT;

// Internal signals
reg [2:0] state = IDLE;
reg [4:0] char_in_latched;
reg start_prev = 0;

// Morse code lookup outputs
reg [3:0] morse_pattern;
reg [2:0] morse_length;
reg [3:0] morse_pattern_shifted;

// Transmission control
reg [2:0] symbol_index;
reg [24:0] timer;

// Output registers
reg morse_serial_out = 0;
reg busy = 0;
reg [3:0] char_for_7seg;

// Map 5-bit input to 4-bit hex for 7-segment display
always @(*) begin
    case (char_in_latched)
        5'd1:  char_for_7seg = 4'hA; // A
        5'd2:  char_for_7seg = 4'hB; // B
        5'd3:  char_for_7seg = 4'hC; // C
        5'd4:  char_for_7seg = 4'hD; // D
        5'd5:  char_for_7seg = 4'hE; // E
        5'd6:  char_for_7seg = 4'hF; // F
        default: char_for_7seg = 4'h0;
    endcase
end

// Morse Code ROM (combinational)
always @(*) begin
    case (char_in_latched)
        5'd1:  {morse_pattern, morse_length} = {4'b1000, 3'd2}; // A (.-)
        5'd2:  {morse_pattern, morse_length} = {4'b0111, 3'd4}; // B (-...)
        5'd3:  {morse_pattern, morse_length} = {4'b0101, 3'd4}; // C (-.-.)
        5'd4:  {morse_pattern, morse_length} = {4'b0110, 3'd3}; // D (-..)
        5'd5:  {morse_pattern, morse_length} = {4'b1000, 3'd1}; // E (.)
        5'd6:  {morse_pattern, morse_length} = {4'b1101, 3'd4}; // F (..-.)
        5'd7:  {morse_pattern, morse_length} = {4'b0010, 3'd3}; // G (--.)
        5'd8:  {morse_pattern, morse_length} = {4'b1111, 3'd4}; // H (....)
        5'd9:  {morse_pattern, morse_length} = {4'b1100, 3'd2}; // I (..)
        5'd10: {morse_pattern, morse_length} = {4'b1000, 3'd4}; // J (.---)
        5'd11: {morse_pattern, morse_length} = {4'b0100, 3'd3}; // K (-.-)
        5'd12: {morse_pattern, morse_length} = {4'b1011, 3'd4}; // L (.-..)
        5'd13: {morse_pattern, morse_length} = {4'b0000, 3'd2}; // M (--)
        5'd14: {morse_pattern, morse_length} = {4'b0100, 3'd2}; // N (-.)
        5'd15: {morse_pattern, morse_length} = {4'b0000, 3'd3}; // O (---)
        5'd16: {morse_pattern, morse_length} = {4'b1001, 3'd4}; // P (.--.)
        5'd17: {morse_pattern, morse_length} = {4'b0010, 3'd4}; // Q (--.-)
        5'd18: {morse_pattern, morse_length} = {4'b1010, 3'd3}; // R (.-.)
        5'd19: {morse_pattern, morse_length} = {4'b1110, 3'd3}; // S (...)
        5'd20: {morse_pattern, morse_length} = {4'b0000, 3'd1}; // T (-)
        5'd21: {morse_pattern, morse_length} = {4'b1100, 3'd3}; // U (..-)
        5'd22: {morse_pattern, morse_length} = {4'b1110, 3'd4}; // V (...-)
        5'd23: {morse_pattern, morse_length} = {4'b1000, 3'd3}; // W (.--)
        5'd24: {morse_pattern, morse_length} = {4'b0110, 3'd4}; // X (-..-)
        5'd25: {morse_pattern, morse_length} = {4'b0100, 3'd4}; // Y (-.--)
        5'd26: {morse_pattern, morse_length} = {4'b0011, 3'd4}; // Z (--..)
        5'd0:  {morse_pattern, morse_length} = {4'b0000, 3'd0}; // Space
        default: {morse_pattern, morse_length} = {4'b0000, 3'd0};
    endcase
end

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        timer <= 0;
        symbol_index <= 0;
        morse_serial_out <= 0;
        busy <= 0;
        char_in_latched <= 0;
        start_prev <= 0;
    end else begin
        start_prev <= ui_in[5];
        if (timer > 0) begin
            timer <= timer - 1;
        end

        case (state)
            IDLE: begin
                busy <= 0;
                morse_serial_out <= 0;
                if (ui_in[5] && !start_prev) begin
                    char_in_latched <= ui_in[4:0];
                    state <= START_TRANSMISSION;
                end
            end

            START_TRANSMISSION: begin
                busy <= 1;
                symbol_index <= 0;
                morse_pattern_shifted <= morse_pattern;

                if (char_in_latched == 5'd0) begin
                    state <= WORD_GAP;
                    timer <= WORD_GAP_DURATION;
                end else if (morse_length > 0) begin
                    state <= TRANSMIT_SYMBOL;
                    timer <= (morse_pattern[3]) ? DOT_DURATION : DASH_DURATION;
                end else begin
                    state <= IDLE; // Invalid length, do nothing
                end
            end

            TRANSMIT_SYMBOL: begin
                morse_serial_out <= 1;
                if (timer == 0) begin
                    if (symbol_index < morse_length - 1) begin
                        state <= SYMBOL_GAP;
                        timer <= SYMBOL_GAP_DURATION;
                    end else begin
                        state <= LETTER_GAP;
                        timer <= LETTER_GAP_DURATION;
                    end
                end
            end

            SYMBOL_GAP: begin
                morse_serial_out <= 0;
                if (timer == 0) begin
                    symbol_index <= symbol_index + 1;
                    morse_pattern_shifted <= morse_pattern_shifted << 1;
                    state <= TRANSMIT_SYMBOL;
                    timer <= (morse_pattern_shifted[2]) ? DOT_DURATION : DASH_DURATION; // Check next bit
                end
            end

            LETTER_GAP: begin
                morse_serial_out <= 0;
                if (timer == 0) begin
                    state <= IDLE;
                end
            end

            WORD_GAP: begin
                morse_serial_out <= 0;
                if (timer == 0) begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

// 7-segment display driver
seven_segment seven_segment_inst (
    .clk(clk),
    .rst_n(rst_n),
    .data(char_for_7seg),
    .segments(uo_out)
);

// Output assignments
assign uio_out[0] = morse_serial_out;
assign uio_out[1] = busy;
assign uio_out[7:2] = 0;

assign uio_oe[0] = ena;
assign uio_oe[1] = ena;
assign uio_oe[7:2] = 0;

endmodule
