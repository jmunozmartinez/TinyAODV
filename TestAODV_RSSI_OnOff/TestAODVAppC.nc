/*
 * Author of this version: Jaime Munoz Martinez <http://www.jaimemunozmartinez.com>
 * Date: 2014/11/19
 * Version 0.2.2
 * Published under the terms of the GNU General Public License (GPLv2).
 */
 
#define NEW_PRINTF_SEMANTICS
#include "printf.h"
 
configuration TestAODVAppC {
}

implementation {
  components MainC, LedsC, PrintfC, SerialStartC;
  components AODV;
  components TestAODVM; 
  components new TimerMilliC() as TimerSender;
  components new TimerMilliC() as TimerMinutes;
  components new TimerMilliC() as TimerNode;
  
  TestAODVM.Boot -> MainC.Boot;
  TestAODVM.SplitControl -> AODV.SplitControl;
  TestAODVM.AMSend -> AODV.AMSend[1];
  TestAODVM.Receive -> AODV.Receive[1];
  TestAODVM.Leds -> LedsC;  
  
  TestAODVM.MilliTimer -> TimerSender;
  TestAODVM.Timer2 -> TimerMinutes;
  TestAODVM.TimerMote -> TimerNode;
}

