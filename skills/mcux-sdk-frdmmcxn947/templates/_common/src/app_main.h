/*******************************************************************************
* File Name : app_main.h
*
* Entry point of the layered application. src/main.c calls app_main() after the
* SDK startup code (SystemInit); app_main() starts with board_init() (clocks,
* pins, console). The SDK files of the app (CMakeLists.txt, prj.conf, the
* exported board folder) stay as new_app.sh left them - code goes in src/.
*******************************************************************************/
#ifndef APP_MAIN_H
#define APP_MAIN_H

void app_main(void);   /* does not return */

#endif /* APP_MAIN_H */
