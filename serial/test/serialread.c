#define SERIALTERMINAL      "/dev/ttyUSB0"
#include <errno.h>
#include <fcntl.h> 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

static struct termios orig_termios;  /* TERMinal I/O Structure */
static int ttyfd = STDIN_FILENO;     /* STDIN_FILENO is 0 by default */
int fd;

int set_interface_attribs(int fd, int speed, int canonical)
{
    struct termios tty;

    if (tcgetattr(fd, &tty) < 0) {
        printf("Error from tcgetattr: %s\n", strerror(errno));
        return -1;
    }

    if (canonical == 0) {
        cfmakeraw(&tty);
    }

    cfsetospeed(&tty, (speed_t)speed);
    cfsetispeed(&tty, (speed_t)speed);

    tty.c_cflag |= CLOCAL | CREAD;
    tty.c_cflag &= ~PARENB;     /* no parity bit */
    tty.c_cflag &= ~CSTOPB;     /* only need 1 stop bit */
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag &= ~CRTSCTS;    /* no hardware flowcontrol */
    tty.c_cflag |= CS8;         /* 8-bit characters */

    if (canonical == 1) {
        tty.c_lflag |= ICANON | ISIG;  /* canonical input */
    }
    tty.c_lflag &= ~(ECHO | ECHOE | ECHONL | IEXTEN);

    tty.c_iflag &= ~IGNCR;  /* preserve carriage return */
    tty.c_iflag &= ~INPCK;
    tty.c_iflag &= ~(INLCR | ICRNL | IUCLC | IMAXBEL);
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);   /* no SW flowcontrol */

    tty.c_oflag &= ~OPOST;

    tty.c_cc[VEOL] = 0;
    tty.c_cc[VEOL2] = 0;
    tty.c_cc[VEOF] = 0x04;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        printf("Error from tcsetattr: %s\n", strerror(errno));
        return -1;
    }
    return 0;
}

int main()
{
    char *portname = SERIALTERMINAL;
    int wlen;
    int rlen;
    unsigned char ibuf[64];
    unsigned char p;
    int plen;
    int fd;

    fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        printf("Error opening %s: %s\n", portname, strerror(errno));
        return -1;
    }
    /*baudrate 1200, 8 bits, no parity, 1 stop bit */
    set_interface_attribs(fd, B1200, 0);

    do {
               plen = read(fd, &p, 1);
               printf("Got byte.\n");
               if (plen > 0) {
                   /* first display as hex numbers then ASCII */
                   printf(" 0x%x", p);
                   if (p == 4) {
                       printf("\n\nBye bye.\n");
                       exit(0);
                   }
                   if (p >= ' ') {
                       printf("\n    \"%c\"\n\n", p);
		   } else {
                       printf("\n    \".\"\n\n");
		   } 
               } else if (plen < 0) {
                   printf("Error from read: %d: %s\n", plen, strerror(errno));
               } else {  /* plen == 0 */
                   printf("Nothing read. EOF?\n");
               }
	       if (p == 0x13) {
		   //printf("\n\n***** C64 XOFF ******\n\n");
		   do {
      	               plen = read(fd, &p, 1);
                       //printf("Got byte.\n");
                       if (plen > 0) {
                           /* first display as hex numbers then ASCII */
                           printf(" 0x%x", p);
                           if (p == 4) {
                               printf("\n\nBye bye.\n");
                               exit(0);
                           }
                           if (p >= ' ') {
                              printf("\n    \"%c\"\n\n", p);
			   } else if (p == 0x11) {
                              printf("\n\n***** C64 XON *****\n\n");
                           } else{
                              printf("\n    \".\"\n\n");
			   }
                       } else if (plen < 0) {
                           printf("Error from read: %d: %s\n", plen, strerror(errno));
                       } else {  /* plen == 0 */
                           printf("Nothing read. EOF?\n");
                       }
		   } while (p != 0x11); /* while (p != XON) */
	       } /* if (p == XOFF) */
    } while(1);
}
