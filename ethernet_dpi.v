
/* Version 0.82 beta, September 2012.

  See the README file for information about this module.

  Copyright (c) 2011 R. Diez

  This source file may be used and distributed without
  restriction provided that this copyright statement is not
  removed from the file and that any derivative work contains
  the original copyright notice and the associated disclaimer.

  This source file is free software; you can redistribute it
  and/or modify it under the terms of the GNU Lesser General
  Public License version 3 as published by the Free Software Foundation.

  This source is distributed in the hope that it will be
  useful, but WITHOUT ANY WARRANTY; without even the implied
  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU Lesser General Public License for more
  details.

  You should have received a copy of the GNU Lesser General
  Public License along with this source; if not, download it
  from http://www.gnu.org/licenses/
*/

`define ETHDPI_ADDR_WIDTH 32
`define ETHDPI_DATA_WIDTH 32

// Ethernet Controller registers, memory mapped and accessible over the Wishbone bus.
`define ETHDPI_MODER      `ETHDPI_ADDR_WIDTH'h00  // Mode Register
`define ETHDPI_INT        `ETHDPI_ADDR_WIDTH'h04  // Interrupt Source Register
`define ETHDPI_INT_MASK   `ETHDPI_ADDR_WIDTH'h08  // Interrupt Mask Register
`define ETHDPI_IPGT       `ETHDPI_ADDR_WIDTH'h0C  // Back to Bak Inter Packet Gap Register
`define ETHDPI_IPGR1      `ETHDPI_ADDR_WIDTH'h10  // Non Back to Back Inter Packet Gap Register 1
`define ETHDPI_IPGR2      `ETHDPI_ADDR_WIDTH'h14  // Non Back to Back Inter Packet Gap Register 2
`define ETHDPI_PACKETLEN  `ETHDPI_ADDR_WIDTH'h18  // Packet Length Register (min. and max.)
`define ETHDPI_COLLCONF   `ETHDPI_ADDR_WIDTH'h1C  // Collision and Retry Configuration Register
`define ETHDPI_TX_BD_NUM  `ETHDPI_ADDR_WIDTH'h20  // Transmit Buffer Descriptor Number Register
`define ETHDPI_CTRLMODER  `ETHDPI_ADDR_WIDTH'h24  // Control Module Mode Register
`define ETHDPI_MIIMODER   `ETHDPI_ADDR_WIDTH'h28  // MII Mode Register
`define ETHDPI_MIICOMMAND `ETHDPI_ADDR_WIDTH'h2C  // MII Command Register
`define ETHDPI_MIIADDRESS `ETHDPI_ADDR_WIDTH'h30  // MII Address Register
`define ETHDPI_MIITX_DATA `ETHDPI_ADDR_WIDTH'h34  // MII Transmit Data Register
`define ETHDPI_MIIRX_DATA `ETHDPI_ADDR_WIDTH'h38  // MII Receive Data Register
`define ETHDPI_MIISTATUS  `ETHDPI_ADDR_WIDTH'h3C  // MII Status Register
`define ETHDPI_MAC_ADDR0  `ETHDPI_ADDR_WIDTH'h40  // MAC Individual Address Register 0
`define ETHDPI_MAC_ADDR1  `ETHDPI_ADDR_WIDTH'h44  // MAC Individual Address Register 1
`define ETHDPI_HASH_ADDR0 `ETHDPI_ADDR_WIDTH'h48  // Hash Register 0
`define ETHDPI_HASH_ADDR1 `ETHDPI_ADDR_WIDTH'h4C  // Hash Register 1
`define ETHDPI_TX_CTRL    `ETHDPI_ADDR_WIDTH'h50  // Tx Control Register
`define ETHDPI_LAST_REGISTER `ETHDPI_TX_CTRL

`define ETHDPI_BUFFER_DESCRIPTORS_BEGIN `ETHDPI_ADDR_WIDTH'h400  // The Tx descriptors come first, then the Rx. The boundary is at ethreg_tx_bd_num.
`define ETHDPI_BUFFER_DESCRIPTORS_END   `ETHDPI_ADDR_WIDTH'h800  // One address beyond the end.

// MODER register
`define ETHDPI_MODER_RXEN     `ETHDPI_DATA_WIDTH'h00000001  // Receive Enable
`define ETHDPI_MODER_TXEN     `ETHDPI_DATA_WIDTH'h00000002  // Transmit Enable
`define ETHDPI_MODER_NOPRE    `ETHDPI_DATA_WIDTH'h00000004  // No Preamble
`define ETHDPI_MODER_BRO      `ETHDPI_DATA_WIDTH'h00000008  // Reject Broadcast
`define ETHDPI_MODER_IAM      `ETHDPI_DATA_WIDTH'h00000010  // Use Individual Hash
`define ETHDPI_MODER_PRO      `ETHDPI_DATA_WIDTH'h00000020  // Promiscuous (receive all)
`define ETHDPI_MODER_IFG      `ETHDPI_DATA_WIDTH'h00000040  // Min. IFG not required
`define ETHDPI_MODER_LOOPBCK  `ETHDPI_DATA_WIDTH'h00000080  // Loop Back
`define ETHDPI_MODER_NOBCKOF  `ETHDPI_DATA_WIDTH'h00000100  // No Backoff
`define ETHDPI_MODER_EXDFREN  `ETHDPI_DATA_WIDTH'h00000200  // Excess Defer
`define ETHDPI_MODER_FULLD    `ETHDPI_DATA_WIDTH'h00000400  // Full Duplex
`define ETHDPI_MODER_RESET_NOT_USED_ANY_MORE  `ETHDPI_DATA_WIDTH'h00000800  // Used to reset this module, does not work any more.
`define ETHDPI_MODER_DLYCRCEN `ETHDPI_DATA_WIDTH'h00001000  // Delayed CRC Enable
`define ETHDPI_MODER_CRCEN    `ETHDPI_DATA_WIDTH'h00002000  // CRC Enable
`define ETHDPI_MODER_HUGEN    `ETHDPI_DATA_WIDTH'h00004000  // Huge Enable
`define ETHDPI_MODER_PAD      `ETHDPI_DATA_WIDTH'h00008000  // Pad Enable
`define ETHDPI_MODER_RECSMALL `ETHDPI_DATA_WIDTH'h00010000  // Receive Small
`define ETHDPI_MODER_RESERVED ( `ETHDPI_DATA_WIDTH'hFFFE0000 + `ETHDPI_MODER_RESET_NOT_USED_ANY_MORE ) // Reserved bits.

// Definitions for the INT (Interrupt Source) and INT_MASK registers.
`define ETHDPI_INT_RESERVED 31:7
`define ETHDPI_INT_ALL 6:0
`define ETHDPI_INT_RXC  6  // A Control Frame was received. Always 0, as this implementation does not support receiving Ethernet flow control frames.
`define ETHDPI_INT_TXC  5  // A Control Frame was transmitted. Always 0, as this implementation does not support sending Ethernet flow control frames.
`define ETHDPI_INT_BUSY 4  // A frame was discarded due to insufficient number of receive buffers.
                           // Always 0, as this implementation does not support this feature. Ethernet Frames will only be read
                           // from the TAP interface if there is an available Buffer Descriptor. If the TAP interface's internal buffer
                           // overflows, data will be lost without warning.
`define ETHDPI_INT_RXE  3  // Receive Error, can never happen.
`define ETHDPI_INT_RXF  2  // Receive Frame (frame has been received).
`define ETHDPI_INT_TXE  1  // Transmit Error, can never happen.
`define ETHDPI_INT_TXB  0  // Transmit Buffer (frame has been transmitted).

// PACKETLEN register.
`define ETHDPI_PACKETLEN_MINFL 31:16
`define ETHDPI_PACKETLEN_MAXFL 15:0

// TX_CTRL register.
`define ETHDPI_TX_CTRL_RESERVED 31:17
`define ETHDPI_TX_CTRL_TXPAUSERQ 16
`define ETHDPI_TX_CTRL_TXPAUSETV 15:0

// MIICOMMAND register.
`define ETHDPI_MIICOMMAND_RESERVED 31:3
`define ETHDPI_MIICOMMAND_WCTRLDATA 2  // Write Control Data
`define ETHDPI_MIICOMMAND_RSTAT     1  // Read Status.
`define ETHDPI_MIICOMMAND_SCANSTAT  0  // Scan Status.

// MIIRX_DATA value for the RSTAT command in the MIICOMMAND register.
`define ETHDPI_MII_RSTAT_LINK_ESTABLISHED_MASK `ETHDPI_DATA_WIDTH'h0004  // Link established

// Tx Buffer Descriptor Flags
`define ETHDPI_TXBD_LEN 31:16  // Data length.
`define ETHDPI_TXBD_RD  15     // Ready.
`define ETHDPI_TXBD_IRQ 14
`define ETHDPI_TXBD_WR  13     // Wrap to the first Buffer Descriptor after processing this one.
`define ETHDPI_TXBD_PAD 12     // Add padding.
`define ETHDPI_TXBD_CRC 11     // Calculate and append the CRC to the frame.
`define ETHDPI_TXBD_RESERVED 10:9
`define ETHDPI_TXBD_UR   8     // Underrun (can never happen).
`define ETHDPI_TXBD_RTRY 7:4   // Retry.
`define ETHDPI_TXBD_RL   3     // Retransmission Limit (can never happen).
`define ETHDPI_TXBD_LC   2     // Late Collision (collision detected during transmission).
`define ETHDPI_TXBD_DF   1     // Defer Indication.
`define ETHDPI_TXBD_CS   0     // Carrier Sense Lost.

// Rx Buffer Descriptor Flags
`define ETHDPI_RXBD_LEN 31:16  // Data length.
`define ETHDPI_RXBD_RD   15     // Is Empty.
`define ETHDPI_RXBD_IRQ  14
`define ETHDPI_RXBD_WR   13      // Wrap to the first Buffer Descriptor after processing this one.
`define ETHDPI_RXBD_RESERVED 12:9
`define ETHDPI_RXBD_CF    8      // Control Frame received (as opposed to normal data). Control Frames are not supported, so this is always zero.
`define ETHDPI_RXBD_M     7      // Miss (received only because the interface is in promiscuous mode) (can never happen).
`define ETHDPI_RXBD_OR    6      // Overrun during reception (can never happen).
`define ETHDPI_RXBD_IS    5      // Invalid Symbol (can never happen).
`define ETHDPI_RXBD_DN    4      // Dribble Nibble (received frame cannot be divided by 8, an extra nibble was added) (can never happen).
`define ETHDPI_RXBD_TL    3      // Too Long (bigger than the current PAKETLEN register) (can never happen).
`define ETHDPI_RXBD_SF    2      // Short Frame (smaller than PAKETLEN register) (can never happen).
`define ETHDPI_RXBD_CRC   1      // CRC error (can never happen).
`define ETHDPI_RXBD_LC    0      // Late Collision (collision detected during reception) (can never happen).
`define ETHDPI_RXBD_CLEAR_ERRORS_MASK  ~( `ETHDPI_RXBD_OR | `ETHDPI_RXBD_IS | `ETHDPI_RXBD_DN | `ETHDPI_RXBD_TL | `ETHDPI_RXBD_SF | `ETHDPI_RXBD_CRC | `ETHDPI_RXBD_LC )

`define ETHDPI_EXPECTED_WB_SEL_VALUE 4'b1111
`define ETHDPI_M_WB_SEL_VALUE        4'b1111


module ethernet_dpi (
                     // WISHBONE common
                     input wire  wb_clk_i,
                     input wire  wb_rst_i,  // There is no need to assert reset at the beginning.

                     // WISHBONE slave, used to access the Ethernet Controller's registers.
                     input  wire [`ETHDPI_DATA_WIDTH-1:0] wb_dat_i,
                     input  wire [3:0] wb_sel_i,  // See ETHDPI_EXPECTED_WB_SEL_VALUE.
                     input  wire wb_we_i,
                     output wire [`ETHDPI_DATA_WIDTH-1:0] wb_dat_o,
                     input  wire [`ETHDPI_ADDR_WIDTH-1:0] wb_adr_i,
                     input  wire wb_cyc_i,
                     input  wire wb_stb_i,
                     output wire wb_ack_o,
                     output wire wb_err_o,

                     // WISHBONE master, used by the Ethernet Controller to access the main memory in a DMA fashion.
                     output wire [`ETHDPI_ADDR_WIDTH-1:0] m_wb_adr_o,
                     output wire [3:0] m_wb_sel_o,
                     output wire m_wb_we_o,
                     output wire [`ETHDPI_DATA_WIDTH-1:0] m_wb_dat_o,
                     input  wire [`ETHDPI_DATA_WIDTH-1:0] m_wb_dat_i,
                     output wire m_wb_cyc_o,
                     output wire m_wb_stb_o,
                     input  wire m_wb_ack_i,
                     input  wire m_wb_err_i,

                     output wire int_o  // Ethernet interrupt request
                    );

   // --- DPI definitions begin ---
   import "DPI-C" function int ethernet_dpi_create ( input string   tap_interface_name,
                                                     input bit      print_informational_messages,
                                                     input string   informational_message_prefix,
                                                     output longint obj );

   // It is not necessary to call ethernet_dpi_destroy(). However, calling it
   // will release all resources associated with the Ethernet DPI instance, and that can help
   // identify resource or memory leaks in other parts of the software.
   import "DPI-C" function void ethernet_dpi_destroy ( input longint obj );

   // Polls the TAP interface, in order to check 1) whether there is an incoming frame ready to be received,
   // and 2) whether the send buffer is empty and ready to accept a new outgoing frame.
   // Possible optimisation: use async I/O or a second thread to avoid polling the TAP interface every time.
   import "DPI-C" function int ethernet_dpi_tick ( input longint obj,
                                                   output int received_frame_byte_count,
                                                   output bit ready_to_send );

   // Discards all received frames until the TAP interface reports that no more frames are available.
   import "DPI-C" function int ethernet_dpi_flush_tap_receive_buffer ( input longint obj );

   // ------ Routines to send frames ------

   import "DPI-C" function int ethernet_dpi_new_tx_frame ( input longint obj );

   import "DPI-C" function int ethernet_dpi_add_byte_to_tx_frame ( input longint obj,
                                                                   input byte data );
   // Before sending a frame, make sure that ethernet_dpi_tick() returned ready_to_send == 1.
   import "DPI-C" function int ethernet_dpi_send_tx_frame ( input longint obj );


   // ------ Routines to receive frames ------

   // Before reading a frame's data, make sure that ethernet_dpi_tick() returned received_frame_byte_count > 0.
   import "DPI-C" function int ethernet_dpi_get_received_frame_byte ( input  longint obj,
                                                                      input  int     offset,
                                                                      output byte    data );

   // After reading all frame bytes, call this routine in order to discard it.
   // ethernet_dpi_tick() will then load the next one from the TAP interface.
   import "DPI-C" function int ethernet_dpi_discard_received_frame ( input longint obj );

   // --- DPI definitions end ---

   parameter module_name = "Ethernet DPI";
   parameter tap_interface_name = "dpi-tap1";

   // Whether the C++ side prints informational messages to stdout.
   // Error messages cannot be turned off and get printed to stderr.
   parameter print_informational_messages = 1;


   // ---- Ethernet Controller registers begin.
   reg [31:0] ethreg_moder;
   reg [47:0] ethreg_mac_addr;
   reg [31:0] ethreg_tx_bd_num;
   reg [`ETHDPI_INT_ALL] ethreg_int;
   reg [`ETHDPI_INT_ALL] ethreg_int_mask;
   reg [31:0] ethreg_miiaddr;
   reg [31:0] ethreg_miitx_data;
   reg [31:0] ethreg_miimoder;
   reg [31:0] ethreg_ipgt;
   reg [31:0] ethreg_ipgr1;
   reg [31:0] ethreg_ipgr2;
   reg [31:0] ethreg_tx_ctrl;
   reg [31:0] ethreg_packetlen;
   reg [31:0] ethreg_collconf;
   reg [31:0] ethreg_miicommand;
   reg [31:0] ethreg_ctrlmoder;
   //  ---- Ethernet Controller registers end.

   localparam buffer_descriptor_count = 128;

   reg  [31:0] buffer_descriptor_flags    [ buffer_descriptor_count-1 : 0 ];
   reg  [31:0] buffer_descriptor_addresses[ buffer_descriptor_count-1 : 0 ];

   longint   obj;  // There can be several instances of this module, and each one has a diferent obj value,
                   // which is a pointer to a class instance on the C++ side.

   typedef enum { state_idle,
                  state_waiting_for_dma_read_to_complete,
                  state_wait_state_between_dma_reads,
                  state_waiting_for_dma_write_to_complete,
                  state_wait_state_between_dma_writes
                } state_machine_state_enum;

   state_machine_state_enum current_state;

   int current_tx_bd_index;
   int current_rx_bd_index;
   int current_dma_addr_offset;
   bit received_frame_mac_addr_miss_flag;

   `define ETHDPI_ERROR_PREFIX       { module_name, " error: " }
   `define ETHDPI_INFORMATION_PREFIX { module_name, ": " }
   `define ETHDPI_TRACE_PREFIX       { module_name, ": " }


   // Thin wrapper around ethernet_dpi_get_received_frame_byte() that checks for any error returned.
   task automatic get_received_frame_byte;
      input  int  offset;
      output byte data;
      begin
         if ( 0 != ethernet_dpi_get_received_frame_byte( obj, offset, data ) )
           begin
              $display( "%sError reading a byte from the received frame at offset 0x%08X.", `ETHDPI_ERROR_PREFIX, offset );
              $finish;
           end;
      end
   endtask;


   // When writing to memory over DMA, we can only write 32 bits at a time,
   // but we may only have 1, 2 or 3 of bytes of data to write for the last 32-bit memory address.
   // This routine helps build those last 4 bytes by padding with zeroes if necessary.

   task automatic get_received_frame_byte_with_alignment_padding;
      input  int  offset;
      input  int  received_frame_byte_count;
      output byte data;
      begin
         if ( offset >= received_frame_byte_count )
           begin
              if ( offset - received_frame_byte_count >= 4 )
                begin
                   $display( "%sInternal error, receive offset %d is out of range by more than the alignment distance.", `ETHDPI_ERROR_PREFIX, offset );
                   $finish;
                end;

              data = 0;
           end
         else
           begin
              get_received_frame_byte( offset, data );
           end;
      end
   endtask;


   // Pads with zeroes if necessary, see get_received_frame_byte_with_alignment_padding() for more information.
   task automatic get_32_bits_worth_of_received_frame_data;
      input  int  offset;
      input  int  received_frame_byte_count;
      output reg [31:0] data;
      begin
         byte b1, b2, b3, b4;

         if ( 0 != ( offset % 4 ) )
           begin
              $display( "%sInternal error: the Ethernet frame offset is not aligned.", `ETHDPI_ERROR_PREFIX );
              $finish;
           end;

         get_received_frame_byte_with_alignment_padding( offset + 0, received_frame_byte_count, b1 );
         get_received_frame_byte_with_alignment_padding( offset + 1, received_frame_byte_count, b2 );
         get_received_frame_byte_with_alignment_padding( offset + 2, received_frame_byte_count, b3 );
         get_received_frame_byte_with_alignment_padding( offset + 3, received_frame_byte_count, b4 );

         // $display( "Received bytes: 0x%02X, 0x%02X, 0x%02X, 0x%02X\n", b1, b2, b3, b4 );

         data = { b1, b2, b3, b4 };
      end
   endtask;


   task automatic wishbone_write;
      begin
         // $display( "%sWishbone write to wb_adr_i=0x%08X, data=0x%08X.", `ETHDPI_TRACE_PREFIX, wb_adr_i, wb_dat_i );

         // Error if the client tries to write to certain registers while Tx or Rx are enabled.
         unique case ( wb_adr_i )
           `ETHDPI_MODER,
           `ETHDPI_INT,
           `ETHDPI_INT_MASK:
             begin
                // Nothing to do here.
             end

           `ETHDPI_MIIADDRESS,
           `ETHDPI_MIITX_DATA,
           `ETHDPI_MIIRX_DATA,
           `ETHDPI_IPGT,
           `ETHDPI_IPGR1,
           `ETHDPI_IPGR2,
           `ETHDPI_TX_CTRL,
           `ETHDPI_PACKETLEN,
           `ETHDPI_COLLCONF,
           `ETHDPI_TX_BD_NUM,
           `ETHDPI_CTRLMODER,
           `ETHDPI_MIIMODER,
           `ETHDPI_MIICOMMAND,
           `ETHDPI_MIISTATUS,
           `ETHDPI_MAC_ADDR0,
           `ETHDPI_MAC_ADDR1,
           `ETHDPI_HASH_ADDR0,
           `ETHDPI_HASH_ADDR1:
             if ( 0 != ( ethreg_moder & ( `ETHDPI_MODER_TXEN | `ETHDPI_MODER_RXEN ) ) )
               begin
                  $display( "%sThe client is trying to write to register 0x%02X after the TXEN or RXEN flag has been set. The documentation states that this should not be done.",
                            `ETHDPI_ERROR_PREFIX, wb_adr_i );
                  $finish;
               end

           default:
             begin
                if ( wb_adr_i <  `ETHDPI_BUFFER_DESCRIPTORS_BEGIN ||
                     wb_adr_i >= `ETHDPI_BUFFER_DESCRIPTORS_END   )
                  begin
                     $display( "%sDefault case in for Wishbone write wb_adr_i=0x%02X.", `ETHDPI_ERROR_PREFIX, wb_adr_i );
                     $finish;
                  end;
             end
         endcase;


         unique case ( wb_adr_i )
           `ETHDPI_MODER:
             begin
                // $display( "%sWriting to ETHDPI_MODER data: 0x%08X", `ETHDPI_TRACE_PREFIX, wb_dat_i );

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_RESERVED ) )
                  begin
                     if ( 0 != ( wb_dat_i & `ETHDPI_MODER_RESET_NOT_USED_ANY_MORE ) )
                       begin
                          $display( "%sThe client is trying to reset this module with the RESET bit in the Mode Register (MODER), which is no longer supported by the real Ethernet core. This Ethernet simulation model does not support it either.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end
                     else
                       begin
                          $display( "%sThe client is setting the reserved bits in the Mode Register (MODER), which is probably an error.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;
                  end;

                // NOTE: The Excess Defer (EXDFREN), the No Backoff (NOBCKOF) and the Interframe Gap (IFG)
                //       flags are ignored, as there can be no Ethernet collisions or transmission delays
                //       on the TAP interface.

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_NOPRE ) )
                  begin
                     $display( "%sThe client is setting the NOPRE bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_IAM ) )
                  begin
                     $display( "%sThe client is setting the IAM bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_LOOPBCK ) )
                  begin
                     $display( "%sThe client is setting the LOOPBCK bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_NOBCKOF ) )
                  begin
                     $display( "%sThe client is setting the NOBCKOF bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_DLYCRCEN ) )
                  begin
                     // If this feature is ever implemented, keep in mind that the TAP interface does not send
                     // or receive the CRC, so it's not possible to simulate sending an invalid CRC.
                     $display( "%sThe client is setting the DLYCRCEN bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_HUGEN ) )
                  begin
                     $display( "%sThe client is setting the HUGEN bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                /* The PAD bit is ignored, see the README file for details.
                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_PAD ) )
                  begin
                     $display( "%sThe client is setting the PAD bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;
                */

                if ( 0 != ( wb_dat_i & `ETHDPI_MODER_RECSMALL ) )
                  begin
                     $display( "%sThe client is setting the RECSMALL bit in the Mode Register (MODER), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != ( wb_dat_i     & `ETHDPI_MODER_RXEN ) &&
                     0 == ( ethreg_moder & `ETHDPI_MODER_RXEN ) )
                  begin
                     // If the "enable rx" flag changes from 0 to 1, flush the TAP interface receive buffer.
                     // Otherwise, we might receive stale frames.
                     ethernet_dpi_flush_tap_receive_buffer( obj );
                  end

                ethreg_moder <= wb_dat_i;
             end

           `ETHDPI_MIIADDRESS:  ethreg_miiaddr    <= wb_dat_i;  // The value in this register is ignored.
           `ETHDPI_MIITX_DATA:  ethreg_miitx_data <= wb_dat_i;  // The value in this register is ignored.
           `ETHDPI_MIIRX_DATA:
             begin
                $display( "%sThe client is trying to write to the MIIRX register, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                $finish;
             end
           `ETHDPI_MIIMODER:    ethreg_miimoder   <= wb_dat_i;  // The value in this register is ignored.

           `ETHDPI_IPGT:  ethreg_ipgt  <= wb_dat_i;  // The value in this register is ignored.
           `ETHDPI_IPGR1: ethreg_ipgr1 <= wb_dat_i;  // The value in this register is ignored.
           `ETHDPI_IPGR2: ethreg_ipgr2 <= wb_dat_i;  // The value in this register is ignored.

           `ETHDPI_TX_CTRL:
             begin
                if ( 0 != wb_dat_i[`ETHDPI_TX_CTRL_RESERVED] )
                  begin
                     $display( "%sThe client is trying to set reserved bits in TX CTRL register, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( 0 != wb_dat_i[`ETHDPI_TX_CTRL_TXPAUSERQ] )
                  begin
                     $display( "%sThe client is trying to send an Ethernet pause control frame, which is not supported yet by this implementation.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                ethreg_tx_ctrl <= wb_dat_i;
             end

           `ETHDPI_INT:
             begin
                if ( 0 != wb_dat_i[`ETHDPI_INT_RESERVED] )
                  begin
                     $display( "%sThe client is trying to clear reserved bits in the Interrupt Source Register (INT_SOURCE), which is probably an error.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                // $display("%sReg int: old: 0b%7B, new: 0b%7B",
                //          `ETHDPI_TRACE_PREFIX,
                //          ethreg_int,
                //          ethreg_int & (~ wb_dat_i[`ETHDPI_INT_ALL]) );

                ethreg_int <= ethreg_int & (~ wb_dat_i[`ETHDPI_INT_ALL] );
             end

           `ETHDPI_INT_MASK:
             begin
                if ( 0 != wb_dat_i[`ETHDPI_INT_RESERVED] )
                  begin
                     $display( "%sThe client is setting the reserved bits in the Interrupt Mask Register (INT_MASK), which is probably an error.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                /* Although the user can set any of the following interrupt mask bits,
                   the associated interrupts are never triggered by this simulation module.

                if ( wb_dat_i[`ETHDPI_INT_RXC] )
                  begin
                     $display( "%sThe client is setting the RXC bit in the Interrupt Mask Register (INT_MASK), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[`ETHDPI_INT_TXC] )
                  begin
                     $display( "%sThe client is setting the TXC bit in the Interrupt Mask Register (INT_MASK), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[`ETHDPI_INT_BUSY] )
                  begin
                     $display( "%sThe client is setting the BUSY bit in the Interrupt Mask Register (INT_MASK), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[`ETHDPI_INT_RXE] )
                  begin
                     $display( "%sThe client is setting the RXE bit in the Interrupt Mask Register (INT_MASK), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[`ETHDPI_INT_TXE] )
                  begin
                     $display( "%sThe client is setting the TXE bit in the Interrupt Mask Register (INT_MASK), which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;
                */

                ethreg_int_mask <= wb_dat_i[`ETHDPI_INT_ALL];
             end

           `ETHDPI_MAC_ADDR0:
             begin
                ethreg_mac_addr[31:0] <= wb_dat_i;
             end

           `ETHDPI_MAC_ADDR1:
             begin
                if ( 0 != wb_dat_i[31:16] )
                  begin
                     $display( "%sThe client is setting the reserved bits in the Ethernet MAC Address 1 Register (MAC_ADDR1), which is probably an error.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                ethreg_mac_addr[47:32] <= wb_dat_i[15:0];
             end

           `ETHDPI_TX_BD_NUM:
             begin
                // NOTE: according to the specification, out-of-range values should be ignored, that is,
                //       they are not written to the register.
                if ( wb_dat_i > buffer_descriptor_count )
                  begin
                     $display( "%sThe client is trying to write an out-of-range value to the register that specifies the number of Transmit Buffer Descriptors (TX_BD_NUM). The out-of-range value will be ignored, but this is probably an error in the client software.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end
                else
                  begin
                     ethreg_tx_bd_num <= wb_dat_i;

                     // Reset the transmit and receive buffer indexes.
                     // This is not documented in the real Ethernet core, so it may behave differently.
                     // The trouble is, there is no way to reset this simulation model any more from
                     // the software driver, and this is the only way to reset the buffer indexes.
                     // The software can reset all other registers by hand.
                     current_tx_bd_index <= 0;        // Note that there might not be any Tx Buffer Descriptors (all of them are Rx).
                     current_rx_bd_index <= wb_dat_i; // Note that there might not be any Rx Buffer Descriptors (all of them are Tx).
                  end;
             end

           `ETHDPI_HASH_ADDR0,
           `ETHDPI_HASH_ADDR1:
             begin
                $display( "%sMAC address recognition with hash tables is not implemented yet.", `ETHDPI_ERROR_PREFIX );
                $finish;
             end

           `ETHDPI_PACKETLEN:
             begin
                if ( 0 != ( wb_dat_i[ `ETHDPI_PACKETLEN_MAXFL ] % 4 ) )
                  begin
                     $display( "%sThe client is trying to set the maximum frame length to an unaligned value. This is dangerous because both the real Ethernet core and this simulation model will write beyond this limit up until the next alignment boundary, causing a buffer overflow in the receive buffers.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[ `ETHDPI_PACKETLEN_MAXFL ] < wb_dat_i[ `ETHDPI_PACKETLEN_MINFL ] )
                  begin
                     $display( "%sThe client is trying to set a maximum frame length of %d that is less than the minimum frame length of %d. This is probably an error at the client side.",
                               `ETHDPI_ERROR_PREFIX, wb_dat_i[ `ETHDPI_PACKETLEN_MAXFL ], wb_dat_i[ `ETHDPI_PACKETLEN_MINFL ] );
                     $finish;
                  end;

                ethreg_packetlen <= wb_dat_i;
             end

           `ETHDPI_COLLCONF:   ethreg_collconf <= wb_dat_i;  // Collision and Retry Configuration, the value in this register is ignored.

           `ETHDPI_MIISTATUS:
             begin
                $display( "%sThe client is trying to write to the MIISTATUS register, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                $finish;
             end

           `ETHDPI_MIICOMMAND:
             begin
                if ( 0 != wb_dat_i[ `ETHDPI_MIICOMMAND_RESERVED ] )
                  begin
                     $display( "%sThe client is setting the reserved bits in the MIICOMMAND register, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[ `ETHDPI_MIICOMMAND_WCTRLDATA ] )
                  begin
                     $display( "%sThe client is setting the WCTRLDATA bit in the MIICOMMAND register, which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_dat_i[ `ETHDPI_MIICOMMAND_SCANSTAT ] )
                  begin
                     $display( "%sThe client is setting the SCANSTAT bit in the MIICOMMAND register, which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                ethreg_miicommand <= wb_dat_i;
             end

           `ETHDPI_CTRLMODER:   ethreg_ctrlmoder  <= wb_dat_i;  // The value in this register is ignored.

           default:
             begin
                if ( wb_adr_i >= `ETHDPI_BUFFER_DESCRIPTORS_BEGIN &&
                     wb_adr_i <  `ETHDPI_BUFFER_DESCRIPTORS_END )
                  begin
                     integer bd_index = ( wb_adr_i - `ETHDPI_BUFFER_DESCRIPTORS_BEGIN ) / 8;
                     bit     is_first_word_in_bd = !wb_adr_i[2];
                     bit     is_tx = ( bd_index < ethreg_tx_bd_num );
                     bit     is_bd_enabled;

                     /* $display( "%sWriting to Buffer Descriptor %d, is first word: %d, is tx: %d, data: 0x%08X.",
                               `ETHDPI_TRACE_PREFIX, bd_index, is_first_word_in_bd, is_tx, wb_dat_i ); */

                     if ( is_tx )
                       begin
                          is_bd_enabled = ( 0 != ( ethreg_moder & `ETHDPI_MODER_TXEN ) ) &&
                                          buffer_descriptor_flags[ bd_index ][ `ETHDPI_TXBD_RD ];
                       end
                     else
                       begin
                          is_bd_enabled = ( 0 != ( ethreg_moder & `ETHDPI_MODER_RXEN ) &&
                                          buffer_descriptor_flags[ bd_index ][ `ETHDPI_RXBD_RD ] );
                       end;

                     if ( is_bd_enabled )
                       begin
                          $display( "%sThe client is trying to update a Buffer Descriptor which has been previously enabled for transmission or reception and could possibly be in use by the Ethernet Controller. This is probably an error in the client.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( is_first_word_in_bd )
                       begin
                          if ( is_tx )
                            begin
                               if ( 0 != wb_dat_i[`ETHDPI_TXBD_RESERVED] )
                                 begin
                                    $display( "%sThe client is trying to set reserved bits in the Tx Buffer Descriptor, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                                    $finish;
                                 end;

                               /* The PAD bit is ignored, see the README file for details.
                               if ( 0 != ( wb_dat_i[`ETHDPI_TXBD_PAD] ) )
                                 begin
                                    $display( "%sThe client is setting the PAD bit in the Tx Buffer Descriptor, which is not supported yet.", `ETHDPI_ERROR_PREFIX );
                                    $finish;
                                 end; */

                               // There is a global CRC flag in the MODER register and another CRC flag in the Tx Buffer Descriptor,
                               // and it is not clear in the Ethernet core documentation (as of dec 2011) how those two work together.
                               // However, I've seen assignment "CrcEnIn(r_CrcEn | PerPacketCrcEn)" in the Verilog source code,
                               // so I guess either flag will enable CRC generation.
                               if ( 0 == ( wb_dat_i[`ETHDPI_TXBD_CRC] ) &&
                                    0 == ( ethreg_moder & `ETHDPI_MODER_CRCEN ) )
                                 begin
                                    $display( "%sThe client is trying to send an Ethernet frame with an already-calculated CRC at the end, as both the TXBD_CRC bit in the Tx Buffer Descriptor and the CRCEN bit in the Mode Register (MODER) are not set. This is however not supported yet, the Ethernet Controller must be configured to generate the CRC itself.", `ETHDPI_ERROR_PREFIX );
                                    $finish;
                                 end;

                               /* $display( "%sSetting Tx Buffer Descriptor: data len: %d",
                                         `ETHDPI_TRACE_PREFIX,
                                         wb_dat_i[`ETHDPI_TXBD_LEN] ); */
                            end
                          else
                            begin
                               if ( 0 != wb_dat_i[`ETHDPI_RXBD_RESERVED] )
                                 begin
                                    $display( "%sThe client is trying to set reserved bits in the Rx Buffer Descriptor, which is probably an error.", `ETHDPI_ERROR_PREFIX );
                                    $finish;
                                 end;

                               /* $display( "%sSetting Rx Buffer Descriptor: data len: %d",
                                         `ETHDPI_TRACE_PREFIX,
                                         wb_dat_i[`ETHDPI_RXBD_LEN] ); */
                            end;

                          buffer_descriptor_flags[ bd_index ] <= wb_dat_i;
                       end
                     else
                       begin
                          /* $display( "%sSet the Buffer Descriptor to address: 0x%08X.",
                                    `ETHDPI_TRACE_PREFIX,
                                    wb_dat_i ); */

                          if ( 0 != ( wb_dat_i % 4 ) )
                            begin
                               $display( "%sThe client is trying to write an unaligned memory address to a Buffer Descriptor, but this Ethernet simulation model does not support unaligned memory addresses.", `ETHDPI_ERROR_PREFIX );
                               $finish;
                            end;

                          buffer_descriptor_addresses[ bd_index ] <= wb_dat_i;
                       end
                  end
                else
                  begin
                     if ( wb_adr_i <= `ETHDPI_LAST_REGISTER )
                       begin
                          $display( "%sThe client is trying to write to register 0x%02X, which does not exist or has not been implemented yet. Please contact the author of this module for help.",
                                    `ETHDPI_ERROR_PREFIX, wb_adr_i );
                          $finish;
                       end
                     else
                       begin
                          $display( "%sDefault case for Wishbone write wb_adr_i=0x%02X.", `ETHDPI_ERROR_PREFIX, wb_adr_i );
                          $finish;
                       end;
                  end;
             end
         endcase;
      end
   endtask


   task automatic wishbone_read;
      begin
         // $display( "%sWishbone read from wb_adr_i=0x%08X.", `ETHDPI_TRACE_PREFIX, wb_adr_i );

         unique case ( wb_adr_i )
           `ETHDPI_MODER:
             wb_dat_o <= ethreg_moder;

           `ETHDPI_INT:
             begin
                wb_dat_o[ `ETHDPI_INT_RESERVED ] <= 0;
                wb_dat_o[ `ETHDPI_INT_ALL      ] <= ethreg_int[ `ETHDPI_INT_ALL ];
             end

           `ETHDPI_INT_MASK:
             begin
                wb_dat_o[ `ETHDPI_INT_RESERVED ] <= 0;
                wb_dat_o[ `ETHDPI_INT_ALL      ] <= ethreg_int_mask[ `ETHDPI_INT_ALL ];
             end

           `ETHDPI_IPGT:   wb_dat_o <= ethreg_ipgt;
           `ETHDPI_IPGR1:  wb_dat_o <= ethreg_ipgr1;
           `ETHDPI_IPGR2:  wb_dat_o <= ethreg_ipgr2;

           `ETHDPI_PACKETLEN:   wb_dat_o <= ethreg_packetlen;
           `ETHDPI_COLLCONF:    wb_dat_o <= ethreg_collconf;
           `ETHDPI_TX_BD_NUM:   wb_dat_o <= ethreg_tx_bd_num;
           `ETHDPI_CTRLMODER:   wb_dat_o <= ethreg_ctrlmoder;
           `ETHDPI_MIIMODER:    wb_dat_o <= ethreg_miimoder;
           `ETHDPI_MIICOMMAND:  wb_dat_o <= ethreg_miicommand;
           `ETHDPI_MIIADDRESS:  wb_dat_o <= ethreg_miiaddr;
           `ETHDPI_MIITX_DATA:  wb_dat_o <= ethreg_miitx_data;
           `ETHDPI_MIIRX_DATA:
             begin
                // I am not sure what to do if other bits of the MIICOMMAND registers are set,
                // therefore I am being rather restrictive here, the MIICOMMAND register
                // must have just this one bit set.
                if ( ethreg_miicommand != (1 << `ETHDPI_MIICOMMAND_RSTAT) )
                  begin
                     $display( "%sThe client is trying to read the MIIRX_DATA register, but the value in the MIICOMMAND register is not supported yet.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                // The "Link Established" bit is documented as 'sticky', but that does not really matter here,
                // as we are always reporting a "link up" status.
                wb_dat_o <= `ETHDPI_MII_RSTAT_LINK_ESTABLISHED_MASK;
             end

           `ETHDPI_MIISTATUS:
             wb_dat_o <= 0;  // About the BUSY     bit: it's always zero, as all simulated operations are completed instantly.
                             // About the LINKFAIL bit: it's always zero, as the TAP interface always provides a connected virtual cable.

           `ETHDPI_MAC_ADDR0:
             wb_dat_o <= ethreg_mac_addr[31:0];

           `ETHDPI_MAC_ADDR1:
             begin
                wb_dat_o[15:0]  <= ethreg_mac_addr[47:32];
                wb_dat_o[31:16] <= 0;
             end

           `ETHDPI_HASH_ADDR0:
             wb_dat_o <= 0;  // Not supported yet.

           `ETHDPI_HASH_ADDR1:
             wb_dat_o <= 0;  // Not supported yet.

           `ETHDPI_TX_CTRL:
             wb_dat_o <= ethreg_tx_ctrl;

           default:
             begin
                if ( wb_adr_i >= `ETHDPI_BUFFER_DESCRIPTORS_BEGIN &&
                     wb_adr_i <  `ETHDPI_BUFFER_DESCRIPTORS_END )
                  begin
                     integer bd_index = ( wb_adr_i - `ETHDPI_BUFFER_DESCRIPTORS_BEGIN ) / 8;
                     integer _unused_ok = bd_index;  // Prevents 'unused' warning under Verilator for some of the 32 bits in bd_index.
                     bit     is_first_word_in_bd = !wb_adr_i[2];

                     if ( is_first_word_in_bd )
                       wb_dat_o <= buffer_descriptor_flags[ bd_index ];
                     else
                       wb_dat_o <= buffer_descriptor_addresses[ bd_index ];
                  end
                else
                  begin
                     $display( "%sDefault case for Wishbone read wb_adr_i=0x%02X.", `ETHDPI_ERROR_PREFIX, wb_adr_i );
                     $finish;
                     // In case you comment out the error above:
                     wb_dat_o <= 0;
                  end;
             end
         endcase;
      end
   endtask


   task automatic start_wishbone_master_cycle;
      begin
         m_wb_sel_o <= `ETHDPI_M_WB_SEL_VALUE;
         m_wb_cyc_o <= 1;
         m_wb_stb_o <= 1;
      end
   endtask

   task automatic stop_wishbone_master_cycle;
      begin
         m_wb_cyc_o <= 0;
         m_wb_stb_o <= 0;
         m_wb_dat_o <= 0;
         m_wb_we_o  <= 0;
         m_wb_sel_o <= 0;
         m_wb_adr_o <= 0;
      end
   endtask

   task automatic clear_wishbone_slave_outputs;
      begin
         wb_dat_o <= 0;
         wb_ack_o <= 0;
         wb_err_o <= 0;
      end
   endtask


   task automatic step_state_machine;
      input int received_frame_byte_count;
      input bit ready_to_send;
      begin
         unique case ( current_state )

           state_idle:
             begin
                if ( ready_to_send &&
                     0 != ( ethreg_moder & `ETHDPI_MODER_TXEN ) &&
                     ethreg_tx_bd_num > 0 &&
                     buffer_descriptor_flags[ current_tx_bd_index ][ `ETHDPI_TXBD_RD ] )
                  begin
                     /* $display("%sInitiating DMA read for Tx Buffer Descriptor %d, address 0x%08X, data length is %d bytes.",
                              `ETHDPI_TRACE_PREFIX,
                              current_tx_bd_index,
                              buffer_descriptor_addresses[ current_tx_bd_index ],
                              buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_LEN] ); */

                     if ( buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_LEN] < 4 )
                       begin
                          $display( "%sThe data length to send is too small.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( 0 != ethernet_dpi_new_tx_frame( obj ) )
                       begin
                          $display( "%sError preparing a new Ethernet frame to send.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     m_wb_adr_o <= buffer_descriptor_addresses[ current_tx_bd_index ];
                     m_wb_we_o  <= 0;
                     m_wb_dat_o <= 0;
                     start_wishbone_master_cycle;

                     current_dma_addr_offset <= 0;

                     current_state <= state_waiting_for_dma_read_to_complete;
                  end
                else if ( received_frame_byte_count > 0 &&
                          0 != ( ethreg_moder & `ETHDPI_MODER_RXEN ) &&
                          ethreg_tx_bd_num < buffer_descriptor_count &&
                          buffer_descriptor_flags[ current_rx_bd_index ][ `ETHDPI_RXBD_RD ] )
                  begin
                     reg [31:0] data;

                     /* $display( "%sInitiating DMA write for Rx Buffer Descriptor %d, address 0x%08X, frame data length is %d bytes.",
                               `ETHDPI_TRACE_PREFIX,
                               current_rx_bd_index,
                               buffer_descriptor_addresses[ current_rx_bd_index ],
                               received_frame_byte_count ); */

                     if ( received_frame_byte_count > { 16'h00, ethreg_packetlen[ `ETHDPI_PACKETLEN_MAXFL ] } )
                       begin
                          // The frame is too big, ignore it.
                          // This is an uncommon scenario, so generate an error. If you really need
                          // this behaviour, just comment this error out. You will probably have to
                          // set the "Too Long" (TL) bit too, see below.
                          $display( "%sThe frame received is too big to fit in the receiver buffer.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end
                     else if ( received_frame_byte_count < 6 )
                       begin
                          // The frame is too small, ignore it. We could receive small frames (see the RECSMALL flag),
                          // but this functionality has not been implemented yet. Besides, I don't think that
                          // the TAP interface would deliver such small frames.
                          // We need the first 6 bytes in order to filter by MAC address.
                          $display( "%sThe frame received is too small. I did not think that was possible with the TAP interface.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end
                     else
                       begin
                          byte mac_addr_0, mac_addr_1, mac_addr_2, mac_addr_3, mac_addr_4, mac_addr_5;
                          bit  is_broadcast, is_our_mac_addr, is_addr_match, should_receive;

                          get_received_frame_byte( 0, mac_addr_0 );
                          get_received_frame_byte( 1, mac_addr_1 );
                          get_received_frame_byte( 2, mac_addr_2 );
                          get_received_frame_byte( 3, mac_addr_3 );
                          get_received_frame_byte( 4, mac_addr_4 );
                          get_received_frame_byte( 5, mac_addr_5 );

                          is_broadcast    = 48'hFFFFFFFFFFFF == { mac_addr_0, mac_addr_1, mac_addr_2, mac_addr_3, mac_addr_4, mac_addr_5 };
                          is_our_mac_addr = ethreg_mac_addr == { mac_addr_0, mac_addr_1, mac_addr_2, mac_addr_3, mac_addr_4, mac_addr_5 };

                          is_addr_match   = is_our_mac_addr || ( is_broadcast && 0 == ( ethreg_moder & `ETHDPI_MODER_BRO ) );
                          should_receive  = is_addr_match || 0 != ( ethreg_moder & `ETHDPI_MODER_PRO );

                          /* $display( "Our MAC address: 0x%12X, received: 0x%12X, is_our_mac_addr: %d, is_broadcast: %d, is_addr_match: %d, should_receive: %d",
                                    ethreg_mac_addr,
                                    { mac_addr_0, mac_addr_1, mac_addr_2, mac_addr_3, mac_addr_4, mac_addr_5 },
                                    is_our_mac_addr,
                                    is_broadcast,
                                    is_addr_match,
                                    should_receive ); */

                          if ( ! should_receive )
                            begin
                               if ( 0 != ethernet_dpi_discard_received_frame( obj ) )
                                 begin
                                    $display( "%sError discarding the received frame in the DPI module.", `ETHDPI_ERROR_PREFIX );
                                    $finish;
                                 end;
                            end
                          else
                            begin
                               received_frame_mac_addr_miss_flag <= ! is_addr_match;

                               get_32_bits_worth_of_received_frame_data( 0, received_frame_byte_count, data );

                               m_wb_adr_o <= buffer_descriptor_addresses[ current_rx_bd_index ];
                               m_wb_we_o  <= 1;
                               m_wb_dat_o <= data;
                               start_wishbone_master_cycle;

                               current_dma_addr_offset <= 0;

                               current_state <= state_waiting_for_dma_write_to_complete;
                            end;
                       end;
                  end;
             end

           state_waiting_for_dma_read_to_complete:
             begin
                if ( m_wb_err_i )
                  begin
                     $display( "%sWishbone bus error reading ethernet data over DMA.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end
                else if ( m_wb_ack_i )
                  begin
                     // $display( "%sTx data received: 0x%08X", `ETHDPI_TRACE_PREFIX, m_wb_dat_i );
                     // This includes the bytes being read at this Wishbone cycle.
                     int byte_count_left = { 16'h0, buffer_descriptor_flags[ current_tx_bd_index ] [`ETHDPI_TXBD_LEN] } - current_dma_addr_offset;

                     if ( byte_count_left < 1 )
                       begin
                          $display( "%sInternal error calculating the DMA addresses.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( 0 != ethernet_dpi_add_byte_to_tx_frame( obj, m_wb_dat_i[ 31:24 ] ) )
                       begin
                          $display( "%sError appending to the DPI tx queue.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( byte_count_left >= 2 )  // In a separate if(), as Verilator does not support short-circuit expression evaluation yet (as of Dec 2011).
                       if ( 0 != ethernet_dpi_add_byte_to_tx_frame( obj, m_wb_dat_i[ 23:16 ] ) )
                       begin
                          $display( "%sError appending to the DPI tx queue.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( byte_count_left >= 3 )
                       if ( 0 != ethernet_dpi_add_byte_to_tx_frame( obj, m_wb_dat_i[ 15:8  ] ) )
                       begin
                          $display( "%sError appending to the DPI tx queue.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     if ( byte_count_left >= 4 )
                       if ( 0 != ethernet_dpi_add_byte_to_tx_frame( obj, m_wb_dat_i[  7:0  ] ) )
                       begin
                          $display( "%sError appending a byte to the tx Ethernet frame.", `ETHDPI_ERROR_PREFIX );
                          $finish;
                       end;

                     stop_wishbone_master_cycle;

                     if ( byte_count_left <= 4 )
                       begin
                          if ( 0 != ethernet_dpi_send_tx_frame( obj ) )
                            begin
                               $display( "%sError sending the DPI frame.", `ETHDPI_ERROR_PREFIX );
                               $finish;
                            end;

                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_RD  ] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_UR  ] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_RTRY] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_RL  ] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_LC  ] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_DF  ] <= 0;
                          buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_CS  ] <= 0;

                          if ( buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_IRQ] )
                            begin
                               // $display( "%sSetting the Tx interrupt source bit", `ETHDPI_TRACE_PREFIX );
                               ethreg_int[`ETHDPI_INT_TXB] <= 1;
                            end;

                          if ( buffer_descriptor_flags[ current_tx_bd_index ][`ETHDPI_TXBD_WR] )
                            current_tx_bd_index <= 0;
                          else if ( current_tx_bd_index == ethreg_tx_bd_num - 1 )
                            current_tx_bd_index <= 0;
                          else
                            current_tx_bd_index <= current_tx_bd_index + 1;

                          current_state <= state_idle;
                       end
                     else
                       begin
                          current_dma_addr_offset <= current_dma_addr_offset + 4;
                          current_state <= state_wait_state_between_dma_reads;
                       end
                  end
                else
                  begin
                     // Nothing to do here, just wait for the next time around.
                  end;
             end

           state_waiting_for_dma_write_to_complete:
             begin
                if ( m_wb_err_i )
                  begin
                     $display( "%sWishbone bus error writing ethernet data over DMA.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end
                else if ( m_wb_ack_i )
                  begin
                     reg [31:0] next_offset = current_dma_addr_offset + 4;

                     stop_wishbone_master_cycle;

                     // Have we written the last 32 bits? If so, we're done here with the Ethernet frame reception.
                     if ( next_offset >= received_frame_byte_count )
                       begin
                          if ( 0 != ethernet_dpi_discard_received_frame( obj ) )
                            begin
                               $display( "%sError discarding the received frame in the DPI module.", `ETHDPI_ERROR_PREFIX );
                               $finish;
                            end;

                          buffer_descriptor_flags[ current_rx_bd_index ][`ETHDPI_RXBD_RD ] <= 0;
                          buffer_descriptor_flags[ current_rx_bd_index ] &= `ETHDPI_RXBD_CLEAR_ERRORS_MASK;
                          buffer_descriptor_flags[ current_rx_bd_index ][`ETHDPI_RXBD_LEN] <= received_frame_byte_count[15:0];
                          buffer_descriptor_flags[ current_rx_bd_index ][`ETHDPI_RXBD_M  ] <= received_frame_mac_addr_miss_flag;

                          if ( buffer_descriptor_flags[ current_rx_bd_index ][`ETHDPI_RXBD_IRQ] )
                            begin
                               // $display( "%sSetting the Rx interrupt source bit", `ETHDPI_TRACE_PREFIX );
                               ethreg_int[`ETHDPI_INT_RXF] <= 1;
                            end;

                          if ( buffer_descriptor_flags[ current_rx_bd_index ][`ETHDPI_RXBD_WR] )
                            current_rx_bd_index <= ethreg_tx_bd_num;
                          else if ( current_rx_bd_index == buffer_descriptor_count )
                            current_rx_bd_index <= ethreg_tx_bd_num;
                          else
                            current_rx_bd_index <= current_rx_bd_index + 1;

                          current_state <= state_idle;
                       end
                     else
                       begin
                          current_dma_addr_offset <= next_offset;
                          current_state <= state_wait_state_between_dma_writes;
                       end
                  end
                else
                  begin
                     // Nothing to do here, just wait for the next time around.
                  end;
             end

           state_wait_state_between_dma_reads:
             begin
                // $display("%sInitiating next DMA read from address 0x%08X",
                //          `ETHDPI_TRACE_PREFIX,
                //          buffer_descriptor_addresses[ current_tx_bd_index ] + current_dma_addr_offset );

                m_wb_adr_o <= buffer_descriptor_addresses[ current_tx_bd_index ] + current_dma_addr_offset;
                m_wb_we_o  <= 0;
                m_wb_dat_o <= 0;
                start_wishbone_master_cycle;

                current_state <= state_waiting_for_dma_read_to_complete;
             end

           state_wait_state_between_dma_writes:
             begin
                reg [31:0] data;

                // $display( "%sInitiating next DMA write to address 0x%08X",
                //           `ETHDPI_TRACE_PREFIX,
                //           buffer_descriptor_addresses[ current_rx_bd_index ] + current_dma_addr_offset );

                get_32_bits_worth_of_received_frame_data( current_dma_addr_offset, received_frame_byte_count, data );

                m_wb_adr_o <= buffer_descriptor_addresses[ current_rx_bd_index ] + current_dma_addr_offset;
                m_wb_we_o  <= 1;
                m_wb_dat_o <= data;
                start_wishbone_master_cycle;

                current_state <= state_waiting_for_dma_write_to_complete;
             end

           default:
             begin
                $display( "%sDefault case for current_state=%d.", `ETHDPI_ERROR_PREFIX, current_state );
                $finish;
             end
           endcase;
      end
   endtask


   task automatic initial_reset;
      begin
         wb_dat_o = 0;
         wb_ack_o = 0;
         wb_err_o = 0;

         m_wb_cyc_o = 0;
         m_wb_stb_o = 0;
         m_wb_dat_o = 0;
         m_wb_we_o  = 0;
         m_wb_sel_o = 0;
         m_wb_adr_o = 0;

         int_o = 0;

         ethreg_moder      = `ETHDPI_MODER_CRCEN | `ETHDPI_MODER_PAD;
         ethreg_mac_addr   = 0;
         ethreg_tx_bd_num  = buffer_descriptor_count / 2;
         ethreg_int        = 0;
         ethreg_int_mask   = 0;
         ethreg_miiaddr    = 0;
         ethreg_miitx_data = 0;
         ethreg_ipgt       = `ETHDPI_DATA_WIDTH'h12;
         ethreg_ipgr1      = `ETHDPI_DATA_WIDTH'h0C;
         ethreg_ipgr2      = `ETHDPI_DATA_WIDTH'h12;
         ethreg_miimoder   = `ETHDPI_DATA_WIDTH'h64;  // Clock divider set to 0x64 (100), send no 32-bit preamble. Both ignored by this implementation.
         ethreg_tx_ctrl    = 0;
         ethreg_packetlen  = { 16'h0040, 16'h0600 };
         ethreg_collconf   = `ETHDPI_DATA_WIDTH'h000F003F;
         ethreg_miicommand = 0;
         ethreg_ctrlmoder  = 0;

         for ( integer i = 0; i < buffer_descriptor_count; i++ )
           begin
              buffer_descriptor_flags    [i] = 0;
              buffer_descriptor_addresses[i] = 0;
           end;

         current_state = state_idle;
         current_tx_bd_index = 0;
         current_rx_bd_index = ethreg_tx_bd_num;
         current_dma_addr_offset = 0;
         received_frame_mac_addr_miss_flag = 0;
      end
   endtask


   always @(posedge wb_clk_i)
   begin
      if ( wb_rst_i )
        begin
           // NOTE: If you modify the reset logic, please update the initial_reset task too.

           clear_wishbone_slave_outputs;
           stop_wishbone_master_cycle;

           int_o <= 0;

           ethreg_moder      <= `ETHDPI_MODER_CRCEN | `ETHDPI_MODER_PAD;
           ethreg_mac_addr   <= 0;
           ethreg_tx_bd_num  <= buffer_descriptor_count / 2;
           ethreg_int        <= 0;
           ethreg_int_mask   <= 0;
           ethreg_miiaddr    <= 0;
           ethreg_miitx_data <= 0;
           ethreg_ipgt       <= `ETHDPI_DATA_WIDTH'h12;
           ethreg_ipgr1      <= `ETHDPI_DATA_WIDTH'h0C;
           ethreg_ipgr2      <= `ETHDPI_DATA_WIDTH'h12;
           ethreg_miimoder   <= `ETHDPI_DATA_WIDTH'h64;  // Clock divider set to 0x64 (100), send no 32-bit preamble. Both ignored by this implementation.
           ethreg_tx_ctrl    <= 0;
           ethreg_packetlen  <= { 16'h0040, 16'h0600 };
           ethreg_collconf   <= `ETHDPI_DATA_WIDTH'h000F003F;
           ethreg_miicommand <= 0;
           ethreg_ctrlmoder  <= 0;

           for ( integer i = 0; i < buffer_descriptor_count; i++ )
             begin
                // Use = instead of <= , for Verilator (as of dic 2011) cannot use <= in loops that initialise arrays like this.
                buffer_descriptor_flags    [i] = 0;
                buffer_descriptor_addresses[i] = 0;
             end;

           current_state <= state_idle;
           current_tx_bd_index <= 0;
           current_rx_bd_index <= ethreg_tx_bd_num;
           current_dma_addr_offset <= 0;
           received_frame_mac_addr_miss_flag <= 0;
	    end
      else
        begin
           int received_frame_byte_count;
           bit ready_to_send;

           // Possible optimisation: we don't need to poll the TAP interface if we are currently sending
           // or receiving a frame.
           if ( 0 != ethernet_dpi_tick( obj, received_frame_byte_count, ready_to_send ) )
             begin
                $display( "%sError calling ethernet_dpi_tick().", `ETHDPI_ERROR_PREFIX );
                $finish;
             end;

           step_state_machine( received_frame_byte_count, ready_to_send );

           int_o <= ( 0 != ( ethreg_int & ethreg_int_mask ) );

           // Default values for the Wishbone slave output signals.
           clear_wishbone_slave_outputs;

           if ( wb_cyc_i &&
                wb_stb_i &&
                !wb_ack_o  // If we answered in the last cycle, finish the transaction in this one by clearing wb_ack_o.
              )
             begin
                wb_ack_o <= 1;  // We can always answer straight away, without delays.

                // I am not sure if we would ever see unaligned Wishbone addresses at this point.
                if ( 0 != ( wb_adr_i % 4 ) )
                  begin
                     $display( "%sThe client is trying to read from or write to an unaligned memory address over the Wishbone bus, but this Ethernet model implementation does not support unaligned Wishbone memory addresses.", `ETHDPI_ERROR_PREFIX );
                     $finish;
                  end;

                if ( wb_sel_i != `ETHDPI_EXPECTED_WB_SEL_VALUE )
                  begin
                     $display( "%sThe client is using an unexpected Wishbone wb_sel_i value of 0x%02X.", `ETHDPI_ERROR_PREFIX, wb_sel_i );
                     $finish;
                  end;

                if ( wb_we_i )
                  wishbone_write();
                else
                  wishbone_read();
             end;
        end;
   end;


   initial
     begin
        obj = 0;

        if ( 0 != ethernet_dpi_create( tap_interface_name,
                                       print_informational_messages,
                                       `ETHDPI_INFORMATION_PREFIX,
                                       obj ) )
          begin
             $display( "%sError creating the object instance.", `ETHDPI_ERROR_PREFIX );
             $finish;
          end;

        initial_reset;
     end

   final
     begin
        // This is optional, but can help find resource or memory leaks in other parts of the software.
        ethernet_dpi_destroy( obj );
     end

endmodule
