/*
 * console.h - Layer 2: line console over the board console (USB CDC).
 * Echoes characters, CR or LF ends a line, "help" lists the commands, unknown commands answer
 * "ERR unknown command". Protocol for tests: OK ... / ERR ... / EVT ... / <TAG> k=v ... / READY.
 */
#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdint.h>

#define CONSOLE_LINE_MAX    64U
#define CONSOLE_ARGS_MAX    8U

typedef void (*console_handler_t)(int argc, char *argv[]);

typedef struct
{
    const char        *name;
    const char        *usage;
    console_handler_t  fn;
} console_cmd_t;

void console_init(const console_cmd_t *cmds, uint32_t count);
void console_poll(void);
/* printf to the console; lines end with "\r\n" */
void console_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

#endif /* CONSOLE_H */
