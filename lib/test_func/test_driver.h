/*******************************************************************************
* File Name : test_driver.h
*
* Shared by the on-target unit-test runner (test_driver_main.c) and the suites
* (test_*.c, the test driver cases). Unity's setUp()/tearDown() are global, so
* the runner owns them and calls the hooks the running suite set: a suite
* starts with
*     test_driver_setup = my_setup; test_driver_teardown = NULL;
* before its RUN_TEST() lines.
*******************************************************************************/
#ifndef TEST_DRIVER_H
#define TEST_DRIVER_H

extern void (*test_driver_setup)(void);
extern void (*test_driver_teardown)(void);

/* suites, one per func/ module */
void test_gesture_suite(void);
void test_fxscale_suite(void);

#endif /* TEST_DRIVER_H */
