module MEM_stage(
    input   wire            clk,
    input   wire            reset,
    // allowin
    input   wire            ws_allowin,
    output  wire            ms_allowin,
    // input from EXE stage
    input   wire            es_to_ms_valid,
    input   wire [224:0]    es_to_ms_bus,
    // output for WB stage
    output  wire            ms_to_ws_valid,
    output  wire [217:0]    ms_to_ws_bus,
    // data sram interface
    input   wire [31:0]     data_sram_rdata,     // read data
    input                   data_sram_data_ok,   // if data has been written or given back
    // output ms_valid and ms_to_ds_bus to ID stage
    output                  out_ms_valid,
    // interrupt signal
    output                  mem_ex,
    output                  mem_ertn,
    input                   wb_ex,
    input                   wb_ertn,

    output                  mem_write_asid_ehi,
    output                  mem_refetch,
    input                   wb_refetch,
    input                   wb_write_asid_ehi
);

wire refetch_needed;

wire        gr_we;
wire        res_from_mem;
wire [31:0] pc;
wire [4: 0] dest;
wire [31:0] mem_result;
wire [31:0] final_result;

wire [31:0] alu_result;

reg         ms_valid;
wire        ms_ready_go;
reg [224:0] es_to_ms_bus_r;
wire        ds_has_int;
wire        mem_re;
wire        mem_we;

// add ld op
wire [4:0] ld_op;
wire       inst_ld_b;
wire       inst_ld_bu;
wire       inst_ld_h;
wire       inst_ld_hu;
wire       inst_ld_w; 

assign {inst_ld_b,inst_ld_bu,inst_ld_h,inst_ld_hu,inst_ld_w}=ld_op;

assign ms_ready_go    = (mem_we | mem_re) ? data_sram_data_ok : 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if(wb_ex || wb_ertn || wb_refetch) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end
// deal with input and output
wire [33:0] csr_data;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] data_sram_addr_error;
wire [3:0]  exception_op;

wire [9:0]  tlb_bus;
wire inst_tlb_fill;
wire inst_tlb_wr;
wire inst_tlb_srch;
wire inst_tlb_rd;
wire inst_tlb_inv;
wire [4:0] op_tlb_inv;

wire inst_rdcntid;
assign {refetch_needed, tlb_bus, mem_re,mem_we,inst_rdcntid,data_sram_addr_error, ds_has_int,exception_op,rj_value,rkd_value,csr_data,ld_op,res_from_mem,gr_we,dest,alu_result,pc}=es_to_ms_bus_r;
assign ms_to_ws_bus={refetch_needed, refetch_needed, tlb_bus, mem_re,inst_rdcntid,data_sram_addr_error, ds_has_int,exception_op,rj_value,rkd_value,csr_data,gr_we,dest,final_result,pc};

wire [4:0]  csr_op;
wire [13:0] csr_num;
wire [13:0] mem_csr_num;
wire [14:0] csr_code;
wire inst_csrrd;
wire inst_csrwr;
wire inst_csrxchg;
wire inst_ertn;
wire inst_syscall;
assign {csr_op,csr_num,csr_code} = csr_data;
assign {inst_csrrd, inst_csrwr, inst_csrxchg, inst_ertn, inst_syscall} = csr_op;
assign {inst_tlb_fill, inst_tlb_wr, inst_tlb_srch, inst_tlb_rd, inst_tlb_inv, op_tlb_inv} = tlb_bus;

assign mem_ex = inst_syscall | exception_op[3] | exception_op[2] | exception_op[1] | exception_op[0];       // note that csr_data[29] means inst_syscall
assign mem_ertn = inst_ertn;                                                                             // note that csr_data[30] means inst_ertn

//bobbbbbbbbbby add below
wire [31:0] ld_b_result;
wire [31:0] ld_bu_result;
wire [31:0] ld_h_result;
wire [31:0] ld_hu_result;
wire [1:0]  addr;
assign addr = alu_result[1:0];
assign ld_b_result = (addr == 2'b00) ? {{24{data_sram_rdata[7]}}, data_sram_rdata[7:0]} :
                     (addr == 2'b01) ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15:8]} :
                     (addr == 2'b10) ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                     (addr == 2'b11) ? {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} : 0;
assign ld_bu_result = (addr == 2'b00) ? {{24'b0}, data_sram_rdata[7:0]} :
                      (addr == 2'b01) ? {{24'b0}, data_sram_rdata[15:8]} :
                      (addr == 2'b10) ? {{24'b0}, data_sram_rdata[23:16]} :
                      (addr == 2'b11) ? {{24'b0}, data_sram_rdata[31:24]} : 0;
assign ld_h_result = (addr == 2'b00) ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15:0]} :
                     (addr == 2'b10) ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]}: 0;
assign ld_hu_result = (addr == 2'b00) ? {{16'b0}, data_sram_rdata[15:0]} : 
                      (addr == 2'b10) ? {{16'b0}, data_sram_rdata[31:16]} : 0;
//bobbbbbbbbbby add above
assign mem_result   =   inst_ld_b   ? ld_b_result : 
                        inst_ld_bu  ? ld_bu_result:
                        inst_ld_h   ? ld_h_result :
                        inst_ld_hu  ? ld_hu_result: data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

assign out_ms_valid = ms_valid;

assign mem_write_asid_ehi = (inst_tlb_rd     |
                            inst_csrwr      & (csr_num == 14'h18) |
                            inst_csrwr      & (csr_num == 14'h11) |
                            inst_csrxchg    & (csr_num == 14'h18) |
                            inst_csrxchg    & (csr_num == 14'h11)) & ms_valid;

assign mem_refetch = refetch_needed;
endmodule
