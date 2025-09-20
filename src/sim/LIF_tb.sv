module LIF_tb();

    logic clk;
    logic rst;
    
    // Neuron core signals
    logic [7:0] neuron_addr = 8'sd0;
    logic signed [15:0] virtual_current = 8'sd0;
    logic spike_out;
    logic signed [15:0] v_mem_out;
    logic neuron_ready;
    
    // AER input interface
    logic [16:0] AERIN_ADDR;
    logic AERIN_REQ;
    logic AERIN_ACK;

    // Scheduler interface
    logic SCHED_EMPTY;
    logic SCHED_FULL;
    logic SCHED_BURST_END = 1'b0; 
    logic [11:0] SCHED_DATA_OUT;

    // AER output busy flag
    logic AEROUT_CTRL_BUSY;

    // Controller outputs to synaptic core
    logic [7:0] CTRL_PRE_EN;
    logic CTRL_BIST_REF;
    logic CTRL_SYN_CS;
    logic CTRL_SYN_WE;
    logic [12:0] CTRL_SYN_ADDR;

    // Controller outputs to neuron core
    logic CTRL_NEUR_EVENT;
    logic CTRL_NEUR_TREF;
    logic [4:0] CTRL_NEUR_PARAM;

    // Controller outputs to scheduler
    logic CTRL_SCHED_POP_N;
    logic [7:0] CTRL_SCHED_ADDR;
    logic [6:0] CTRL_SCHED_EVENT_IN;
    logic [4:0] CTRL_SCHED_PARAM;

    // AER output interface signals
    logic CTRL_AEROUT_POP_NEUR;
    logic [7:0] AEROUT_ADDR;
    logic AEROUT_REQ;
    logic AEROUT_ACK;
        // Proper ACK handshake
    always @(posedge clk) begin
        if (rst) 
            AEROUT_ACK <= 1'b0;
        else 
            AEROUT_ACK <= AEROUT_REQ;  // ACK follows REQ with 1 cycle delay
    end

    // Synaptic core signals
    logic enable_learning = 1'b1; // Disable learning for basic testing
    logic pre_spike;
    logic post_spike;
    logic signed [15:0] weight_out;
    logic signed [15:0] efficacy_out;
    
    
    // Generate pre_spike signal from controller's synaptic control
    always_comb begin
        pre_spike = CTRL_SYN_CS && CTRL_SYN_WE && (|CTRL_PRE_EN);
        post_spike = spike_out; // Connect neuron spike to post-synaptic input
    end

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate synaptic core
    synaptic_core #(
        .N_SYNAPSES(8192),
        .WEIGHT_WIDTH(16),
        .TRACE_WIDTH(18),
        .INIT_FROM_FILE(1'b1) 
    ) dut_synaptic (
        .clk(clk),
        .rst_n(~rst),
        .enable_learning(enable_learning),
        .pre_spike(pre_spike),
        .post_spike(post_spike),
        .syn_addr(CTRL_SYN_ADDR[12:0]), 
        .syn_cs(CTRL_SYN_CS),
        .syn_we(CTRL_SYN_WE),
        .weight_out(weight_out),
        .efficacy_out(efficacy_out)
    );

   
    neuron_core #(
        .N(256),
        .ADDR_W(8),
        .DATA_W(16),
        .V_THRESH(5),
        .V_RESET(0),
        .LEAK(1)
    ) dut_neuron (
        .clk(clk),
        .reset(rst),
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .neuron_addr(neuron_addr),
        .virtual_current(virtual_current),
        .syn_current(efficacy_out),
        .spike_out(spike_out),
        .v_mem_out(v_mem_out),
        .neuron_ready(neuron_ready)
    );
    
    // Instantiate scheduler
    scheduler #(
        .N(256),
        .M(8),
        .VIRT_BITS(4)
    ) dut_scheduler (
        .clk(clk),
        .rst_n(~rst),
        .ctrl_sched_pop_n(CTRL_SCHED_POP_N),
        .ctrl_sched_virts(CTRL_SCHED_PARAM), 
        .ctrl_sched_addr(CTRL_SCHED_ADDR),
        .ctrl_sched_event_in(CTRL_SCHED_EVENT_IN),
        .ctrl_neurmem_addr(neuron_addr), 
        .neur_event_out(spike_out),      
        .sched_empty(SCHED_EMPTY),
        .sched_full(SCHED_FULL),
        .sched_data_out(SCHED_DATA_OUT)
    );
    
    // Instantiate controller
    controller #(
        .N(256),
        .M(8)
    ) dut_controller (
        .CLK(clk),
        .RST(rst),
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_BURST_END(SCHED_BURST_END),
        .SCHED_DATA_OUT({1'b0, SCHED_DATA_OUT}), 
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        .CTRL_PRE_EN(CTRL_PRE_EN),
        .CTRL_BIST_REF(CTRL_BIST_REF),
        .CTRL_SYN_CS(CTRL_SYN_CS),
        .CTRL_SYN_WE(CTRL_SYN_WE),
        .CTRL_SYN_ADDR(CTRL_SYN_ADDR),
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        .CTRL_NEUR_PARAM(CTRL_NEUR_PARAM),
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        .CTRL_SCHED_PARAM(CTRL_SCHED_PARAM),
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR)
    );

    // Instantiate aer_out
    aer_out #(
        .N(256),
        .M(8)
    ) dut_aer_out (
        .CLK(clk),
        .RST(rst),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .CTRL_NEURMEM_CS(CTRL_NEURMEM_CS),
        .CTRL_NEURMEM_WE(CTRL_NEURMEM_WE),
        .SYNARRAY_WDATA(SYNARRAY_WDATA),
        .CTRL_SYN_ADDR(CTRL_SYN_ADDR),
        .CTRL_SYN_CS(CTRL_SYN_CS),
        .CTRL_SYN_WE(CTRL_SYN_WE),
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR),
        .SCHED_DATA_OUT(SCHED_DATA_OUT[7:0]), // Lower 8 bits for address
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK)
    );

    // Test sequence - Testing AER-driven operation
    initial begin
        #10;  // Wait for reset
        force AEROUT_CTRL_BUSY = 1'b0;  // Override the busy flag
    end
    
    initial begin
        // Initialize all inputs
        rst = 1;
        AERIN_ADDR = 17'b0;
        AERIN_REQ = 1'b0;
        
        #20;
        rst = 0;
        #20;

        // Test 1: Synaptic input via AER 
        send_aer_event(17'b1_00000000_00000001);
        #30;
        send_aer_event(17'b1_00000000_00000010); 
        #30;
        send_aer_event(17'b1_00000000_00000100);
        #30;
        
        // Test 2: Decay event via AER (software-controlled decay)
        send_aer_event(17'b0_00000000_11111111);
        #30;
        
        // Another decay
        send_aer_event(17'b0_00000000_11111111);
        #30;
        
        send_aer_event(17'b0_00000000_00001001);
        #50; // Wait for scheduler to process
        
        // Test 4: Mixed operation - charge and decay
        send_aer_event(17'b1_00000000_00001000);
        #30;
        send_aer_event(17'b1_00000000_00010000);
        #30;
        
        // Now decay
        send_aer_event(17'b0_00000000_11111111);
        #30;
        
        // Test 5: Try to cause a spike
        repeat(4) begin
            send_aer_event(17'b1_00000000_00000001);
            #20;
        end
        
        send_aer_event(17'b1_00000000_00000111);
        #30;
        
        #200;
        
        $finish;
    end
    
    // Task to send AER events 
    task send_aer_event(input [16:0] addr);
        begin
            AERIN_ADDR = addr;
            AERIN_REQ = 1'b1;
            wait(AERIN_ACK);
            #5;
            AERIN_REQ = 1'b0;
            #5;
        end
    endtask

endmodule