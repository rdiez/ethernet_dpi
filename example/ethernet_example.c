
// Ethernet client example for the Ethernet DPI module.
//
// Version 0.86 beta, November 2011.
//
// This example code has been tested with the OpenRISC MinSoC project,
// but should be easy to port to other platforms.
// It is designed to run without the standard C runtime library,
// so the usual printf() functions and the like are not available.
//
// You need a serial port interface (UART 16550) to run this example.
// Otherwise, you will need to comment out all routines that
// print progress messages and the like.

#include <stdint.h>  // For uint32_t, alternative for 32-bit systems:  typedef unsigned uint32_t;
#include <stdlib.h>  // For NULL.

#include <int.h>  // For int_init() and int_add() from the MinSoC project, this is platform specific.

#include "uart_support.h"


#define EOL "\r\n"  // CR (0x0D), LF (0x0A).

// --------- These definitions depend on your platform ---------

#define ETH_IRQ 4

static const uint32_t UART1_BASE_ADDR = 0x90000000;
static const uint32_t ETH_BASE        = 0x92000000;

// This is how your processor accesses the 32-bit Ethernet Controller registers mapped into its memory space.
#define REG32(add) *((volatile unsigned long *)(add))

// -------------------------------------------------------------

#define ETH_MODER           0x00
#define ETH_INT_SOURCE      0x04
#define ETH_INT_MASK        0x08
#define ETH_IPGT            0x0C
#define ETH_IPGR1           0x10
#define ETH_IPGR2           0x14
#define ETH_PACKETLEN       0x18
#define ETH_COLLCONF        0x1C
#define ETH_TX_BD_NUM       0x20
#define ETH_CTRLMODER       0x24
#define ETH_MIIMODER        0x28
#define ETH_MIICOMMAND      0x2C
#define ETH_MIIADDRESS      0x30
#define ETH_MIITX_DATA      0x34
#define ETH_MIIRX_DATA      0x38
#define ETH_MIISTATUS       0x3C
#define ETH_MAC_ADDR0       0x40
#define ETH_MAC_ADDR1       0x44
#define ETH_HASH0_ADR       0x48
#define ETH_HASH1_ADR       0x4C
#define ETH_TXCTRL          0x50

#define ETH_BD_OFFSET       0x400

// Mode Register (MODER) bits.
#define ETH_RECSMAL         0x00010000
#define ETH_PAD             0x00008000
#define ETH_HUGEN           0x00004000
#define ETH_CRCEN           0x00002000
#define ETH_DLYCRCEN        0x00001000
#define ETH_FULLD           0x00000400
#define ETH_EXDFREN         0x00000200
#define ETH_NOBCKOF         0x00000100
#define ETH_LOOPBCK         0x00000080
#define ETH_IFG             0x00000040
#define ETH_PRO             0x00000020
#define ETH_IAM             0x00000010
#define ETH_BRO             0x00000008
#define ETH_NOPRE           0x00000004
#define ETH_TXEN            0x00000002
#define ETH_RXEN            0x00000001

// Interrupt Register bits.
#define ETH_RXC             0x00000040
#define ETH_TXC             0x00000020
#define ETH_BUSY            0x00000010
#define ETH_RXE             0x00000008
#define ETH_RXB             0x00000004
#define ETH_TXE             0x00000002
#define ETH_TXB             0x00000001

// MIISTATUS Register bits.
#define ETH_MIISTATUS_BUSY  0x00000002

// Buffer Descriptor bits.
#define ETH_RXBD_EMPTY      0x00008000
#define ETH_RXBD_IRQ        0x00004000
#define ETH_RXBD_WRAP       0x00002000
#define ETH_RXBD_CF         0x00000100
#define ETH_RXBD_MISS       0x00000080
#define ETH_RXBD_OR         0x00000040
#define ETH_RXBD_IS         0x00000020
#define ETH_RXBD_DN         0x00000010
#define ETH_RXBD_TL         0x00000008
#define ETH_RXBD_SF         0x00000004
#define ETH_RXBD_CRC        0x00000002
#define ETH_RXBD_LC         0x00000001

#define ETH_TXBD_READY      0x00008000
#define ETH_TXBD_IRQ        0x00004000
#define ETH_TXBD_WRAP       0x00002000
#define ETH_TXBD_PAD        0x00001000
#define ETH_TXBD_CRC        0x00000800
#define ETH_TXBD_UR         0x00000100
#define ETH_TXBD_RL         0x00000008
#define ETH_TXBD_LC         0x00000004
#define ETH_TXBD_DF         0x00000002
#define ETH_TXBD_CS         0x00000001

// The MAC address the user wants to use.
#define OWN_MAC_ADDRESS_5   0x01
#define OWN_MAC_ADDRESS_4   0x02
#define OWN_MAC_ADDRESS_3   0x03
#define OWN_MAC_ADDRESS_2   0x04
#define OWN_MAC_ADDRESS_1   0x05
#define OWN_MAC_ADDRESS_0   0x06

#define BROADCAST_ADDRESS_5 0xFF
#define BROADCAST_ADDRESS_4 0xFF
#define BROADCAST_ADDRESS_3 0xFF
#define BROADCAST_ADDRESS_2 0xFF
#define BROADCAST_ADDRESS_1 0xFF
#define BROADCAST_ADDRESS_0 0xFF

// The IP address the user wants to use.
#define OWN_IP_ADDRESS_0   192
#define OWN_IP_ADDRESS_1   168
#define OWN_IP_ADDRESS_2   254
#define OWN_IP_ADDRESS_3   1

#define MAC_ADDR_LEN 6
#define IP_ADDR_LEN  4

// The default maximum frame length in the Ethernet controller core is 1536.
#define MAX_FRAME_LEN 1536

static unsigned char eth_tx_packet[ MAX_FRAME_LEN ];
static unsigned char eth_rx_packet[ MAX_FRAME_LEN ];

#define BUFFER_DESCRIPTOR_COUNT 128
#define TX_BD_COUNT ( BUFFER_DESCRIPTOR_COUNT / 2 )

static uint8_t s_current_tx_bd_index;
static uint8_t s_current_rx_bd_index;

static uint32_t get_bd_status_addr ( const uint8_t tx_bd_index )
{
    return ETH_BASE + ETH_BD_OFFSET + tx_bd_index * 8;
}

static uint32_t get_bd_ptr_addr ( const uint8_t tx_bd_index )
{
    return ETH_BASE + ETH_BD_OFFSET + tx_bd_index * 8 + 4;
}

static void wait_until_miistatus_not_busy ( void )
{
    while( REG32( ETH_BASE + ETH_MIISTATUS ) & ETH_MIISTATUS_BUSY )
    {
    }
}


// This routine is for illustration and test purposes only, as the TAP interface will always
// report "link up".

void wait_until_link_is_up ( void )
{
    const uint32_t ETHDPI_MIICOMMAND_RSTAT = 1 << 1;  // Read Status.
    const uint32_t ETHDPI_MII_RSTAT_LINK_ESTABLISHED_MASK = 0x04;

    for ( ; ; )
    {
        REG32( ETH_BASE + ETH_MIIADDRESS ) = 1<<8;  // Value ignored by the DPI module.

        REG32( ETH_BASE + ETH_MIICOMMAND ) = ETHDPI_MIICOMMAND_RSTAT;
        wait_until_miistatus_not_busy();

        if ( REG32( ETH_BASE + ETH_MIIRX_DATA ) & ETHDPI_MII_RSTAT_LINK_ESTABLISHED_MASK )
            break;
    }
}


static void init_ethernet ( void )
{
    // Set the PHY Address to 0x01, this gets ignored anyway by the Ethernet DPI module.
    REG32(ETH_BASE + ETH_MIIADDRESS) = 0x00000001;

    // Enable the transmit and receive interrupts.
    REG32(ETH_BASE + ETH_INT_MASK) = ETH_RXB | ETH_TXB;

    // Set the MAC address.
    REG32(ETH_BASE + ETH_MAC_ADDR1) = (OWN_MAC_ADDRESS_5 << 8) |
                                       OWN_MAC_ADDRESS_4;
    REG32(ETH_BASE + ETH_MAC_ADDR0) = (OWN_MAC_ADDRESS_3 << 24) |
                                      (OWN_MAC_ADDRESS_2 << 16) |
                                      (OWN_MAC_ADDRESS_1 << 8) |
                                       OWN_MAC_ADDRESS_0;

    REG32(ETH_BASE + ETH_PACKETLEN) = ( 64 << 16 ) | MAX_FRAME_LEN;

    // Clear all interrupt source flags.
    REG32(ETH_BASE + ETH_INT_SOURCE) = ETH_RXC | ETH_TXC | ETH_BUSY | ETH_RXE | ETH_RXB | ETH_TXE | ETH_TXB;

    // Reset all buffer descriptors.
    REG32( ETH_BASE + ETH_TX_BD_NUM ) = TX_BD_COUNT;

    uint32_t i;
    for ( i = 0; i < BUFFER_DESCRIPTOR_COUNT; ++i )
    {
        REG32( get_bd_status_addr( i ) ) = 0;
    }

    s_current_tx_bd_index = 0;
    s_current_rx_bd_index = TX_BD_COUNT;

    wait_until_link_is_up();

    REG32(ETH_BASE + ETH_MODER) = ETH_TXEN | ETH_RXEN | ETH_PAD | ETH_CRCEN | ETH_FULLD;
}


static void start_ethernet_send ( const int length )
{
    REG32( get_bd_ptr_addr( s_current_tx_bd_index ) ) = (unsigned long) eth_tx_packet;

    uint16_t send_flags = ETH_TXBD_READY | ETH_TXBD_IRQ | ETH_TXBD_PAD | ETH_TXBD_CRC;

    if ( s_current_tx_bd_index == TX_BD_COUNT - 1 )
        send_flags += ETH_TXBD_WRAP;

    REG32( get_bd_status_addr( s_current_tx_bd_index ) ) = ( ( 0x0000FFFF & length ) << 16 ) | send_flags;
}


static void eth_interrupt ( void * const context )
{
    unsigned long source = REG32(ETH_BASE + ETH_INT_SOURCE);

    if ( source & ETH_TXB )
    {
        uart_print( UART1_BASE_ADDR, "Ethernet transmit interrupt received." EOL );
    }

    if ( source & ETH_RXB )
    {
        uart_print( UART1_BASE_ADDR, "Ethernet receive interrupt received." EOL );
    }

    if ( source & ~(ETH_RXB|ETH_TXB) )
    {
        uart_print( UART1_BASE_ADDR, "Unknown Ethernet interrupt received." EOL );
    }

    // Clear all received interrupts.
    REG32(ETH_BASE + ETH_INT_SOURCE) |= source;
}


static void print_mac_address ( const unsigned char * const addr )
{
    uart_print_hex( UART1_BASE_ADDR, addr[0], 2 );
    uart_print_char( UART1_BASE_ADDR, ':' );
    uart_print_hex( UART1_BASE_ADDR, addr[1], 2 );
    uart_print_char( UART1_BASE_ADDR, ':' );
    uart_print_hex( UART1_BASE_ADDR, addr[2], 2 );
    uart_print_char( UART1_BASE_ADDR, ':' );
    uart_print_hex( UART1_BASE_ADDR, addr[3], 2 );
    uart_print_char( UART1_BASE_ADDR, ':' );
    uart_print_hex( UART1_BASE_ADDR, addr[4], 2 );
    uart_print_char( UART1_BASE_ADDR, ':' );
    uart_print_hex( UART1_BASE_ADDR, addr[5], 2 );
}


static void print_ip_address ( const unsigned char * const addr )
{
    uart_print_unsigned( UART1_BASE_ADDR, addr[0] );
    uart_print_char( UART1_BASE_ADDR, '.' );
    uart_print_unsigned( UART1_BASE_ADDR, addr[1] );
    uart_print_char( UART1_BASE_ADDR, '.' );
    uart_print_unsigned( UART1_BASE_ADDR, addr[2] );
    uart_print_char( UART1_BASE_ADDR, '.' );
    uart_print_unsigned( UART1_BASE_ADDR, addr[3] );
}


static void copy_mac_address ( const unsigned char * const src,
                               unsigned char * const dest )
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
    dest[3] = src[3];
    dest[4] = src[4];
    dest[5] = src[5];
}


static void copy_ip_address ( const unsigned char * const src,
                              unsigned char * const dest )
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
    dest[3] = src[3];
}


static void write_own_mac_addr ( unsigned char * const dest )
{
    dest[ 0 ] = OWN_MAC_ADDRESS_5;
    dest[ 1 ] = OWN_MAC_ADDRESS_4;
    dest[ 2 ] = OWN_MAC_ADDRESS_3;
    dest[ 3 ] = OWN_MAC_ADDRESS_2;
    dest[ 4 ] = OWN_MAC_ADDRESS_1;
    dest[ 5 ] = OWN_MAC_ADDRESS_0;
}


static void write_broadcast_mac_addr ( unsigned char * const dest )
{
    dest[ 0 ] = BROADCAST_ADDRESS_5;
    dest[ 1 ] = BROADCAST_ADDRESS_4;
    dest[ 2 ] = BROADCAST_ADDRESS_3;
    dest[ 3 ] = BROADCAST_ADDRESS_2;
    dest[ 4 ] = BROADCAST_ADDRESS_1;
    dest[ 5 ] = BROADCAST_ADDRESS_0;
}


static void wait_until_frame_was_sent ( void )
{
    // Wait until the frame has been sent.
    for ( ; ; )
    {
        const uint32_t status = REG32( get_bd_status_addr( s_current_tx_bd_index ) );

        if ( 0 == ( status & ETH_TXBD_READY ) )
        {
            // uart_print( UART1_BASE_ADDR, "Tx ready now." EOL );

            if ( 0 != ( status & ( ETH_TXBD_UR |
                                   ETH_TXBD_RL |
                                   ETH_TXBD_LC |
                                   ETH_TXBD_DF |
                                   ETH_TXBD_CS ) ) )
            {
                uart_print( UART1_BASE_ADDR, "The Ethernet frame transmission failed." EOL );
            }

            break;
        }

        // uart_print( UART1_BASE_ADDR, "Tx not ready yet." EOL );
    }

    s_current_tx_bd_index = ( s_current_tx_bd_index + 1 ) % TX_BD_COUNT;
}


static int process_received_frame ( const int frame_len )
{
    // At the moment, we can only reply to a single ARP query for our MAC address.
    // Use a command like this to make this routine generate an answer:
    //   With Ubuntu's arping:
    //     arping -c 1 -f -w 10 -I dpi-tap1 192.168.254.1
    //   With Thomas Habets' arping:
    //     sudo ./arping -w 10000000 -c 1 -i dpi-tap1 192.168.254.1

    const int ARP_FRAME_LENGTH = 42;

    if ( frame_len < ARP_FRAME_LENGTH )
    {
        uart_print( UART1_BASE_ADDR, "The frame is too short to be the kind of ARP frame we are looking for." EOL );
        return 0;
    }

    int pos = 0;

    if ( eth_rx_packet[ pos + 0 ] != BROADCAST_ADDRESS_5 ||
         eth_rx_packet[ pos + 1 ] != BROADCAST_ADDRESS_4 ||
         eth_rx_packet[ pos + 2 ] != BROADCAST_ADDRESS_3 ||
         eth_rx_packet[ pos + 3 ] != BROADCAST_ADDRESS_2 ||
         eth_rx_packet[ pos + 4 ] != BROADCAST_ADDRESS_1 ||
         eth_rx_packet[ pos + 5 ] != BROADCAST_ADDRESS_0 )
    {
        uart_print( UART1_BASE_ADDR, "The target MAC address is not broadcast." EOL );
        return 0;
    }

    pos += MAC_ADDR_LEN;

    const int src_mac_addr_pos = pos;

    uart_print( UART1_BASE_ADDR, "Received broadcast frame from MAC address " );
    print_mac_address( &eth_rx_packet[ pos ] );
    uart_print( UART1_BASE_ADDR, EOL );

    pos += MAC_ADDR_LEN;

    const unsigned char ARP_PROTOCOL_HI = 0x08;
    const unsigned char ARP_PROTOCOL_LO = 0x06;
    if ( eth_rx_packet[ pos + 0 ] != ARP_PROTOCOL_HI ||
         eth_rx_packet[ pos + 1 ] != ARP_PROTOCOL_LO )
    {
        uart_print( UART1_BASE_ADDR, "The frame does not contain ARP protocol data." EOL );
        return 0;
    }

    pos += 2;

    const unsigned char ETHERNET_HARDWARE_TYPE_HI = 0x00;
    const unsigned char ETHERNET_HARDWARE_TYPE_LO = 0x01;

    if ( eth_rx_packet[ pos + 0 ] != ETHERNET_HARDWARE_TYPE_HI ||
         eth_rx_packet[ pos + 1 ] != ETHERNET_HARDWARE_TYPE_LO )
    {
        uart_print( UART1_BASE_ADDR, "The ARP frame does not contain the Ethernet hardware type." EOL );
        return 0;
    }

    pos += 2;

    const unsigned char IP_PROTOCOL_HI = 0x08;
    const unsigned char IP_PROTOCOL_LO = 0x00;

    if ( eth_rx_packet[ pos + 0 ] != IP_PROTOCOL_HI ||
         eth_rx_packet[ pos + 1 ] != IP_PROTOCOL_LO )
    {
        uart_print( UART1_BASE_ADDR, "The ARP frame is not about the IP protocol." EOL );
        return 0;
    }

    pos += 2;

    const unsigned char HARDWARE_SIZE = MAC_ADDR_LEN;

    if ( eth_rx_packet[ pos ] != HARDWARE_SIZE )
    {
        uart_print( UART1_BASE_ADDR, "The ARP frame has an invalid hardware size." EOL );
        return 0;
    }

    pos += 1;

    const unsigned char PROTOCOL_SIZE = IP_ADDR_LEN;

    if ( eth_rx_packet[ pos ] != PROTOCOL_SIZE )
    {
        uart_print( UART1_BASE_ADDR, "The ARP frame has an invalid protocol size." EOL );
        return 0;
    }

    pos += 1;

    const unsigned char OPCODE_REQUEST_HI = 0x00;
    const unsigned char OPCODE_REQUEST_LO = 0x01;
    const unsigned char OPCODE_REPLY_HI = 0x00;
    const unsigned char OPCODE_REPLY_LO = 0x02;

    if ( eth_rx_packet[ pos + 0 ] != OPCODE_REQUEST_HI ||
         eth_rx_packet[ pos + 1 ] != OPCODE_REQUEST_LO )
    {
        uart_print( UART1_BASE_ADDR, "The ARP frame is not an ARP request." EOL );
        return 0;
    }

    pos += 2;

    uart_print( UART1_BASE_ADDR, "The ARP sender MAC address is " );
    print_mac_address( &eth_rx_packet[ pos ] );
    uart_print( UART1_BASE_ADDR, EOL );

    pos += MAC_ADDR_LEN;

    const int src_ip_addr_pos = pos;

    uart_print( UART1_BASE_ADDR, "The ARP sender IP address is " );
    print_ip_address( &eth_rx_packet[ pos ] );
    uart_print( UART1_BASE_ADDR, EOL );

    pos += IP_ADDR_LEN;

    uart_print( UART1_BASE_ADDR, "The target MAC address is " );
    print_mac_address( &eth_rx_packet[ pos ] );
    uart_print( UART1_BASE_ADDR, EOL );

    // Linux uses 0x000000 here, but arping uses 0xFFFFFF.
    const int is_zero = eth_rx_packet[ pos + 0 ] == 0 &&
                        eth_rx_packet[ pos + 1 ] == 0 &&
                        eth_rx_packet[ pos + 2 ] == 0 &&
                        eth_rx_packet[ pos + 3 ] == 0 &&
                        eth_rx_packet[ pos + 4 ] == 0 &&
                        eth_rx_packet[ pos + 5 ] == 0;

    const int is_bcast   = eth_rx_packet[ pos + 0 ] == BROADCAST_ADDRESS_5 &&
                           eth_rx_packet[ pos + 1 ] == BROADCAST_ADDRESS_4 &&
                           eth_rx_packet[ pos + 2 ] == BROADCAST_ADDRESS_3 &&
                           eth_rx_packet[ pos + 3 ] == BROADCAST_ADDRESS_2 &&
                           eth_rx_packet[ pos + 4 ] == BROADCAST_ADDRESS_1 &&
                           eth_rx_packet[ pos + 5 ] == BROADCAST_ADDRESS_0;

    if ( !is_zero && !is_bcast  )
    {
        uart_print( UART1_BASE_ADDR, "The target MAC address is neither zero nor 0xFF." EOL );
        return 0;
    }

    pos += MAC_ADDR_LEN;

    uart_print( UART1_BASE_ADDR, "The target IP address is " );
    print_ip_address( &eth_rx_packet[ pos ] );
    uart_print( UART1_BASE_ADDR, EOL );

    if ( eth_rx_packet[ pos + 0 ] != OWN_IP_ADDRESS_0 ||
         eth_rx_packet[ pos + 1 ] != OWN_IP_ADDRESS_1 ||
         eth_rx_packet[ pos + 2 ] != OWN_IP_ADDRESS_2 ||
         eth_rx_packet[ pos + 3 ] != OWN_IP_ADDRESS_3 )
    {
        uart_print( UART1_BASE_ADDR, "The target IP address is not ours." EOL );
        return 0;
    }

    pos += IP_ADDR_LEN;

    if ( pos != ARP_FRAME_LENGTH )
    {
        uart_print( UART1_BASE_ADDR, "Internal error parsing the frame." EOL );
        return 0;
    }


    // Build the ARP reply.

    pos = 0;

    copy_mac_address( &eth_rx_packet[ src_mac_addr_pos ], &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    write_own_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    eth_tx_packet[ pos + 0 ] = ARP_PROTOCOL_HI;
    eth_tx_packet[ pos + 1 ] = ARP_PROTOCOL_LO;
    pos += 2;

    eth_tx_packet[ pos + 0 ] = ETHERNET_HARDWARE_TYPE_HI;
    eth_tx_packet[ pos + 1 ] = ETHERNET_HARDWARE_TYPE_LO;
    pos += 2;

    eth_tx_packet[ pos + 0 ] = IP_PROTOCOL_HI;
    eth_tx_packet[ pos + 1 ] = IP_PROTOCOL_LO;
    pos += 2;

    eth_tx_packet[ pos + 0 ] = HARDWARE_SIZE;
    pos += 1;

    eth_tx_packet[ pos + 0 ] = PROTOCOL_SIZE;
    pos += 1;

    eth_tx_packet[ pos + 0 ] = OPCODE_REPLY_HI;
    eth_tx_packet[ pos + 1 ] = OPCODE_REPLY_LO;
    pos += 2;

    write_own_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    eth_tx_packet[ pos + 0 ] = OWN_IP_ADDRESS_0;
    eth_tx_packet[ pos + 1 ] = OWN_IP_ADDRESS_1;
    eth_tx_packet[ pos + 2 ] = OWN_IP_ADDRESS_2;
    eth_tx_packet[ pos + 3 ] = OWN_IP_ADDRESS_3;
    pos += IP_ADDR_LEN;

    copy_mac_address( &eth_rx_packet[ src_mac_addr_pos ], &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    copy_ip_address( &eth_rx_packet[ src_ip_addr_pos ], &eth_tx_packet[ pos ] );
    pos += IP_ADDR_LEN;

    if ( pos != ARP_FRAME_LENGTH )
    {
        uart_print( UART1_BASE_ADDR, "Internal error building the ARP reply frame." EOL );
        return 0;
    }

    // After the ARP information, at the end of the Ethernet packet, comes the dummy CRC,
    // which should be 4 bytes with value 0xDEADF00D.

    uart_print( UART1_BASE_ADDR, "Sending the ARP reply..." EOL );

    start_ethernet_send( ARP_FRAME_LENGTH );
    wait_until_frame_was_sent();

    uart_print( UART1_BASE_ADDR, "Reply sent." EOL );

    return 1;
}


void register_read_test ( void )
{
    unsigned i;

    for ( i = 0; i <= ETH_TXCTRL; i += 4 )
    {
        uart_print( UART1_BASE_ADDR, "Ethernet register at address 0x");
        uart_print_hex( UART1_BASE_ADDR, i, 4 );
        uart_print( UART1_BASE_ADDR, ", value 0x" );
        uart_print_hex( UART1_BASE_ADDR, REG32( ETH_BASE + i ), 8 );
        uart_print( UART1_BASE_ADDR, "." EOL );
    }

    const uint32_t tx_bd_count = REG32( ETH_BASE + ETH_TX_BD_NUM );

    for ( i = 0; i < BUFFER_DESCRIPTOR_COUNT; ++i )
    {
        if ( i < tx_bd_count )
        {
            uart_print( UART1_BASE_ADDR, "Ethernet Tx Buffer Descriptor ");
        }
        else
        {
            uart_print( UART1_BASE_ADDR, "Ethernet Rx Buffer Descriptor ");
        }

        uart_print_unsigned( UART1_BASE_ADDR, i );

        uart_print( UART1_BASE_ADDR, ", flags 0x" );

        uart_print_hex( UART1_BASE_ADDR, REG32( get_bd_status_addr( i ) ), 8 );

        uart_print( UART1_BASE_ADDR, ", addr 0x" );

        uart_print_hex( UART1_BASE_ADDR, REG32( get_bd_ptr_addr( i ) ), 8 );

        uart_print( UART1_BASE_ADDR, "." EOL );
    }
}


int main ( void )
{
    int_init();  // This is specific for OpenRISC, you may need to call some other routine here
                 // in order to initialise interrupt support and so on.

    // We use a serial port console to display informational messages.
    init_uart( UART1_BASE_ADDR );

    uart_print( UART1_BASE_ADDR, "This is the Ethernet example program." EOL );

    init_ethernet();

    int_add( ETH_IRQ, &eth_interrupt, NULL );

    // Use an Ethernet sniffer like Wireshark in order to see the test frame sent.
    uart_print( UART1_BASE_ADDR, "Sending the first test frame (which has invalid protocol contents)..." EOL );

    int pos = 0;

    write_broadcast_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    write_own_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    eth_tx_packet[ pos + 0 ] = 0x10;
    eth_tx_packet[ pos + 1 ] = 0x20;
    eth_tx_packet[ pos + 2 ] = 0x30;
    eth_tx_packet[ pos + 3 ] = 0x40;
    eth_tx_packet[ pos + 4 ] = 0x50;
    eth_tx_packet[ pos + 5 ] = 0x60;
    pos += 6;

    int fill_to_end = 0;

    if ( fill_to_end )
    {
        while ( pos < MAX_FRAME_LEN )
        {
            eth_tx_packet[ pos ] = (unsigned char) pos;
            ++pos;
        }
    }

    start_ethernet_send( pos );
    wait_until_frame_was_sent();

    uart_print( UART1_BASE_ADDR, "Sending the second test frame (which has invalid protocol contents)..." EOL );

    pos = 0;

    write_broadcast_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    write_own_mac_addr( &eth_tx_packet[ pos ] );
    pos += MAC_ADDR_LEN;

    eth_tx_packet[ pos + 0 ] = 0x11;
    eth_tx_packet[ pos + 1 ] = 0x22;
    eth_tx_packet[ pos + 2 ] = 0x33;
    eth_tx_packet[ pos + 3 ] = 0x44;
    eth_tx_packet[ pos + 4 ] = 0x55;
    eth_tx_packet[ pos + 5 ] = 0x66;
    pos += 6;

    start_ethernet_send( pos );
    wait_until_frame_was_sent();

    const int dump_all_register_values = 0;
    if ( dump_all_register_values )
    {
        register_read_test();
    }


    // Main infinite loop.
    //
    // Wait for incoming frames, dump their contents and reply to a single type of ARP request.
    // See the README file for an example on how to generate the right type of APR request with arping.

    for ( ; ; )
    {
        uart_print( UART1_BASE_ADDR, "Waiting for a frame to be received..." EOL );

        REG32( get_bd_ptr_addr( s_current_rx_bd_index ) ) = (unsigned long) eth_rx_packet;

        uint32_t receive_flags = ETH_RXBD_EMPTY | ETH_RXBD_IRQ;

        if ( s_current_rx_bd_index == BUFFER_DESCRIPTOR_COUNT - 1 )
            receive_flags += ETH_RXBD_WRAP;

        REG32( get_bd_status_addr( s_current_rx_bd_index ) ) = receive_flags;

        uint32_t status;

        for ( ; ; )
        {
            status = REG32( get_bd_status_addr( s_current_rx_bd_index ) );

            if ( 0 == ( status & ETH_RXBD_EMPTY ) )
            {
                uart_print( UART1_BASE_ADDR, "Frame received." EOL );
                break;
            }
        }

        if ( status & ( ETH_RXBD_OR  |
                        ETH_RXBD_IS  |
                        ETH_RXBD_DN  |
                        ETH_RXBD_TL  |
                        ETH_RXBD_SF  |
                        ETH_RXBD_CRC |
                        ETH_RXBD_LC  ) )
        {
            uart_print( UART1_BASE_ADDR, "Error receiving frame, rx status is: " );
            uart_print_hex( UART1_BASE_ADDR, status, 8 );
            uart_print( UART1_BASE_ADDR,  EOL );
        }
        else
        {
            const int eth_rx_len = ( status >> 16 );

            const int should_dump_frame_contents = 0;

            if ( should_dump_frame_contents )
            {
                uart_print( UART1_BASE_ADDR, "Received length: " );

                uart_print_int( UART1_BASE_ADDR, eth_rx_len );
                uart_print( UART1_BASE_ADDR, EOL );
                uart_print( UART1_BASE_ADDR, "Frame data: " );

                int i;
                for ( i = 0; i < eth_rx_len; i++ )
                {
                    uart_print_hex( UART1_BASE_ADDR, eth_rx_packet[i], 2 );
                    uart_print( UART1_BASE_ADDR," " );
                }

                uart_print( UART1_BASE_ADDR, EOL "End of received data." EOL );
            }

            if ( ! process_received_frame( eth_rx_len ) )
            {
                uart_print( UART1_BASE_ADDR, "The received frame has been ignored." EOL );
            }
        }

        ++s_current_rx_bd_index;

        if ( s_current_rx_bd_index == BUFFER_DESCRIPTOR_COUNT )
            s_current_rx_bd_index = TX_BD_COUNT;
    }
}
