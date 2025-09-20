//Author: Sadeem Zahid

module LIF_Neuron (
    input  logic rst,
    input  logic signed [15:0] curr_vs_mem,    // soma
    input  logic signed [15:0] curr_vd_mem,    // dendrite
    output logic signed [15:0] next_vs_mem,
    output logic signed [15:0] next_vd_mem,
    input  logic signed [15:0] synaptic_in,
    output logic spike
);
    parameter int LEAK    = 1;
    parameter int V_THRESH = 10;
    parameter int G_C     = 1;

    logic signed [15:0] vd_delta, vs_delta;
    logic signed [15:0] coupling_term;

    always_comb begin
        coupling_term = (curr_vd_mem - curr_vs_mem) >>> G_C;

        vd_delta = synaptic_in - LEAK - coupling_term;
        vs_delta = coupling_term - LEAK;

        next_vd_mem = curr_vd_mem + vd_delta;
        next_vs_mem = curr_vs_mem + vs_delta;

        if (next_vs_mem < 0) next_vs_mem = 0;
        if (next_vd_mem < 0) next_vd_mem = 0;

        if (next_vs_mem >= V_THRESH) begin
            spike        = 1'b1;
            next_vs_mem  = 16'd0;
        end else begin
            spike = 1'b0;
        end
    end
endmodule
