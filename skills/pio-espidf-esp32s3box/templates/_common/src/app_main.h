/*******************************************************************************
* File Name : app_main.h
*
* Entry point of the layered application. ESP-IDF starts app_main() in the
* "main" FreeRTOS task after the bootloader and the system init; the superloop
* in app_main.c yields 1 ms per pass so the idle task (and its watchdog) runs.
*******************************************************************************/
#ifndef APP_MAIN_H
#define APP_MAIN_H

void app_main(void);   /* does not return */

#endif /* APP_MAIN_H */
