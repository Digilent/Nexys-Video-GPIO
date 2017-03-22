`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Digilent Inc.
// Engineer: Arthur Brown
// 
// Create Date: 10/1/2016
// Module Name: top
// Project Name: OLED Demo
// Target Devices: Nexys Video
// Tool Versions: Vivado 2016.2
// Description: creates OLED Demo, handles user inputs to operate OLED control module
// 
// Dependencies: OLEDCtrl.v, debouncer.v, delay_ms.v
// 
// Revision 0.01 - File Created
//
//////////////////////////////////////////////////////////////////////////////////

module OLED_master (
    input  clk,
    input  rstn,
    output oled_sdin,
    output oled_sclk,
    output oled_dc,
    output oled_res,
    output oled_vbat,
    output oled_vdd
);
    //STATE MACHINE CODES:
    localparam  Idle                 = 0;
    localparam  Init                 = 1;
    //display sequence 
    localparam  ActiveWriteAlpha     = 2;
    localparam  ActiveUpdateAlpha    = 3;
    localparam  ActiveDelayAlpha     = 4;
    localparam  ActiveWriteSplash    = 5;
    localparam  ActiveUpdateSplash   = 6;
    localparam  ActiveDelaySplash    = 7;
    localparam  ActiveWait           = 8;
    localparam  Done                 = 9;
    //common states
    localparam  Write                = 11;
    localparam  WriteWait            = 12;
    localparam  UpdateWait           = 13;
    localparam  DelayWait            = 14;
    //debugging state
    localparam  FullDisp             = 10;
    
    // SPLASH screen text
    localparam  splash_str1="This is         ", splash_str1_len=16;
    localparam  splash_str2="Digilent's      ", splash_str2_len=16;
    localparam  splash_str3="Nexys Video     ", splash_str3_len=16;
    localparam  splash_str4="                ", splash_str4_len=16;
    // ALPHA screen text
    localparam  alpha_str1="ABCDEFGHIJKLMNOP", alpha_str1_len=16;
    localparam  alpha_str2="QRSTUVWXYZabcdef", alpha_str2_len=16;
    localparam  alpha_str3="ghijklmnopqrstuv", alpha_str3_len=16;
    localparam  alpha_str4="wxyz0123456789  ", alpha_str4_len=16;
    // select_screen value definitions
    localparam  SPLASH = 1,
                ALPHA = 0;
        
    //startup/bringdown control pin - derived from cpu_resetn(active low)
    wire        rst;
        
    //state machine registers.
    reg   [3:0] state = Idle;
    reg   [3:0] after_state;//"return address" for common states
    reg   [5:0] count = 0;//loop index variable
    reg         screen_select = ALPHA; //
    
    //delay_ms module control signals
    reg         delay_start=0;
    reg  [11:0] delay_time_ms=0;
    wire        delay_done;
        
    //OLEDCtrl module control signals START/DATA/READY fit naming convention *_start / *_OTHER / *_ready
    //   - START command will be ignored unless READY is asserted.
    //   - DATA should be asserted on the same cycle as START is asserted
    //   - START should be deasserted on the clock cycle after it was asserted
    //   - START and READY are active-high
    reg         update_start = 0;        //update oled display over spi
    reg         update_clear = 0;        //when asserted high, an update command clears the display, instead of filling from memory
    wire        update_ready;
    reg         disp_on_start = 0;       //turn the oled display on
    wire        disp_on_ready;
    reg         disp_off_start = 0;      //turn the oled display off
    wire        disp_off_ready;
    reg         toggle_disp_start = 0;   //turns on every pixel on the oled, or returns the display to before each pixel was turned on
    wire        toggle_disp_ready;
    reg         write_start = 0;         //writes a character bitmap into local memory
    wire        write_ready;
    reg   [8:0] write_base_addr = 0;     //location to write character to, two most significant bits are row position, 0 is topmost. bottom seven bits are X position, addressed by pixel x position.
    reg   [7:0] write_ascii_data = 0;    //ascii value of character to write to memory
    
    // extra OLEDCtrl signals to combine DISPLAY_ON(update, disp_off, toggle_disp, write) and DISPLAY_OFF(disp_on) command groups
    wire       init_done;
    wire       init_ready;
    
	assign rst = ~rstn;
    
    // MODULE INSTANTIATIONS
    
    OLED_ctrl OLED (
        .clk                (clk),              
        .write_start        (write_start),      
        .write_ascii_data   (write_ascii_data), 
        .write_base_addr    (write_base_addr),  
        .write_ready        (write_ready),      
        .update_start       (update_start),     
        .update_ready       (update_ready),     
        .update_clear       (update_clear),    
        .disp_on_start      (disp_on_start),    
        .disp_on_ready      (disp_on_ready),    
        .disp_off_start     (disp_off_start),   
        .disp_off_ready     (disp_off_ready),   
        .toggle_disp_start  (toggle_disp_start),
        .toggle_disp_ready  (toggle_disp_ready),
        .SDIN               (oled_sdin),        
        .SCLK               (oled_sclk),        
        .DC                 (oled_dc),        
        .RES                (oled_res),        
        .VBAT               (oled_vbat),        
        .VDD                (oled_vdd)
    );
    
    delay_ms DELAY (
        clk,
        delay_time_ms,
        delay_start,
        delay_done
    );
    
    // COMBINATORIAL LOGIC
    
    always@(write_base_addr)
        if (screen_select == SPLASH)
        case (write_base_addr[8:7])//select string as [y]
        0: write_ascii_data <= 8'hff & (splash_str1 >> ({3'b0, (splash_str1_len - 1 - write_base_addr[6:3])} << 3));//index string parameters as str[x]
        1: write_ascii_data <= 8'hff & (splash_str2 >> ({3'b0, (splash_str2_len - 1 - write_base_addr[6:3])} << 3));
        2: write_ascii_data <= 8'hff & (splash_str3 >> ({3'b0, (splash_str3_len - 1 - write_base_addr[6:3])} << 3));
        3: write_ascii_data <= 8'hff & (splash_str4 >> ({3'b0, (splash_str4_len - 1 - write_base_addr[6:3])} << 3));
        endcase
        else if (screen_select == ALPHA)
        case (write_base_addr[8:7])//select string as [y]
        0: write_ascii_data <= 8'hff & (alpha_str1 >> ({3'b0, (alpha_str1_len - 1 - write_base_addr[6:3])} << 3));//index string parameters as str[x]
        1: write_ascii_data <= 8'hff & (alpha_str2 >> ({3'b0, (alpha_str2_len - 1 - write_base_addr[6:3])} << 3));
        2: write_ascii_data <= 8'hff & (alpha_str3 >> ({3'b0, (alpha_str3_len - 1 - write_base_addr[6:3])} << 3));
        3: write_ascii_data <= 8'hff & (alpha_str4 >> ({3'b0, (alpha_str4_len - 1 - write_base_addr[6:3])} << 3));
        endcase
    
    assign init_done = disp_off_ready | toggle_disp_ready | write_ready | update_ready;//parse ready signals for clarity
    assign init_ready = disp_on_ready;
    
    // STATE MACHINE
    reg once = 1;
    always@(posedge clk)
        case (state)
            Idle: begin
                if ((rst == 1'b1 || once == 1'b1) && init_ready == 1'b1) begin
                    disp_on_start <= 1'b1;
                    state <= Init;
                    once <= 1'b0;
                end
            end
            Init: begin
                disp_on_start <= 1'b0;
                if (rst == 1'b0 && init_done == 1'b1)
                    state <= ActiveWriteAlpha;
            end
            ActiveWriteAlpha: begin
                write_start <= 1'b1;
                write_base_addr <= 'b0;
                screen_select <= ALPHA;
                after_state <= ActiveUpdateAlpha;
                state <= WriteWait;
            end
            ActiveUpdateAlpha: begin
                after_state <= ActiveDelayAlpha;
                state <= UpdateWait;
                update_start <= 1'b1;
                update_clear <= 1'b0;
            end
            ActiveDelayAlpha: begin
                after_state <= ActiveWriteSplash;
                state <= DelayWait;
                delay_start <= 1'b1;
                delay_time_ms <= 4000;
            end
            ActiveWriteSplash: begin
                write_start <= 1'b1;
                write_base_addr <= 'b0;
                screen_select <= SPLASH;
                after_state <= ActiveUpdateSplash;
                state <= WriteWait;
            end
            ActiveUpdateSplash: begin
                after_state <= ActiveDelaySplash;
                state <= UpdateWait;
                update_start <= 1'b1;
                update_clear <= 1'b0;
            end
            ActiveDelaySplash: begin
                after_state <= ActiveWait;
                state <= DelayWait;
                delay_start <= 1'b1;
                delay_time_ms <= 1000;
            end
            ActiveWait: begin // hold until ready, then accept input
                if (rst && disp_off_ready) begin
                    disp_off_start <= 1'b1;
                    state <= Done;
                end
            end
            Write: begin
                write_start <= 1'b1;
                write_base_addr <= write_base_addr + 9'h8;
                //write_ascii_data updated with write_base_addr
                state <= WriteWait;
            end
            DelayWait: begin
                delay_start <= 1'b0;
                if (delay_done == 1'b1)
                    state <= after_state;
            end
            WriteWait: begin
                write_start <= 1'b0;
                if (write_ready == 1'b1)
                    if (write_base_addr == 9'h1f8) begin
                        state <= after_state;
                    end else begin
                        state <= Write;
                    end
            end
            UpdateWait: begin
                update_start <= 0;
                if (update_ready == 1'b1)
                    state <= after_state;
            end
            Done: begin
                disp_off_start <= 1'b0;
                if (rst == 1'b0 && disp_on_ready == 1'b1)
                    state <= Idle;
            end
            FullDisp: begin
                toggle_disp_start <= 1'b0;
                if (init_ready == 1)
                    state <= after_state;
            end
            default: state <= Idle;
        endcase
endmodule
