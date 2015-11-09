/*
 * Author of this version: Jaime Munoz Martinez <http://www.jaimemunozmartinez.com>
 * Date: 2014/11/19
 * Version 0.2.2
 * Published under the terms of the GNU General Public License (GPLv2).
 */

#include "printf.h"
 
module TestAODVM {
  uses {
    interface Boot;
    interface SplitControl;
    //interface StdControl; //for timers
	/**
   * Start this component and all of its subcomponents.  Return
   * values of SUCCESS will always result in a <code>startDone()</code>
   * event being signalled.
   **/
    interface Timer<TMilli> as MilliTimer;
    interface Timer<TMilli> as Timer2;
    interface Timer<TMilli> as TimerMote;
    interface AMSend;
    interface Receive;
    interface Leds;
  }
}

implementation {
  
  message_t pkt;
  message_t* p_pkt;
  uint16_t node_id;
  am_addr_t addressID;
  
  uint16_t src  = 0x1;
  uint16_t dest = 0x6;  
  uint16_t sleepNode = 0x5;
  uint16_t sleepNode2 = 0x3;	
  	
	uint16_t receivedCounter = 0;
	uint16_t sentCounter = 0;
	uint16_t sentLimit = 200;
	
	uint32_t timerCounter = 0;
  uint32_t timerCounter2 = 0;
  uint32_t timerMoteCounter = 0;
  uint16_t minutes = 0;
  uint16_t minutesMote = 0;
  
  uint32_t limitTimer = 120;
  uint32_t sleepTime = 61;
  uint32_t awakeTime = 71;
  
  
  event void Boot.booted() {
    call SplitControl.start();
  }
  
  
  event void SplitControl.startDone(error_t err) {
    if (err == SUCCESS) {
      //dbg("APPS", "%s\t APPS: startDone %d.\n", sim_time_string(), err);
     	//printf("APPS: startDone %d.\n", err);
     	printf("********************** APPS: start DONE! *********************\n");
  		printfflush();
      p_pkt = &pkt;
      node_id = TOS_NODE_ID; //to print the NODE_ID
      if( TOS_NODE_ID == dest ){
      printf("I am the DESTINATION %u\n", dest);
  		printfflush();
  		call Timer2.startPeriodic(1024);
      }
      if( TOS_NODE_ID == src ) {
      	printf("I am the SOURCE %u\n", src);
  			printfflush();
        call MilliTimer.startPeriodic(2048);
      }
      if( TOS_NODE_ID == sleepNode ) {
      	printf("I am the SleepNode %u\n", sleepNode);
  			printfflush();
        call TimerMote.startPeriodic(1024);
      } else {
    	//call TimerMote.startPeriodic(1024);
    	printf("I am the node: %u\n", node_id);
    	printfflush();
    	call SplitControl.start();
    	}
    }
  }
  
  event void SplitControl.stopDone(error_t err) {
    // do nothing
    //call Leds.led1Toggle();
    if (err != SUCCESS) {
      call SplitControl.stop();
    }
    printf("SplitControl FAILS!\n");
    printfflush();    
  }

//*********
// TIMERs
//*********
  
  event void Timer2.fired() {
  	timerCounter2++;
  	if (timerCounter2%60 ==0){
  	minutes++;
  	//post print_route_table();
    printf("Timer: %u minutes\n", minutes);
    printf("APPS: SENT %u and RECEIVED %u\n", sentCounter, receivedCounter);
  	printfflush();
  	}
  	/*****
  	if (timerCounter2 == sleepTime){ //Turn off the node at 61secs, for 10 SECONDS
  	call SplitControl.stop();
  	}
  	if (timerCounter2 == awakeTime){ //Turn on the node at 71secs
  	call SplitControl.start(); 
  	}
  	*****/	
  }
  
  
  event void TimerMote.fired() {
  	timerMoteCounter++;
  	if (timerMoteCounter%60 ==0){
  	minutesMote++;
  	//post print_route_table();
    printf("Timer: %u minutes\n", minutes);
    //printf("APPS: SENT %u and RECEIVED %u\n", sentCounter, receivedCounter);
  	printfflush();
  	}
  	// To sleep and awake motes
  	if (timerCounter2 == sleepTime){ //Turn off the node at 61secs, for 10 SECONDS
  	call SplitControl.stop();
  	}
  	if (timerCounter2 == awakeTime){ //Turn on the node at 71secs
  	call SplitControl.start(); 
  	} 	
  }
  
  
  event void MilliTimer.fired() {
    //dbg("APPS", "%s\t APPS: MilliTimer.fired()\n", sim_time_string());
    timerCounter++;
    if (timerCounter%30 ==0){
    minutes++;
  	printf("Timer: %u minutes\n", minutes);    
  	}
    printf("APPS: MilliTimer fired %lu\n", timerCounter);
    printfflush();
    //printf("APPS: SENT %u and RECEIVED %u\n", sentCounter, receivedCounter);
  	//printfflush();
    //call Leds.led0Toggle();
    //call Leds.led2Toggle();
    //addressID = dest;
    //call AMSend.send(dest, p_pkt, 10);
    
    /*
     * Set of limit for Transmissions: Timer/Number of Messages
     *
     if (sentCounter == sentLimit || timerCounter == limitCounter) {
     		//LOGIC for reset, stop, whatever
     		printf("Transmision Finished\n");
     		printf("APPS: SENT %u and RECEIVED %u\n", sentCounter, receivedCounter);
   	 		printfflush();
   	 		call SplitControl.stop();
   	 		//Reset of some values, wait some time,...
     	} else 
     */
   
    if (call AMSend.send(dest, p_pkt, 4) == SUCCESS){
    //printf("Call AMSend.send SUCCESSFUL\n");
   	//printfflush();
    }else{
    printf("Call AMSend.send FAIL\n");
   	printfflush();
   	}
   	
  }
  
// Maybe the sentCounter can be sent in the payload of the Message 
// and it can be used as a CRC, to check that the message was delivered
 
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    //dbg("APPS", "%s\t APPS: sendDone!!\n", sim_time_string());
    call Leds.led1Toggle();
    sentCounter++;
    if (sentCounter%10 ==0){
   	//printf("SENT messages: %u\n", sentCounter);
   	printf("APPS: SENT %u and RECEIVED %u\n", sentCounter, receivedCounter);
   	printfflush();
   	}
  }
  
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    //dbg("APPS", "%s\t APPS: receive!!\n", sim_time_string());
    call Leds.led2Toggle();
    receivedCounter++;
    if (receivedCounter%10 ==0){
    printf("RECEIVED messages: %u\n", receivedCounter);
  	printfflush();
  	}
    return bufPtr;
  }
}

/*
 *****************
 * CODE EXAMPLES *
 *****************
 */

/*
This code:

uint16_t a = 32000;
uint32_t b = 64000L;
printf("a: %d (%d)\n", a, sizeof(a));
printf("b: %lu (%d)\n", b, sizeof(b));

Now gives me this output:

a: 32000 (2)
b: 64000 (4)
*/

/*

*********** 
** IDEAS **
***********

0- After T time, the Destination Turns off for some time interval and then restart

1- Send sentCounter in Messages
(Check Tutorials: 1.3 BlinkToRadio and 1.4 BaseStation

2- After the sentCounter reach a LEVEL, the Source1 stops sending messages
and the Destination6 starts sending messages

3- Store sentCounter and receiveCounter in localMemory or in a .txt file in
the laptop. (Check MT 2006 and 2008)

4- After the Timer2 reach a value, stop sending messages and check Delivery Rate


*************
Technical Issues
*************

- Strenght of the RF signal:
-------------------------

You can either change it in code by calling:
call CC2420Packet.SetRFPower(&packet, pwr);

or by changing it at compile time in Makefile by adding this line:
CFLAGS += "-DCC2420_DEF_RFPOWER=N"

where valid values for pwr in setRFPower and N in CFLAG are 1 through 31,
with power of 1 equal to -25dBm and 31 equal to max power (0dBm).


*/
