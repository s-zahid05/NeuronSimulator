//Author: Sadeem Zahid

//aer_out heavily based off of ODIN aer_out file 
//Frenkel, C. (2019). ODIN: online-learning digital spiking neural network (SNN) processor (HDL source code and documentation) 
//[Computer software]. GitHub. https://github.com/ChFrenkel/ODIN

module aer_out #(
    parameter int N = 256,
    parameter int M = 8
)(
    // Global inputs
    input  logic           CLK,
    input  logic           RST,
    // Neuron monitor inputs
    input  logic [6:0]     NEUR_EVENT_OUT,   
    input  logic [M-1:0]   CTRL_NEURMEM_ADDR,
    input  logic           CTRL_NEURMEM_CS,
    input  logic           CTRL_NEURMEM_WE,
    // Synapse monitor inputs
    input  logic [31:0]    SYNARRAY_WDATA,
    input  logic [12:0]    CTRL_SYN_ADDR,
    input  logic           CTRL_SYN_CS,
    input  logic           CTRL_SYN_WE,
    // Scheduler output for neuron pop
    input  logic           CTRL_AEROUT_POP_NEUR,
    input  logic [M-1:0]   SCHED_DATA_OUT,   
    // Output interface to controller
    output logic           AEROUT_CTRL_BUSY,
    // AER link
    output logic [M-1:0]   AEROUT_ADDR,
    output logic           AEROUT_REQ,
    input  logic           AEROUT_ACK
);

    logic      AEROUT_ACK_d;
    logic      ack_negedge;
    
    logic [7:0]    neur_state_samp;
    logic [M-1:0]  syn_state_samp;
    
    logic neuron_event;
    logic synapse_event;
    
    assign ack_negedge    = AEROUT_ACK_d & ~AEROUT_ACK;
    assign neuron_event   = CTRL_NEURMEM_CS && CTRL_NEURMEM_WE;
    assign synapse_event  = CTRL_SYN_CS && CTRL_SYN_WE;
    
    // Sync ACK detection
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            AEROUT_ACK_d <= '0;
        end else begin
            AEROUT_ACK_d <= AEROUT_ACK;
        end
    end
    
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            neur_state_samp <= '0;
            syn_state_samp  <= '0;
        end else begin
            if (neuron_event) begin
                neur_state_samp <= {1'b0, NEUR_EVENT_OUT};
            end
            if (synapse_event) begin
                syn_state_samp <= SYNARRAY_WDATA[M-1:0];
            end
        end
    end
    
    // AER output FSM
    always_ff @(posedge CLK or posedge RST) begin
        if (RST) begin
            AEROUT_CTRL_BUSY <= '0;
            AEROUT_REQ       <= '0;
            AEROUT_ADDR      <= '0;
        end else begin
            if (ack_negedge) begin
                AEROUT_REQ       <= '0;
                AEROUT_CTRL_BUSY <= '0;
            end

            else if (!AEROUT_CTRL_BUSY) begin
                if (CTRL_AEROUT_POP_NEUR) begin
                    AEROUT_ADDR      <= SCHED_DATA_OUT;
                    AEROUT_REQ       <= '1;
                    AEROUT_CTRL_BUSY <= '1;
                end else if (neuron_event) begin
                    AEROUT_ADDR      <= CTRL_NEURMEM_ADDR;
                    AEROUT_REQ       <= '1;
                    AEROUT_CTRL_BUSY <= '1;
                end else if (synapse_event) begin
                    AEROUT_ADDR      <= syn_state_samp;
                    AEROUT_REQ       <= '1;
                    AEROUT_CTRL_BUSY <= '1;
                end
            end
        end
    end

endmodule