/*
 * console.h - Layer 2: line console on the board's Stream (Arduino API).
 * Echoes characters, CR or LF ends a line, "help" lists the commands, unknown commands answer
 * "ERR unknown command". Protocol for tests: OK ... / ERR ... / EVT ... / <TAG> k=v ... / READY.
 * Print with console_out().print/println or console_printf() - println() ends lines with CR LF
 * (the Renesas core's Print has no printf).
 */
#ifndef CONSOLE_H
#define CONSOLE_H

#include <Arduino.h>

#define CONSOLE_LINE_MAX    64
#define CONSOLE_ARGS_MAX    8
#define CONSOLE_PRINTF_MAX  128

typedef void (*console_handler_t)(int argc, char *argv[]);

struct console_cmd_t
{
    const char        *name;
    const char        *usage;
    console_handler_t  fn;
};

void   console_init(const console_cmd_t *cmds, size_t count);
void   console_poll();          /* reads what is available, never blocks */
Print &console_out();           /* the console as an Arduino Print */
void   console_printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
                                /* formatted line part, up to CONSOLE_PRINTF_MAX - 1 chars */

#endif /* CONSOLE_H */
