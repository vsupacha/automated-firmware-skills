/*******************************************************************************
* File Name : test_log.c
*
* Test log record of the on-target unit tests (see test_log.h). Records only;
* the runner prints test_log_line() on its console.
*******************************************************************************/
#include "test_log.h"

#include <stdio.h>
#include <string.h>

struct test_log_rec fw_test_log;

static void copy_name(char *dst, const char *src)
{
    strncpy(dst, (src != NULL) ? src : "", TEST_LOG_NAME - 1U);
    dst[TEST_LOG_NAME - 1U] = '\0';
}

static void ring_put(const char *text)
{
    for (const char *p = text; *p != '\0'; p++)
    {
        fw_test_log.ring[fw_test_log.head] = *p;
        fw_test_log.head++;
        if (fw_test_log.head >= TEST_LOG_RING)
        {
            fw_test_log.head    = 0U;
            fw_test_log.wrapped = 1U;
        }
    }
}

void test_log_clear(void)
{
    memset(&fw_test_log, 0, sizeof(fw_test_log));
    fw_test_log.magic   = TEST_LOG_MAGIC;
    fw_test_log.version = TEST_LOG_VERSION;
}

void test_log_begin(const char *name)
{
    if (fw_test_log.magic != TEST_LOG_MAGIC)
    {
        test_log_clear();
    }
    copy_name(fw_test_log.current, name);
    fw_test_log.running = 1U;
}

void test_log_end(const char *name, bool pass)
{
    fw_test_log.cases++;
    if (pass)
    {
        fw_test_log.passed++;
    }
    else
    {
        fw_test_log.failed++;
        copy_name(fw_test_log.last_fail, name);
    }
    fw_test_log.running = 0U;
    ring_put(pass ? "PASS " : "FAIL ");
    ring_put((name != NULL) ? name : "");
    ring_put("\n");
}

const char *test_log_line(void)
{
    static char line[64U + TEST_LOG_NAME];

    (void)snprintf(line, sizeof(line), "TESTLOG: cases=%lu passed=%lu failed=%lu running=%lu last_fail=%s",
                   (unsigned long)fw_test_log.cases, (unsigned long)fw_test_log.passed,
                   (unsigned long)fw_test_log.failed, (unsigned long)fw_test_log.running,
                   (fw_test_log.last_fail[0] != '\0') ? fw_test_log.last_fail : "-");
    return line;
}
