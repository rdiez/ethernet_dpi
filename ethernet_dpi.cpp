
/* Version 0.82 beta, September 2012.

   See the README file for information about this module.

   During development, use compiler flag -DDEBUG in order to enable assertions.
   
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

// NOTE: The Verilator-generated forward declarations of the DPI methods like ethernet_dpi_create()
//       must be visible to this file. If you are compiling this file as a standalone module,
//       you will have to include here the apropriate Verilator-generated header file.
//       Example:  #include "Vminsoc_bench_core__Dpi.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <stdarg.h>

#include <unistd.h>  // For close().
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/if_tun.h>
#include <arpa/inet.h>
#include <poll.h>

#include <stdexcept>


// We may have more error codes in the future, that's why the success value is zero.
// It would be best to return the error message as a string, but Verilog
// does not have good support for variable-length strings.
static const int RET_SUCCESS = 0;
static const int RET_FAILURE = 1;

static const char ERROR_MSG_PREFIX[] = "Error in the Ethernet DPI module: ";

// The default maximum frame length in the Ethernet controller core is 1536.
// The TAP interface has normally an MTU of 1500, which is the length
// of the payload only. However, I have tried to send more than 1500 bytes,
// namely 1600 bytes, to the TAP interface, and it does work (!), as of dec 2011.
// Sending 2000 bytes fails silently though, no error is returned from the write() call,
// and the frame is just dropped.
// I am not sure where the limit should be. I'll just add 36, so that we get 1536
// out of 1500, which should normally be OK.
static const char MTU_MARGIN = 36;


class ethernet_dpi
{
private:
  bool m_print_informational_messages;
  std::string m_informational_message_prefix;
  
  int m_tun_tap_clone_device;
  int m_socket;
  int m_mtu;

  char * m_send_buffer;
  char * m_receive_buffer;

  int m_received_byte_count;
  int m_send_byte_count;

public:
  ethernet_dpi ( const char * tap_interface_name,
                 unsigned char print_informational_messages,
                 const char * informational_message_prefix );
  ~ethernet_dpi ( void );

  void tick ( int * received_frame_byte_count,
              unsigned char * ready_to_send );
  
  void new_tx_frame ( void );
  void add_byte_to_tx_frame ( char data );
  void send_tx_frame ( void );

  void get_received_frame_byte ( int offset, char * data );
  void discard_received_frame ( void );
  void flush_tap_receive_buffer ( void );

private:
  void init ( const char * tap_interface_name,
              unsigned char print_informational_messages,
              const char * informational_message_prefix );
  void close_tap ( void );
  void close_socket ( void );
  void release_resources ( void );
  int receive_frame ( void );
};


static std::string format_msg_v ( const char * format_str, va_list arg_list )
{
    std::string ret;
  
    char * str;
    const int res = vasprintf( &str, format_str, arg_list ); 
    
    if ( -1 == res )
      throw std::bad_alloc();

    try
    {
      ret = str;
    }
    catch ( ... )
    {
      free( str );
      throw;
    }

    free( str );
    return ret;
}


static std::string format_msg ( const char * format_str, ... )
{
    va_list arg_list;
    va_start( arg_list, format_str );

    const std::string ret = format_msg_v( format_str, arg_list );

    va_end( arg_list );

    return ret;
}


static std::string format_error_message ( const int errno_val,
                                          const char * const prefix_msg_fmt,
                                          ... )
{
  va_list arg_list;
  va_start( arg_list, prefix_msg_fmt );

  const std::string prefix_msg = format_msg_v( prefix_msg_fmt, arg_list );
  
  va_end( arg_list );

  
  char buffer[ 2048 ];

  #if (_POSIX_C_SOURCE >= 200112L || _XOPEN_SOURCE >= 600) && ! _GNU_SOURCE
  #error "The call to strerror_r() below will not compile properly. The easiest thing to do is to define _GNU_SOURCE when compiling this module."
  #endif
  
  const char * const strerror_msg = strerror_r( errno_val, buffer, sizeof(buffer) );

  std::string sys_msg;
  
  if ( strerror_msg == NULL )
  {
    sys_msg = "<no error message available>";
  }
  else
  {
    // According to the strerror_r() documentation, if the string lands in the buffer,
    // it may be truncated, but it always includes a terminating null byte.
    
    sys_msg = strerror_msg;
  }

  const std::string ret = format_msg( "%sError code %d: %s",
                                      prefix_msg.c_str(),
                                      errno_val,
                                      sys_msg.c_str() );
  return ret;
}


static std::string ip_address_to_text ( const in_addr * const addr )
{
  char ip_addr_buffer[80];
  
  const char * const str = inet_ntop( AF_INET,
                                      addr,
                                      ip_addr_buffer,
                                      sizeof(ip_addr_buffer) );
  if ( str == NULL )
  {
    throw std::runtime_error( format_error_message( errno, "Error formatting the IP address: " ) );
  }

  assert( strlen(str) <= strlen("123.123.123.123") );
  assert( strlen(str) <= sizeof(ip_addr_buffer) );

  return str;
}


static void close_a ( const int fd )
{
  for ( ; ; )
  {
    const int res = close( fd );

    if ( res == -1 && errno == EINTR )
        continue;

    assert( res == 0 );
    
    break;
  }
}


ethernet_dpi::ethernet_dpi ( const char * const tap_interface_name,
                             const unsigned char print_informational_messages,
                             const char * const informational_message_prefix )
 : m_tun_tap_clone_device( -1 )
 , m_socket( -1 )
 , m_send_buffer( NULL )
 , m_receive_buffer( NULL )
 , m_received_byte_count( 0 )
 , m_send_byte_count( 0 )
{
  try
  {
    init( tap_interface_name,
          print_informational_messages,
          informational_message_prefix );
  }
  catch ( ... )
  {
    release_resources();
    throw;
  }
}


ethernet_dpi::~ethernet_dpi ( void )
{
  release_resources();
}


void ethernet_dpi::release_resources ( void )
{
  if ( m_tun_tap_clone_device != -1 )
    close_tap();

  if ( m_socket != -1 )
    close_socket();
  
  free( m_send_buffer );
  m_send_buffer = NULL;

  free( m_receive_buffer );
  m_receive_buffer = NULL;
}


void ethernet_dpi::init ( const char * const tap_interface_name,
                          const unsigned char print_informational_messages,
                          const char * const informational_message_prefix )
{
  if ( tap_interface_name == NULL ||
       tap_interface_name[0] == 0 ||
       strlen(tap_interface_name) >= IFNAMSIZ )
  {
    throw std::runtime_error( "Invalid tap_interface_name parameter." );
  }
  
  switch ( print_informational_messages )
  {
  case 0:
    m_print_informational_messages = false;
    break;
      
  case 1:
    m_print_informational_messages = true;
    break;

  default:
    throw std::runtime_error( "Invalid print_informational_messages parameter." );
  }

  m_informational_message_prefix = informational_message_prefix ? informational_message_prefix : "";

  const char tun_tap_clone_device_name[] = "/dev/net/tun";

  m_tun_tap_clone_device = open( tun_tap_clone_device_name, O_RDWR );

  if ( m_tun_tap_clone_device == -1 )
  {
    throw std::runtime_error( format_error_message( errno,
                                                    "Error opening TUN/TAP clone device \"%s\": ",
                                                    tun_tap_clone_device_name ) );
  }

  // If the TAP device exists, attempt to open it. This should succeed if the
  // parameters match the ones used at creation time and the user is the owner.
  // If the TAP device does not exist, attempt to create it. The user must be root
  // or at least have the CAP_NET_ADMIN capability.
  // Unfortunately, there does not seem to be a way to open the TAP interface only if
  // it already exists, and not to attempt to create it if it does not.

  ifreq ifr_setiff;
  memset( &ifr_setiff, 0, sizeof(ifr_setiff) );
  ifr_setiff.ifr_flags = IFF_TAP |  // Raw ethernet, the alternative would be TUN.
                         IFF_NO_PI; // No Packet Information (no extra header with procotol ID and flags)
  strncpy( ifr_setiff.ifr_name, tap_interface_name, IFNAMSIZ );

  if ( ioctl( m_tun_tap_clone_device, TUNSETIFF, (void *) &ifr_setiff ) == -1 )
  {
    throw std::runtime_error( format_error_message( errno,
                                                    "Error opening/creating TAP interface \"%s\": ",
                                                    tap_interface_name ) );
  }
    
  // Create a socket. We need one in order to retrieve some information from a network interface.
  m_socket = socket( AF_INET, SOCK_DGRAM, 0 );
  
  if ( m_socket == -1 )
  {
    throw std::runtime_error( format_error_message( errno,
                                                    "Error creating a socket: ") );
  }


  // Get the IP address of the TAP interface.
  ifreq ifr_getipaddr;
  memset( &ifr_getipaddr, 0, sizeof(ifr_getipaddr) );
  strncpy( ifr_getipaddr.ifr_name, tap_interface_name, IFNAMSIZ );
  if ( ioctl( m_socket, SIOCGIFADDR, (void *)&ifr_getipaddr ) == -1 )
  {
    throw std::runtime_error( format_error_message( errno,
                                                    "Error getting the IP address of TAP interface \"%s\": ",
                                                    tap_interface_name ) );
  }

  // Get the MTU of the TAP interface.
  ifreq ifr_getmtu;
  memset( &ifr_getmtu, 0, sizeof(ifr_getmtu) );
  strncpy( ifr_getmtu.ifr_name, tap_interface_name, IFNAMSIZ );

  if ( ioctl( m_socket, SIOCGIFMTU, (void *) &ifr_getmtu ) == -1 )
  {
    throw std::runtime_error( format_error_message( errno,
                                                    "Error getting the MTU for TAP interface \"%s\": ",
                                                    tap_interface_name ) );
  }

  m_mtu = ifr_getmtu.ifr_mtu;

  close_socket();  // We don't really need the socket any more.
  
  if ( m_print_informational_messages )
  {
    printf( "%sUsing TAP interface \"%s\", IP addr: %s, MTU: %d.\n",
            m_informational_message_prefix.c_str(),
            tap_interface_name,
            ip_address_to_text( &((const sockaddr_in *)&ifr_getipaddr.ifr_addr)->sin_addr ).c_str(),
            m_mtu );
    fflush( stdout );
  }

  const size_t buffer_size = m_mtu + MTU_MARGIN + 1;  // We read one byte more than the MTU in order to know if the frame is longer than the maximum allowed.
  
  m_send_buffer    = (char *) malloc( buffer_size );
  m_receive_buffer = (char *) malloc( buffer_size );

  if ( m_send_buffer == NULL || m_receive_buffer == NULL )
    throw std::bad_alloc();

  
  // Notes about the TAP interface's receive buffer.
  //
  // From empiric evidence under Ubuntu 10.04, it looks like a persistent TAP interface drops
  // all incoming packets if no-one holds a file handle to it.
  // I used Thomas Habets's 'arping' tool in order to overload the receive buffer between the
  // open() and recv() calls, and I eventually got this error message:
  //    arping: libnet_write(): libnet_write_link(): only -1 bytes written (No buffer space available)
  //    202 packets transmitted, 0 packets received, 100% unanswered (0 extra)
  // I then repeatedly called recv() and got 201 packets with 42 bytes each, that is a little over 8 KB's
  // worth of data.
  // Afterwards, I tested the following scenario:
  //  - open(TAP interface)
  //  - overflow the buffer with arping
  //  - kill the process
  //  - open(TAP interface)
  //  - recv all packets
  // The receive buffer still delivered 100 stale packets. It looks like the receive buffer is not cleared
  // when the last handle is closed on the TAP interface.
  //
  // Therefore, I think it's good idea to flush the receive buffer at this point.

  flush_tap_receive_buffer();
}


void ethernet_dpi::flush_tap_receive_buffer ( void )
{
  for ( ; ; )
  {
    const int received_byte_count = receive_frame();

    if ( received_byte_count == 0 )
      break;

    if ( false )  // Flush silently.
    {
      if ( m_print_informational_messages )
      {
        printf( "%sDiscarding stale frame with %d bytes.\n",
                m_informational_message_prefix.c_str(),
                received_byte_count );
        fflush( stdout );
      }
    }
  }

  m_received_byte_count = 0;
}


void ethernet_dpi::add_byte_to_tx_frame ( const char data )
{
  if ( m_send_byte_count >= m_mtu + MTU_MARGIN )
    throw std::runtime_error( format_msg( "The frame size exceeds the MTU limit of %d.", m_mtu ) );

  const bool dump_tx_byte = false;

  if ( dump_tx_byte )
    printf( "Adding tx byte: 0x%02X\n", (unsigned char)data );
  
  m_send_buffer[ m_send_byte_count ] = data;
  
  ++m_send_byte_count;
}


void ethernet_dpi::new_tx_frame ( void )
{
  m_send_byte_count = 0;
}


void ethernet_dpi::send_tx_frame ( void )
{
  if ( m_send_byte_count <= 0 )
      throw std::runtime_error( "The frame size exceeds the MTU." );

  const bool dump_tx_frame = false;
  if ( dump_tx_frame )
  {
    printf( "Sending frame of %d bytes, data:\n", m_send_byte_count );
    for ( int i = 0; i < m_send_byte_count; ++i )
      printf( "%02X ", (unsigned char)m_send_buffer[i] );
    printf( "\n" );
  }

  for ( ; ; )  // Repeat if EINTR.
  {
    const ssize_t sent_byte_count = write( m_tun_tap_clone_device,
                                           m_send_buffer,
                                           m_send_byte_count );
    if ( sent_byte_count == 0 )
    {
      throw std::runtime_error( "Cannot write data to the TAP interface." );
    }
    
    if ( sent_byte_count == -1 )
    {
      const int errno_value = errno;

      if ( errno_value == EINTR )
        continue;
      
      throw std::runtime_error( format_error_message( errno, "Error writing data to the TAP interface: " ) );
    }

    if ( sent_byte_count != m_send_byte_count )
    {
      throw std::runtime_error( "Error writing data to the TAP interface, only part of the ethernet frame could be written." );
    }

    break;
  }
}


void ethernet_dpi::close_tap ( void )
{
  assert( m_tun_tap_clone_device != -1 );
  
  close_a( m_tun_tap_clone_device );
  
  m_tun_tap_clone_device = -1;
}


void ethernet_dpi::close_socket ( void )
{
  assert( m_socket != -1 );
  
  close_a( m_socket );
  
  m_socket = -1;
}


// Returns the frame length, or zero if the receive queue is empty.

int ethernet_dpi::receive_frame ( void )
{
  for ( ; ; )  // Repeat if EINTR.
  {
    pollfd polled_fd;

    polled_fd.fd      = m_tun_tap_clone_device;
    polled_fd.events  = POLLIN;
    polled_fd.revents = 0;

    const int poll_res = poll( &polled_fd, 1, 0 );

    if ( poll_res == -1 )
    {
      if ( errno == EINTR )
        continue;
      
      throw std::runtime_error( format_error_message( errno, "Error polling the TAP interface to receive: " ) );
    }

    if ( poll_res == 0 )
      return 0;

    assert( poll_res == 1 );
    
    break;
  }

  for ( ; ; )  // Repeat if EINTR.
  {
    const ssize_t received_byte_count = read( m_tun_tap_clone_device,
                                              m_receive_buffer,
                                              m_mtu + MTU_MARGIN + 1 );
    if ( received_byte_count == 0 )
    {
      throw std::runtime_error( "Cannot read data from the TAP interface." );
    }
    
    if ( received_byte_count == -1 )
    {
      const int errno_value = errno;

      if ( errno_value == EINTR )
        continue;
      
      if ( errno_value == EAGAIN || errno_value == EWOULDBLOCK )
      {
        // No data available yet. This shouldn't happen, as we have called poll() before,
        // and we are not actually reading from a socket which might be in non-blocking mode.
        assert( false );
        return 0;
      }

      throw std::runtime_error( format_error_message( errno, "Error reading data from the TAP interface: " ) );
    }

    if ( false )
    {
      printf( "Received byte count: %u\n", unsigned(received_byte_count) );
      fflush( stdout );
    }
    
    if ( received_byte_count > ssize_t( m_mtu + MTU_MARGIN ) )
    {
      throw std::runtime_error( "Error reading data from the TAP interface, the received packet is bigger than the MTU." );
    }

    return (int) received_byte_count;
  }
}


void ethernet_dpi::tick ( int * const received_frame_byte_count,
                          unsigned char * const ready_to_send )
{
  if ( m_received_byte_count == 0 )
  {
    m_received_byte_count = receive_frame();
  }

  *received_frame_byte_count = m_received_byte_count;

  
  // Possible optimisation: if the TAP interface was ready to send the last time,
  // and we have not sent or received anything, then it should still be ready to send,
  // there is no need to poll.
  
  for ( ; ; )  // Repeat if EINTR.
  {
    pollfd polled_fd;

    polled_fd.fd      = m_tun_tap_clone_device;
    polled_fd.events  = POLLOUT | POLLERR;
    polled_fd.revents = 0;

    const int poll_res = poll( &polled_fd, 1, 0 );

    if ( poll_res == -1 )
    {
      if ( errno == EINTR )
        continue;
      
      throw std::runtime_error( format_error_message( errno, "Error polling the TAP interface to send: " ) );
    }

    if ( poll_res == 0 )
    {
      *ready_to_send = 0;
      break;
    }

    assert( poll_res == 1 );
    *ready_to_send = 1;
    break;
  }
}


void ethernet_dpi::get_received_frame_byte ( const int offset, char * const data )
{
  if ( offset < 0 || offset >= m_received_byte_count )
      throw std::runtime_error( "The received frame byte offset is out of range." );

  *data = m_receive_buffer[ offset ];
}


void ethernet_dpi::discard_received_frame ( void )
{
  m_received_byte_count = 0;
}


// ---------------------------- DPI interface ----------------------------

int ethernet_dpi_create ( const char * const tap_interface_name,
                          const unsigned char print_informational_messages,
                          const char * const informational_message_prefix,
                          long long * const obj )
{
  *obj = 0;  // In case of error, return the equivalent of NULL.
             // Otherwise, the 'final' Verilog section must check whether ethernet_dpi_create() failed before calling ethernet_dpi_destroy().
  
  ethernet_dpi * this_obj = NULL;
  
  try
  {
    this_obj = new ethernet_dpi( tap_interface_name,
                                 print_informational_messages,
                                 informational_message_prefix );
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    delete this_obj;
    
    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    delete this_obj;
    
    return RET_FAILURE;
  }

  assert( sizeof(*obj) >= sizeof(this_obj) );
  *obj = (long long)this_obj;
  return RET_SUCCESS;
}


void ethernet_dpi_destroy ( const long long obj )
{
  const ethernet_dpi * const this_obj = (const ethernet_dpi *)obj;
  
  delete this_obj;
}


int ethernet_dpi_tick ( const long long obj,
                        int * const received_frame_byte_count,
                        unsigned char * const ready_to_send )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );
    
    this_obj->tick( received_frame_byte_count, ready_to_send );
    
    return RET_SUCCESS;
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }
}


int ethernet_dpi_flush_tap_receive_buffer ( const long long obj )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );
    
    this_obj->flush_tap_receive_buffer();
    
    return RET_SUCCESS;
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }
}


int ethernet_dpi_add_byte_to_tx_frame ( const long long obj, const char data )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );
    
    this_obj->add_byte_to_tx_frame( data );
    
    return RET_SUCCESS;
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }
}


int ethernet_dpi_new_tx_frame ( const long long obj )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );
    
    this_obj->new_tx_frame();
    
    return RET_SUCCESS;
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }
}


int ethernet_dpi_send_tx_frame ( const long long obj )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );
    
    this_obj->send_tx_frame();
    
    return RET_SUCCESS;
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }
}


int ethernet_dpi_get_received_frame_byte ( const long long obj,
                                           const int offset,
                                           char * const data )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );

    this_obj->get_received_frame_byte( offset, data );
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }

  return RET_SUCCESS;
}


int ethernet_dpi_discard_received_frame ( const long long obj )
{
  try
  {
    ethernet_dpi * const this_obj = (ethernet_dpi *)obj;

    if ( this_obj == NULL )
      throw std::runtime_error( "Invalid obj parameter." );

    this_obj->discard_received_frame();
  }
  catch ( const std::exception & e )
  {
    // We should return this error string to the caller,
    // but Verilog does not have good support for variable-length strings.
    fprintf( stderr, "%s%s\n", ERROR_MSG_PREFIX, e.what() );
    fflush( stderr );

    return RET_FAILURE;
  }
  catch ( ... )
  {
    fprintf( stderr, "%sUnexpected C++ exception.\n", ERROR_MSG_PREFIX );
    fflush( stderr );

    return RET_FAILURE;
  }

  return RET_SUCCESS;
}

