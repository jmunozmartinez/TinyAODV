/*
 * Copyright (c) 2008 Junseok Kim
 * Author: Junseok Kim <jskim@usn.konkuk.ac.kr> <http://usn.konkuk.ac.kr/~jskim>
 * Date: 2008/05/30
 * Version: 0.0.1
 * Published under the terms of the GNU General Public License (GPLv2).
 *
 *
 * Author of this version: Jaime Munoz Martinez <http://www.jaimemunozmartinez.com>
 * Date: 2014/11/19
 * Version 0.2.2
 * Published under the terms of the GNU General Public License (GPLv2).
 */
 
//#include "AODV.h"
//#include "printf.h" 
includes AODV;


#define AM_AODV_RREQ          10
#define AM_AODV_RREP          11
#define AM_AODV_RERR          12
#define AM_AODV_MSG           13

configuration AODV {
  provides {
    interface SplitControl;
    interface AMSend[am_id_t id];
    interface Receive[uint8_t id];
  }
  uses {
    ;
  }
}

implementation {
  components AODV_M, RandomC, ActiveMessageC;
  components PrintfC, SerialStartC, LedsC;
  //components StdControl;
  
  AODV_M.Leds -> LedsC;
  
  SplitControl = AODV_M.SplitControl;
  AMSend = AODV_M.AMSend;
  Receive = AODV_M.Receive;
  
  AODV_M.Random -> RandomC;
  AODV_M.AMPacket -> ActiveMessageC;
  AODV_M.Packet -> ActiveMessageC;
  AODV_M.PacketAcknowledgements -> ActiveMessageC;
  AODV_M.AMControl -> ActiveMessageC.SplitControl;
  
  components new AMSenderC(AM_AODV_RREQ) as MHSendRREQ, 
             new AMSenderC(AM_AODV_RREP) as MHSendRREP, 
             new AMSenderC(AM_AODV_RERR) as MHSendRERR;
  AODV_M.SendRREQ -> MHSendRREQ;
  AODV_M.SendRREP -> MHSendRREP;
  AODV_M.SendRERR -> MHSendRERR;
  
  components new AMSenderC(AM_AODV_MSG) as MHSend;
  AODV_M.SubSend -> MHSend;
  
  components new AMReceiverC(AM_AODV_RREQ) as MHReceiveRREQ, 
             new AMReceiverC(AM_AODV_RREP) as MHReceiveRREP, 
             new AMReceiverC(AM_AODV_RERR) as MHReceiveRERR;
  AODV_M.ReceiveRREQ -> MHReceiveRREQ;
  AODV_M.ReceiveRREP -> MHReceiveRREP;
  AODV_M.ReceiveRERR -> MHReceiveRERR;
  
  components new AMReceiverC(AM_AODV_MSG) as MHReceive;
  AODV_M.SubReceive -> MHReceive;
  
  components new TimerMilliC() as AODV_Timer;
  AODV_M.AODVTimer -> AODV_Timer;
  
  components new TimerMilliC() as RREQ_Timer; //Random Timer to send RREQ
  AODV_M.RREQTimer -> RREQ_Timer;
  
  components new TimerMilliC() as RREP_Timer; //Random Timer to send RREQ
  AODV_M.RREPTimer -> RREP_Timer;
  
  components new TimerMilliC() as RERR_Timer; //Random Timer to send RREQ
  AODV_M.RERRTimer -> RERR_Timer;
  
  //RSSI and LQI
  //For RSSI
#ifdef __CC2420_H__
  components CC2420ActiveMessageC;
  AODV_M -> CC2420ActiveMessageC.CC2420Packet;
#elif  defined(PLATFORM_IRIS)
  components  RF230ActiveMessageC;
  AODV_M.PacketRSSI -> RF230ActiveMessageC.PacketRSSI;
  AODV_M.PacketLinkQuality -> RF230ActiveMessageC.PacketLinkQuality;
  AODV_M.PacketTransmitPower -> RF230ActiveMessageC.PacketTransmitPower;
/*
#elif defined(PLATFORM_UCMINI)
  components  RFA1ActiveMessageC;
  AODV_M -> RFA1ActiveMessageC.PacketRSSI;
#elif defined(TDA5250_MESSAGE_H)
  components Tda5250ActiveMessageC;
  AODV_M -> Tda5250ActiveMessageC.Tda5250Packet;
*/
#endif
  
}

