
// UART support for the Ethernet client example.

#include <stdint.h>  // For uint32_t, alternative for 32-bit systems:  typedef unsigned uint32_t;

void init_uart ( uint32_t uart_base_addr );
void uart_print ( uint32_t uart_base_addr, const char * p );
void uart_print_char ( uint32_t uart_base_addr, char c );
void uart_print_hex ( uint32_t uart_base_addr, unsigned long val, unsigned min_digits );
void uart_print_unsigned ( uint32_t uart_base_addr, unsigned value );
void uart_print_int ( uint32_t uart_base_addr, int value );
