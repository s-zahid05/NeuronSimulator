module fifo #(
    parameter int width = 8,
    parameter int depth = 16,
    parameter int depth_addr = 4
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    push_req_n,
    input  logic                    pop_req_n,
    input  logic [width-1:0]        data_in,
    output logic                    empty,
    output logic                    full,
    output logic [width-1:0]        data_out
);
    
    logic [width-1:0] fifo_mem [0:depth-1];
    logic [depth_addr:0] write_ptr;
    logic [depth_addr:0] read_ptr;
    
    assign empty = (write_ptr == read_ptr);
    assign full  = (write_ptr[depth_addr-1:0] == read_ptr[depth_addr-1:0]) && 
                   (write_ptr[depth_addr] != read_ptr[depth_addr]);
    
    assign data_out = fifo_mem[read_ptr[depth_addr-1:0]];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= '0;
        end else if (!push_req_n && !full) begin
            fifo_mem[write_ptr[depth_addr-1:0]] <= data_in;
            write_ptr <= write_ptr + 1;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= '0;
        end else if (!pop_req_n && !empty) begin
            read_ptr <= read_ptr + 1;
        end
    end
endmodule