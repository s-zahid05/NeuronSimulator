//Author: Sadeem Zahid

module stdp_update #(
    parameter int TRACE_WIDTH = 18,
    parameter int WEIGHT_WIDTH = 32,
    parameter int TAU_PLUS = 16,
    parameter int TAU_MINUS = 32,
    parameter int A2_PLUS_SH = 6,
    parameter int A2_MINUS_SH = 4,
    parameter int MAX_WEIGHT = 1000,
    parameter int MIN_WEIGHT = -1000
)(
    input  logic                           enable,
    input  logic                           stdp_update_trigger,
    input  logic                           pre_spike_edge,
    input  logic                           post_spike_edge,
    input  logic signed [WEIGHT_WIDTH-1:0] weight_in,
    input  logic signed [TRACE_WIDTH-1:0]  r1_in,
    input  logic signed [TRACE_WIDTH-1:0]  o1_in,
    output logic signed [WEIGHT_WIDTH-1:0] weight_out,
    output logic signed [TRACE_WIDTH-1:0]  r1_out,
    output logic signed [TRACE_WIDTH-1:0]  o1_out
);
    localparam logic signed [TRACE_WIDTH-1:0] TRACE_INIT_VAL = 18'd256;
    
    // Combinational logic for STDP updates
    logic signed [TRACE_WIDTH-1:0] r1_next, o1_next;
    logic signed [WEIGHT_WIDTH-1:0] weight_next;
    logic signed [WEIGHT_WIDTH-1:0] weight_delta;
    
    // Intermediate values for debugging
    logic signed [WEIGHT_WIDTH-1:0] ltp_amount, ltd_amount;
    logic weight_changed;
    
    always_comb begin
        // Default values
        r1_next = r1_in;
        o1_next = o1_in;
        weight_next = weight_in;
        weight_delta = 0;
        ltp_amount = 0;
        ltd_amount = 0;
        weight_changed = 0;
        
        if (enable && stdp_update_trigger) begin
            // Apply trace decay when trigger is active
            if (r1_in > 0) begin
                r1_next = r1_in - (r1_in >>> $clog2(TAU_PLUS));
            end else if (r1_in < 0) begin
                r1_next = r1_in + ((-r1_in) >>> $clog2(TAU_PLUS));
            end
            
            if (o1_in > 0) begin
                o1_next = o1_in - (o1_in >>> $clog2(TAU_MINUS));
            end else if (o1_in < 0) begin
                o1_next = o1_in + ((-o1_in) >>> $clog2(TAU_MINUS));
            end
            
            // Calculate potential weight changes based on current trace values
            ltp_amount = (r1_in >>> A2_PLUS_SH);   // Potentiation based on pre-trace
            ltd_amount = (o1_in >>> A2_MINUS_SH);  // Depression based on post-trace
            
            // Handle spike events and apply STDP rules
            if (pre_spike_edge) begin
                r1_next = TRACE_INIT_VAL;  
                
                // Apply LTD if there's existing post-synaptic trace
                if (o1_in > 0) begin
                    weight_delta = -ltd_amount;
                    weight_next = weight_in + weight_delta;
                    weight_changed = 1;
                end
            end
            
            if (post_spike_edge) begin
                o1_next = TRACE_INIT_VAL; 
                
                // Apply LTP if there's existing pre-synaptic trace
                if (r1_in > 0) begin
                    weight_delta = ltp_amount;
                    weight_next = weight_in + weight_delta;
                    weight_changed = 1;
                end
            end
            
            // Handle simultaneous spikes 
            if (pre_spike_edge && post_spike_edge) begin
                weight_delta = ltp_amount; 
                weight_next = weight_in + weight_delta;
                weight_changed = 1;
                r1_next = TRACE_INIT_VAL;
                o1_next = TRACE_INIT_VAL;
            end
        end
        
        // Bound weight
        if (weight_next > MAX_WEIGHT) begin
            weight_next = MAX_WEIGHT;
        end else if (weight_next < MIN_WEIGHT) begin
            weight_next = MIN_WEIGHT;
        end
        
        if (r1_next < 0) r1_next = 0;
        if (o1_next < 0) o1_next = 0;
    end

    assign weight_out = weight_next;
    assign r1_out = r1_next;
    assign o1_out = o1_next;

endmodule