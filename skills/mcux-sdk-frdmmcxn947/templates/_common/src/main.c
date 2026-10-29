/*******************************************************************************
* File Name : main.c
*
* Entry point: the SDK startup code (startup_mcxn947_cm33_core0.c) calls
* SystemInit() and then main(); everything else starts in app_main().
*******************************************************************************/
#include "app_main.h"

int main(void)
{
    app_main();   /* does not return */
    return 0;
}
