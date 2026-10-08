/*
 * console.cpp - Layer 2: line console (Arduino Stream API; the Stream comes from board.h).
 */
#include "console.h"

#include <stdarg.h>
#include <stdio.h>

#include "../board/board.h"

static Stream              *io;
static const console_cmd_t *table;
static size_t               table_len;
static char                 line[CONSOLE_LINE_MAX];
static size_t               len;

Print &console_out()
{
    return board_console();
}

void console_printf(const char *fmt, ...)
{
    char    buf[CONSOLE_PRINTF_MAX];
    va_list ap;

    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    board_console().print(buf);
}

static void print_help()
{
    io->println("OK commands:");
    io->println("  help");
    for (size_t i = 0; i < table_len; i++)
    {
        io->print("  ");
        io->println(table[i].usage);
    }
}

static void dispatch(char *buf)
{
    char *argv[CONSOLE_ARGS_MAX];
    int   argc = 0;
    char *save = NULL;
    char *tok  = strtok_r(buf, " \t", &save);

    while ((tok != NULL) && (argc < CONSOLE_ARGS_MAX))
    {
        argv[argc++] = tok;
        tok = strtok_r(NULL, " \t", &save);
    }
    if (argc == 0)
    {
        return;
    }
    if (strcmp(argv[0], "help") == 0)
    {
        print_help();
        return;
    }
    for (size_t i = 0; i < table_len; i++)
    {
        if (strcmp(argv[0], table[i].name) == 0)
        {
            table[i].fn(argc, argv);
            return;
        }
    }
    console_printf("ERR unknown command '%s' (try help)\r\n", argv[0]);
}

void console_init(const console_cmd_t *cmds, size_t count)
{
    io        = &board_console();
    table     = cmds;
    table_len = count;
    len       = 0;
}

void console_poll()
{
    while (io->available() > 0)
    {
        char c = (char)io->read();

        if ((c == '\r') || (c == '\n'))
        {
            if (len > 0)
            {
                io->println();
                line[len] = '\0';
                len = 0;
                dispatch(line);
            }
        }
        else if ((c == '\b') || (c == 0x7F))
        {
            if (len > 0)
            {
                len--;
                io->print("\b \b");
            }
        }
        else if ((len < (CONSOLE_LINE_MAX - 1)) && (c >= ' '))
        {
            line[len++] = c;
            io->write(c);
        }
    }
}
