/*******************************************************************************
* File Name : unit.h
*
* Shared by the on-target unit-test runner (unit_main.c) and the suites
* (test_*.c). Unity's setUp()/tearDown() are global, so the runner owns them and
* calls the hooks the running suite set: a suite starts with
*     unit_setup = my_setup; unit_teardown = NULL;
* before its RUN_TEST() lines.
*******************************************************************************/
#ifndef UNIT_H
#define UNIT_H

extern void (*unit_setup)(void);
extern void (*unit_teardown)(void);

/* suites, one per func/ module */
void test_gesture_suite(void);
void test_fxscale_suite(void);

#endif /* UNIT_H */
