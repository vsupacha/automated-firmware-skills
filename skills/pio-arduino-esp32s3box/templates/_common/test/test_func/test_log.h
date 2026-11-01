/*******************************************************************************
* File Name : test_log.h
*
* Test log of the on-target unit tests: the results of the test driver's cases
* in one RAM record (fw_test_log), filled by the runner's setUp()/tearDown().
* After UNITY_END the runner prints test_log_line(), "TESTLOG: cases=..
* passed=.. failed=.. running=.. last_fail=..", before "UNIT-DONE";
* unity_read.py checks that it agrees with Unity's own results. A probe can
* read the same record without the console (symbol fw_test_log, magic "FWTL").
*
* Same layout as lib/test_rtt/test_log.h of automated-firmware-skills-rtthread
* (a copy, not shared code). Plain C: the PlatformIO skills copy this file and
* test_log.c into their test/test_func/ templates unchanged.
*******************************************************************************/
#ifndef TEST_LOG_H
#define TEST_LOG_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TEST_LOG_MAGIC   0x4C545746UL   /* "FWTL" little-endian */
#define TEST_LOG_VERSION 1UL
#define TEST_LOG_NAME    32U
#define TEST_LOG_RING    1024U

struct test_log_rec
{
    uint32_t magic;                    /* TEST_LOG_MAGIC once the first case started */
    uint32_t version;                  /* TEST_LOG_VERSION */
    uint32_t cases;                    /* cases finished since the last clear */
    uint32_t passed;
    uint32_t failed;
    uint32_t running;                  /* 1 while a case runs (a fault leaves it at 1) */
    char     current[TEST_LOG_NAME];   /* the case that runs, or ran last */
    char     last_fail[TEST_LOG_NAME]; /* "" = none */
    uint32_t head;                     /* next write position in ring (wraps) */
    uint32_t wrapped;                  /* 1 once ring was overwritten */
    char     ring[TEST_LOG_RING];      /* "PASS <case>\n" / "FAIL <case>\n" lines */
};

extern struct test_log_rec fw_test_log;

void test_log_clear(void);
void test_log_begin(const char *name);
void test_log_end(const char *name, bool pass);
/* "TESTLOG: cases=.. passed=.. failed=.. running=.. last_fail=<case|->" (no line end) */
const char *test_log_line(void);

#ifdef __cplusplus
}
#endif

#endif /* TEST_LOG_H */
