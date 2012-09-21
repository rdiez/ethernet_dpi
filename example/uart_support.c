
// UART support for the Ethernet client example.
//
// This example code has been tested with the OpenRISC MinSoC project,
// but should be easy to port to other platforms.
// It is designed to run without the standard C runtime library,
// so the usual printf() functions and the like are not available.
//
// You need a serial port interface (UART 16550) to run this example.
// Otherwise, you will need to comment out all routines that
// print progress messages and the like.

#include "uart_support.h"  // The include file for this module comes first.


// --------- These definitions depend on your platform ---------

#define IN_CLK         25000000  // 25 MHz, it does not matter for the UART DPI simulation.
#define UART_BAUD_RATE 115200    // Ignored by the UART DPI simulation.

// This is how your processor accesses the 8-bit UART registers mapped into its memory space.
#define REG8(addr) *((volatile unsigned char *)(addr))

// -------------------------------------------------------------

// -------- Definitions for the serial port interface --------

// UART registers.
#define UART_RX         0       // In:  Receive buffer (with DLAB=0)
#define UART_TX         0       // Out: Transmit buffer (with DLAB=0)
#define UART_DLL        0       // Out: Divisor Latch Low (with DLAB=1)
#define UART_DLM        1       // Out: Divisor Latch High (with DLAB=1)
#define UART_IER        1       // Out: Interrupt Enable Register
#define UART_IIR        2       // In:  Interrupt ID Register
#define UART_FCR        2       // Out: FIFO Control Register
#define UART_EFR        2       // I/O: Extended Features Register
                                // (DLAB=1, 16C660 only)
#define UART_LCR        3       // Out: Line Control Register
#define UART_MCR        4       // Out: Modem Control Register
#define UART_LSR        5       // In:  Line Status Register
#define UART_MSR        6       // In:  Modem Status Register
#define UART_SCR        7       // I/O: Scratch Register

// For the UART Line Status Register.
#define UART_LSR_TEMT 0x40  /* Transmitter empty */
#define UART_LSR_THRE 0x20  /* Transmit-hold-register empty */

// For the UART FIFO Control Register (16550 only)
#define UART_FCR_ENABLE_FIFO    0x01 /* Enable the FIFO */
#define UART_FCR_CLEAR_RCVR     0x02 /* Clear the RCVR FIFO */
#define UART_FCR_CLEAR_XMIT     0x04 /* Clear the XMIT FIFO */
#define UART_FCR_DMA_SELECT     0x08 /* For DMA applications */
#define UART_FCR_TRIGGER_MASK   0xC0 /* Mask for the FIFO trigger range */
#define UART_FCR_TRIGGER_1      0x00 /* Mask for trigger set at 1 */
#define UART_FCR_TRIGGER_4      0x40 /* Mask for trigger set at 4 */
#define UART_FCR_TRIGGER_8      0x80 /* Mask for trigger set at 8 */
#define UART_FCR_TRIGGER_14     0xC0 /* Mask for trigger set at 14 */

// For the UART Line Control Register
// Note: If the word length is 5 bits (UART_LCR_WLEN5), then setting 
//       UART_LCR_STOP will select 1.5 stop bits, not 2 stop bits.
#define UART_LCR_DLAB   0x80    /* Divisor latch access bit */
#define UART_LCR_SBC    0x40    /* Set break control */
#define UART_LCR_SPAR   0x20    /* Stick parity (?) */
#define UART_LCR_EPAR   0x10    /* Even parity select */
#define UART_LCR_PARITY 0x08    /* Parity Enable */
#define UART_LCR_STOP   0x04    /* Stop bits: 0=1 stop bit, 1= 2 stop bits */
#define UART_LCR_WLEN5  0x00    /* Wordlength: 5 bits */
#define UART_LCR_WLEN6  0x01    /* Wordlength: 6 bits */
#define UART_LCR_WLEN7  0x02    /* Wordlength: 7 bits */
#define UART_LCR_WLEN8  0x03    /* Wordlength: 8 bits */

#define EOL "\r\n"  // CR (0x0D), LF (0x0A).

// -------- Routines for the serial port interface --------

void init_uart ( const uint32_t uart_base_addr )
{
    // Initialise the FIFO.
    REG8(uart_base_addr + UART_FCR) = UART_FCR_ENABLE_FIFO |
                                      UART_FCR_CLEAR_RCVR  |
                                      UART_FCR_CLEAR_XMIT  |
                                      UART_FCR_TRIGGER_4;

    // Set 8 bit char, 1 stop bit, no parity (ignored by the UART DPI module).
    REG8(uart_base_addr + UART_LCR) = UART_LCR_WLEN8 & ~(UART_LCR_STOP | UART_LCR_PARITY);

    // Set baud rate (ignored by the UART DPI module).
    const int divisor = IN_CLK/(16 * UART_BAUD_RATE);
    REG8(uart_base_addr + UART_LCR) |= UART_LCR_DLAB;
    REG8(uart_base_addr + UART_DLM) = (divisor >> 8) & 0x000000ff;
    REG8(uart_base_addr + UART_DLL) = divisor & 0x000000ff;
    REG8(uart_base_addr + UART_LCR) &= ~(UART_LCR_DLAB);
}


static void wait_for_transmit ( const uint32_t uart_base_addr )
{
    unsigned char lsr;
    
    do
    {
        lsr = REG8(uart_base_addr + UART_LSR);
    }
    while ((lsr & UART_LSR_THRE) != UART_LSR_THRE);
}


void uart_print_char ( const uint32_t uart_base_addr, const char c )
{
    wait_for_transmit( uart_base_addr );
    REG8(uart_base_addr + UART_TX) = c;
}


void uart_print ( const uint32_t uart_base_addr, const char * p )
{
    while ( *p != 0 )
    {
        uart_print_char( uart_base_addr, *p );
        p++;
    }
}


void uart_print_unsigned ( const uint32_t uart_base_addr, const unsigned value )
{
    unsigned v = value;
    char buffer[80];
    char * ptr = buffer;
	
    do
    {
        const unsigned digit = v % 10;
        const char c = (char)( '0' + digit );

        *ptr = c;
        ++ptr;
        
        v /= 10;
    }
    while ( v != 0 );

    --ptr;
    
    while ( ptr >= buffer )
    {
        uart_print_char( uart_base_addr, *ptr );
        ptr--;
    }
}


void uart_print_hex ( const uint32_t uart_base_addr,
                      const unsigned long val,
                      const unsigned min_digits )
{
    // assert( min_digits >= 1 );
    
	int are_we_past_suppressed_leading_zeroes = 0;

	// uart_print( uart_base_addr, "0x" );
    
	int i;
	for ( i=0; i < sizeof( val ) * 2; ++i )
    {
		int c = (char) (val>>((7-i)*4)) & 0xf;
        
		if(c >= 0x0 && c<=0x9)
			c += '0';
		else
			c += 'a' - 10;
        
		if ((c != '0') || (i >= (sizeof( val ) * 2 - min_digits ) ))
			are_we_past_suppressed_leading_zeroes = 1;
        
		if ( are_we_past_suppressed_leading_zeroes )
			uart_print_char( uart_base_addr, c );
	}
}


void uart_print_int ( const uint32_t uart_base_addr, const int value )
{
    if ( value >= 0 )
    {
        uart_print_unsigned( uart_base_addr, (unsigned) value );
    }
    else
    {
        uart_print_char( uart_base_addr, '-' );
        uart_print_unsigned( uart_base_addr, (unsigned) -value );
    }
}

