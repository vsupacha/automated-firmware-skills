/*******************************************************************************
* File Name : test_func.c
*
* Host unit tests for the logic layer (lib/func or an app's func/), built by
* lib/host_test.sh against the fake board (board.h here). Each module's tests
* are compiled only when host_test.sh found that module (HOST_HAS_<MODULE>).
*
* Usage: test_func <capture-file>
*   stdout is redirected to <capture-file> so console output can be checked;
*   results go to stderr, last line "TESTS: <n> checks, <f> failed".
*******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "board.h"

#if defined(HOST_HAS_CONSOLE)
#include "console.h"
#endif
#if defined(HOST_HAS_LED)
#include "led.h"
#endif
#if defined(HOST_HAS_BUTTON)
#include "button.h"
#endif

static unsigned    checks;
static unsigned    failed;
static const char *group = "";
static const char *cap_path;
static char        cap_buf[8192];

#define CHECK(cond) check((cond) != 0, #cond, __LINE__)

static void check(int ok, const char *what, int line)
{
    checks++;
    if (!ok)
    {
        failed++;
        fprintf(stderr, "FAIL %s: %s (test_func.c:%d)\n", group, what, line);
    }
}

/* Console output capture: stdout goes to a file, read back after each step. */
static void cap_begin(void)
{
    fflush(stdout);
    if (freopen(cap_path, "w+b", stdout) == NULL)
    {
        fprintf(stderr, "ERROR: cannot redirect stdout to %s\n", cap_path);
        exit(1);
    }
}

static const char *cap_end(void)
{
    size_t n;

    fflush(stdout);
    rewind(stdout);
    n = fread(cap_buf, 1U, sizeof(cap_buf) - 1U, stdout);
    cap_buf[n] = '\0';
    return cap_buf;
}

static int contains(const char *hay, const char *needle)
{
    return strstr(hay, needle) != NULL;
}

/* ---------------------------------------------------------------- console */
#if defined(HOST_HAS_CONSOLE)

static int  last_argc;
static char last_argv[CONSOLE_ARGS_MAX][CONSOLE_LINE_MAX];
static int  calls;

static void cmd_record(int argc, char *argv[])
{
    calls++;
    last_argc = argc;
    for (int i = 0; (i < argc) && (i < (int)CONSOLE_ARGS_MAX); i++)
    {
        strncpy(last_argv[i], argv[i], CONSOLE_LINE_MAX - 1U);
        last_argv[i][CONSOLE_LINE_MAX - 1U] = '\0';
    }
    printf("OK %s\r\n", argv[0]);
}

static const console_cmd_t cmds[] =
{
    { "led",  "led <n> on|off",  cmd_record },
    { "info", "info",            cmd_record },
};

static const char *feed(const char *in)
{
    calls     = 0;
    last_argc = 0;
    memset(last_argv, 0, sizeof(last_argv));
    cap_begin();
    fake_console_input(in);
    console_poll();
    return cap_end();
}

static void test_console(void)
{
    const char *out;
    char        line[200];

    group = "console";
    fake_reset(0U, 0U);
    console_init(cmds, (uint32_t)(sizeof(cmds) / sizeof(cmds[0])));

    out = feed("led 1 on\r");
    CHECK(calls == 1);
    CHECK(last_argc == 3);
    CHECK(strcmp(last_argv[0], "led") == 0);
    CHECK(strcmp(last_argv[1], "1") == 0);
    CHECK(strcmp(last_argv[2], "on") == 0);
    CHECK(strcmp(out, "led 1 on\r\nOK led\r\n") == 0);         /* echo, CRLF, result */

    out = feed("info\r\n");                                     /* CRLF = one line */
    CHECK(calls == 1);

    out = feed("info\n");                                       /* LF alone ends a line */
    CHECK(calls == 1);

    out = feed("help\r");
    CHECK(calls == 0);
    CHECK(contains(out, "OK commands:\r\n  help\r\n  led <n> on|off\r\n  info\r\n"));

    out = feed("bogus x\r");
    CHECK(calls == 0);
    CHECK(contains(out, "ERR unknown command 'bogus' (try help)\r\n"));

    out = feed("\r\n\r");                                       /* empty lines: nothing */
    CHECK(calls == 0);
    CHECK(out[0] == '\0');

    out = feed("   \t \r");                                     /* blank line: echo only */
    CHECK(calls == 0);
    CHECK(!contains(out, "ERR"));

    out = feed("lex\bd 2  off\r");                              /* backspace, 2 spaces */
    CHECK(calls == 1);
    CHECK(strcmp(last_argv[0], "led") == 0);
    CHECK(strcmp(last_argv[1], "2") == 0);
    CHECK(strcmp(last_argv[2], "off") == 0);
    CHECK(contains(out, "\b \b"));

    out = feed("\x7f\b");                                       /* backspace on empty line */
    CHECK(out[0] == '\0');

    out = feed("in\x01\x1b" "fo\t\r");                          /* control chars dropped */
    CHECK(calls == 1);
    CHECK(strcmp(last_argv[0], "info") == 0);

    out = feed("led 1 2 3 4 5 6 7 8 9\r");                      /* extra args dropped */
    CHECK(calls == 1);
    CHECK(last_argc == (int)CONSOLE_ARGS_MAX);

    memset(line, 'a', sizeof(line) - 2U);                       /* overlong line truncated */
    line[sizeof(line) - 2U] = '\r';
    line[sizeof(line) - 1U] = '\0';
    out = feed(line);
    CHECK(calls == 0);
    CHECK(contains(out, "ERR unknown command '"));
    {
        const char *q = strstr(out, "ERR unknown command '");
        const char *a = (q != NULL) ? (q + strlen("ERR unknown command '")) : "";
        size_t      n = strspn(a, "a");
        CHECK(n == (CONSOLE_LINE_MAX - 1U));
    }

    out = feed("le");                                           /* line split over polls */
    CHECK(calls == 0);
    out = feed("d 3 on\r");
    CHECK(calls == 1);
    CHECK(strcmp(last_argv[1], "3") == 0);
}
#endif /* HOST_HAS_CONSOLE */

/* -------------------------------------------------------------------- led */
#if defined(HOST_HAS_LED)
static void test_led(void)
{
    group = "led";
    fake_reset(3U, 0U);
    fake_led_force(0U, true);
    fake_led_force(2U, true);

    led_init();
    CHECK(led_count() == 3U);
    CHECK(!fake_led_get(0U) && !fake_led_get(1U) && !fake_led_get(2U));   /* init = all off */

    CHECK(led_set(1U, true));
    CHECK(fake_led_get(0U));                                    /* 1-based: LED1 = index 0 */
    CHECK(led_get(1U));
    CHECK(!led_get(2U));

    CHECK(!led_set(0U, true));                                  /* out of range */
    CHECK(!led_set(4U, true));
    CHECK(!led_get(0U));
    CHECK(!led_get(4U));
    CHECK(!fake_led_get(3U));

    CHECK(led_toggle(2U));
    CHECK(fake_led_get(1U));
    CHECK(led_toggle(2U));
    CHECK(!fake_led_get(1U));
    CHECK(!led_toggle(9U));

    fake_led_force(2U, true);                                   /* get reads the board back */
    CHECK(led_get(3U));

    fake_reset(0U, 0U);                                         /* board without LEDs */
    led_init();
    CHECK(led_count() == 0U);
    CHECK(!led_set(1U, true));
    CHECK(fake_led_writes() == 0U);
}
#endif /* HOST_HAS_LED */

/* ----------------------------------------------------------------- button */
#if defined(HOST_HAS_BUTTON)
#define TICKS   (BUTTON_DEBOUNCE_MS / BUTTON_POLL_MS)

/* poll once per BUTTON_POLL_MS, n times; returns the first event (num in *num) */
static button_evt_t poll_n(uint32_t n, uint32_t *num)
{
    button_evt_t e = BUTTON_EVT_NONE;

    for (uint32_t i = 0U; (i < n) && (e == BUTTON_EVT_NONE); i++)
    {
        fake_advance_ms(BUTTON_POLL_MS);
        e = button_poll(num);
    }
    return e;
}

static void test_button(void)
{
    uint32_t num = 0U;

    group = "button";
    fake_reset(0U, 2U);
    button_init();
    CHECK(button_count() == 2U);
    CHECK(!button_is_pressed(1U));
    CHECK(!button_is_pressed(0U));
    CHECK(!button_is_pressed(3U));
    CHECK(poll_n(5U * TICKS, &num) == BUTTON_EVT_NONE);         /* idle: no events */

    fake_button_set(0U, true);                                  /* press: event after debounce */
    CHECK(poll_n(TICKS - 1U, &num) == BUTTON_EVT_NONE);
    CHECK(!button_is_pressed(1U));
    CHECK(poll_n(1U, &num) == BUTTON_EVT_PRESSED);
    CHECK(num == 1U);
    CHECK(button_is_pressed(1U));
    CHECK(poll_n(5U * TICKS, &num) == BUTTON_EVT_NONE);         /* held: one event only */

    fake_button_set(0U, false);                                 /* release */
    num = 0U;
    CHECK(poll_n(TICKS, &num) == BUTTON_EVT_RELEASED);
    CHECK(num == 1U);
    CHECK(!button_is_pressed(1U));

    fake_button_set(1U, true);                                  /* bounce restarts debounce */
    CHECK(poll_n(TICKS - 2U, &num) == BUTTON_EVT_NONE);
    fake_button_set(1U, false);
    CHECK(poll_n(1U, &num) == BUTTON_EVT_NONE);
    fake_button_set(1U, true);
    CHECK(poll_n(TICKS - 1U, &num) == BUTTON_EVT_NONE);
    CHECK(poll_n(1U, &num) == BUTTON_EVT_PRESSED);
    CHECK(num == 2U);
    fake_button_set(1U, false);
    CHECK(poll_n(TICKS, &num) == BUTTON_EVT_RELEASED);

    fake_button_set(0U, true);                                  /* both at once: two events */
    fake_button_set(1U, true);
    CHECK(poll_n(TICKS, &num) == BUTTON_EVT_PRESSED);
    CHECK(num == 1U);
    CHECK(poll_n(1U, &num) == BUTTON_EVT_PRESSED);
    CHECK(num == 2U);
    CHECK(button_is_pressed(1U) && button_is_pressed(2U));

    fake_reset(0U, 1U);                                         /* pressed at init: no event */
    fake_button_set(0U, true);
    button_init();
    CHECK(button_is_pressed(1U));
    CHECK(poll_n(3U * TICKS, &num) == BUTTON_EVT_NONE);

    fake_reset(0U, BOARD_MAX_BUTTONS + 2U);                     /* more than func can track */
    button_init();
    CHECK(button_count() == BOARD_MAX_BUTTONS);
    fake_button_set(BOARD_MAX_BUTTONS, true);                   /* the untracked one is ignored */
    CHECK(poll_n(2U * TICKS, &num) == BUTTON_EVT_NONE);
}
#endif /* HOST_HAS_BUTTON */

int main(int argc, char *argv[])
{
    if (argc < 2)
    {
        fprintf(stderr, "usage: test_func <capture-file>\n");
        return 2;
    }
    cap_path = argv[1];
    cap_begin();

#if defined(HOST_HAS_CONSOLE)
    test_console();
#endif
#if defined(HOST_HAS_LED)
    test_led();
#endif
#if defined(HOST_HAS_BUTTON)
    test_button();
#endif
    fflush(stdout);
    fprintf(stderr, "TESTS: %u checks, %u failed\n", checks, failed);
    return (failed == 0U) ? 0 : 1;
}
