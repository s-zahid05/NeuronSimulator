//Author: Sadeem Zahid

module STP #(
    parameter int DATA_WIDTH    = 18,   
    parameter int WEIGHT_WIDTH  = 16,   
    parameter int U_BASE        = 64,   
    parameter int U_SCALE_SHIFT = 9,    
    parameter int R_TARGET      = 256   
)(
    input  logic                         pre_spike,
    input  logic signed [DATA_WIDTH-1:0] u_decayed,
    input  logic signed [DATA_WIDTH-1:0] R_decayed,
    input  logic signed [WEIGHT_WIDTH-1:0] weight,    
    output logic signed [DATA_WIDTH-1:0] u_out,
    output logic signed [DATA_WIDTH-1:0] R_out,
    output logic signed [WEIGHT_WIDTH-1:0] efficacy   
);
    
    logic signed [DATA_WIDTH-1:0] u_next, R_next;
    logic signed [2*DATA_WIDTH-1:0] u_R_product;
    logic signed [DATA_WIDTH-1:0] resource_consumed;
    logic signed [2*DATA_WIDTH-1:0] efficacy_product;
    logic signed [2*DATA_WIDTH+WEIGHT_WIDTH-1:0] full_efficacy;  
    
    parameter int G_SYN = 1;
    
    always_comb begin
        u_next = u_decayed;
        R_next = R_decayed;
        
        if (pre_spike) begin
            // Update u
            if (u_decayed < R_TARGET) begin
                u_next = u_decayed + ((R_TARGET - u_decayed) >>> 2);
            end else begin
                u_next = u_decayed; // Cap at R_TARGET
            end
            
            // Compute resource consumption
            u_R_product = u_decayed * R_decayed;
            resource_consumed = u_R_product >>> U_SCALE_SHIFT;
            
            // Update R: R = R - consumed
            R_next = R_decayed - resource_consumed;
            if (R_next < 0) R_next = 0; // Prevent underflow
        end
        
        // Calculate efficacy 
        efficacy_product = u_next * R_next;
        full_efficacy = weight * efficacy_product;
        efficacy = full_efficacy >>> (2*U_SCALE_SHIFT) <<< G_SYN;
    end
    
    assign u_out = u_next;
    assign R_out = R_next;
    
endmodule