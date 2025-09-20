//Author: Sadeem Zahid

//controller heavily based off of ODIN scheduler file
//Frenkel, C. (2019). ODIN: online-learning digital spiking neural network (SNN) processor (HDL source code and documentation) 
//[Computer software]. GitHub. https://github.com/ChFrenkel/ODIN

module scheduler #(
    parameter int N = 256,
    parameter int M = 8,
    parameter int VIRT_BITS = 4
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    ctrl_sched_pop_n,
    input  logic [VIRT_BITS-1:0]    ctrl_sched_virts,
    input  logic [M-1:0]            ctrl_sched_addr,
    input  logic [6:0]              ctrl_sched_event_in, 
    input  logic [M-1:0]            ctrl_neurmem_addr,
    input  logic                    neur_event_out,
    output logic                    sched_empty,
    output logic                    sched_full,
    output logic [VIRT_BITS+M-1:0]  sched_data_out
);
    
    logic push_req_n;
    logic empty_main;
    logic full_main;
    logic [VIRT_BITS+M-1:0] data_out_main;
    
    // Determine if this is a virtual event (has non-zero virtual bits)
    wire is_virtual_event = |ctrl_sched_event_in[6:1];  // Check upper bits
    
    fifo #(
        .width(VIRT_BITS + M),
        .depth(128),
        .depth_addr(7)
    ) fifo_spike_0 (
        .clk(clk),
        .rst_n(rst_n),
        .push_req_n(push_req_n),
        .pop_req_n(ctrl_sched_pop_n),
        .data_in(is_virtual_event ? {ctrl_sched_virts, ctrl_sched_addr} : 
                                    {4'b0, ctrl_neurmem_addr}),
        .empty(empty_main),
        .full(full_main),
        .data_out(data_out_main)
    );
    
    assign push_req_n = ~(neur_event_out | (|ctrl_sched_event_in));
    assign sched_data_out = data_out_main;  // Return full data
    assign sched_empty    = empty_main;
    assign sched_full     = full_main;
    
endmodule