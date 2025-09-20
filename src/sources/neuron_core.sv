//Author: Sadeem Zahid

module neuron_core #(
    parameter int N         = 256,
    parameter int ADDR_W    = 8,
    parameter int DATA_W    = 16,
    parameter int V_THRESH  = 5,
    parameter int V_RESET   = 0,
    parameter int LEAK      = 1
)(
    input  logic                     clk,
    input  logic                     reset,
    input  logic                     CTRL_NEUR_EVENT,
    input  logic [ADDR_W-1:0]        neuron_addr,
    input  logic signed [DATA_W-1:0] virtual_current,
    input  logic signed [DATA_W-1:0] syn_current,
    
    output logic                     spike_out,
    output logic signed [DATA_W-1:0] v_mem_out,
    output logic                     neuron_ready
);
    logic [2:0] curr_calcium [0:N-1];
    logic [2:0] next_calcium;
    logic signed [15:0] curr_vs_mem [0:N-1];  
    logic signed [15:0] next_vs_mem;          
    logic signed [15:0] curr_vd_mem [0:N-1];  
    logic signed [15:0] next_vd_mem;          
    
    // Address latching
    logic [ADDR_W-1:0] latched_addr;
    
    // Internal signals
    logic spike;
    logic ca_high;
    logic signed [DATA_W-1:0] total_input;
    
    assign total_input = syn_current + virtual_current;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            latched_addr <= '0;
        end else if (CTRL_NEUR_EVENT) begin
            latched_addr <= neuron_addr;
        end
    end
    
    // Calcium dynamics module (placeholder for now)
    always_comb begin
        next_calcium = curr_calcium[latched_addr];
        ca_high = 1'b0;
    end
    
    // LIF neuron module
    LIF_Neuron #(
        .LEAK(LEAK),
        .V_THRESH(V_THRESH),
        .G_C(1)
    ) u_lif (
        .rst(reset),
        .spike(spike),
        .curr_vs_mem(curr_vs_mem[latched_addr]),
        .next_vs_mem(next_vs_mem),
        .curr_vd_mem(curr_vd_mem[latched_addr]),
        .next_vd_mem(next_vd_mem),
        .synaptic_in(syn_current)
    );
    
    // Memory update logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < N; i++) begin
                curr_vs_mem[i] <= 16'sd0;  
                curr_vd_mem[i] <= 16'sd0;  
                curr_calcium[i] <= 3'd0;
            end
        end else if (CTRL_NEUR_EVENT) begin
            curr_vs_mem[latched_addr] <= next_vs_mem;
            curr_vd_mem[latched_addr] <= next_vd_mem;
            curr_calcium[latched_addr] <= next_calcium;
        end
    end
    
    // Output assignments
    assign spike_out = spike && CTRL_NEUR_EVENT;
    assign v_mem_out = curr_vs_mem[latched_addr];
    assign neuron_ready = 1'b1;
    
endmodule